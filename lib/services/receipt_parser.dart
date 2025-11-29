// lib/services/receipt_parser.dart
import 'dart:math';

import '../models/receipt_models.dart';
import 'receipt_patterns.dart';
import 'receipt_body_parser.dart' as seq;
import 'receipt_body_parser_coord.dart' as coord;
import 'ocr_service.dart' show OcrElement;

class ReceiptParser2 {
  // HEADER ONLY aynen kalsin
  ReceiptHeader parseHeaderOnly(String text) {
    final lines =
        text
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    return _parseHeader(lines);
  }

  /// Header + Body + Totals hepsini tek seferde doner
  ReceiptParseResult parseFull(
    String rawText, {
    List<OcrElement>? elements,
    void Function(String msg)? log,
  }) {
    // Tum satirlari normalize et
    final lines =
        rawText
            .split(RegExp(r'[\r\n]+'))
            .map((e) => normalizeSpaces(e)) // receipt_patterns.dart icindeki
            .where((e) => e.isNotEmpty)
            .toList();

    // Body baslangic tahmini
    final bodyStart = _guessBodyStartSmart(lines);

    // Header: bodyStart'tan onceki kisimdan
    final header = _parseHeader(lines, endExclusive: bodyStart);

    // ---- BODY (urun satirlari)
    // 1) sequential parser her zaman calisir
    final seqItems = seq.parseBodySequential(
      lines,
      log: (m) => log?.call('[SEQ] $m'),
    ); // List<LineItem> (ana model)

    // 2) varsa koordinat tabanli parser ile deneyip, bos degilse onu tercih et
    List<LineItem> items;
    if (elements != null && elements.isNotEmpty) {
      final coordItems = coord.parseByGeometry(
        elements: elements,
        log: (m) => log?.call('[COORD] $m'),
      ); // List<coord.LineItem>

      if (coordItems.isNotEmpty) {
        items =
            coordItems
                .map(
                  (it) => LineItem(
                    name: it.name,
                    totalPrice: it.totalPrice,
                    vatPercent: it.vatPercent?.round(),
                    quantity: it.quantity,
                    unitPrice: it.unitPrice,
                    weightUnit: it.weightUnit,
                    weight: it.weight,
                    priceWasComputed: it.priceWasComputed,
                  ),
                )
                .toList();
      } else {
        items = seqItems;
      }
    } else {
      items = seqItems;
    }

    // ---- TOTALS
    final totals = seq.extractTotals(lines); // ReceiptTotals (ana model)

    // Indirimleri simdilik bos birakiyoruz
    final discounts = <DiscountLine>[];

    // Misc'i simdilik bos birak
    return ReceiptParseResult(
      header: header,
      items: items,
      discounts: discounts,
      totals: totals,
      misc: const [],
    );
  }

  // ---- BURADAN SONRASI SENDE ZATEN VARDI (header, bodyStart vs.) ----
  // _parseHeader, _guessBusinessName, _guessBodyStartSmart, _parseTotals vs
  // onlara dokunmana gerek yok; sadece _parseTotals'i kullanmiyoruz artık.
  // ...
  // ————— HEADER —————

  ReceiptHeader _parseHeader(List<String> lines, {int? endExclusive}) {
    final limit =
        endExclusive == null
            ? min(18, lines.length)
            : min(endExclusive, lines.length);
    final slice = lines.take(limit).toList();

    String? businessName;
    final addrParts = <String>[];
    String? phone;
    String? taxOffice;
    String? taxNumber;
    DateTime? date;
    String? time;
    String? receiptNo;

    double score = 0;
    bool stopAddress = false;

    for (final l in slice) {
      if (rxHeaderStopWords.hasMatch(l)) stopAddress = true;

      // fiş no
      final r = rxReceiptNo.firstMatch(l);
      if (r != null) {
        receiptNo = r.group(2);
        score += 0.8;
      }

      // tarih
      final d = rxDate.firstMatch(l);
      if (d != null) {
        final dt = tryParseDateFlexible(d.group(0)!);
        if (dt != null) {
          date = dt;
          score += 0.7;
        }
      }

      // saat
      String? t;
      final tl = rxTimeLabelled.firstMatch(l);
      if (tl != null) {
        t =
            tl.group(1)! +
            ':' +
            (tl
                .group(0)!
                .split(RegExp(r'[.:]'))
                .elementAt(1)); // normalize hh:mm
      } else {
        final tc = rxTimeColon.firstMatch(l);
        if (tc != null) t = tc.group(0);
      }
      if (t != null) {
        time = t;
        score += 0.4;
      }

      // telefon
      if (phone == null) {
        if (rxPhoneLabel.hasMatch(l) || rxPhoneClassic.hasMatch(l)) {
          final m = rxPhoneClassic.firstMatch(l);
          if (m != null) {
            final cand = m.group(0)!.replaceAll(RegExp(r'[^0-9+]'), '');
            if (!(cand == taxNumber) &&
                !(RegExp(r'^\d{10,11}$').hasMatch(cand))) {
              phone = cand;
              score += 0.3;
            }
          }
        }
      }

      // vergi dairesi
      if (rxTaxOfficeKey.hasMatch(l)) {
        taxOffice = l;
        score += 0.3;
      }

      // vergi no
      final digit = rxTenElevenDigits.firstMatch(l);
      if (digit != null) {
        final s = digit.group(0)!;
        if (s.length == 10) {
          taxNumber = s;
          score += 0.6;
        }
      }

      // adres
      if (!stopAddress) {
        final isAddressy = RegExp(
          r'\b(sok|sokak|cad|cadde|mh|mah|mahalle|no[:.]?|blok|bina|apt|bulvar|blv|sk|cd)\b',
          caseSensitive: false,
        ).hasMatch(l);
        if (isAddressy || l.contains(',')) {
          addrParts.add(l);
        }
      }
    }

    businessName = _guessBusinessName(slice);

    return ReceiptHeader(
      businessName: businessName,
      address: addrParts.isEmpty ? null : addrParts.join(', '),
      phone: phone,
      taxOffice: taxOffice,
      taxNumber: taxNumber,
      date: date,
      time: time,
      receiptNo: receiptNo,
      confidence: double.parse(min(1.0, score / 2.8).toStringAsFixed(2)),
    );
  }

  String? _guessBusinessName(List<String> slice) {
    for (final s in slice.take(6)) {
      final letters = s.replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]'), '');
      if (letters.isEmpty) continue;
      final upp = letters.replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '').length;
      final ratio = upp / letters.length;
      final hasStreet = RegExp(
        r'\b(sok|cad|cadde|mah|mahalle|no|blok|apt|bulvar|blv|sk|cd)\b',
        caseSensitive: false,
      ).hasMatch(s);
      if (!hasStreet && (ratio > 0.5 || s.split(' ').length <= 5)) {
        return s;
      }
    }
    return slice.isNotEmpty ? slice.first : null;
  }

  // ————— BODY START GUESS —————

  final _forbiddenNameHints = <RegExp>[
    RegExp(r'\bKAS[İI]YER\b', caseSensitive: false),
    RegExp(r'\b(BELGE|MERS[İI]S)\s*NO\b', caseSensitive: false),
    RegExp(r'\b(EKO|Z)\s*NO\b', caseSensitive: false),
    RegExp(r'\bPROV[İI]ZYON\b', caseSensitive: false),
    RegExp(r'\bNAK[İI]T\b', caseSensitive: false),
    RegExp(r'\bKRED[İI]\s*KARTI\b', caseSensitive: false),
    RegExp(r'\bTOPLAM\b', caseSensitive: false),
    RegExp(r'\bTOPKDV\b', caseSensitive: false),
    RegExp(r'KDV\s*ORAN[Iİ]', caseSensitive: false),
    RegExp(r'\b(MH\.?|MAH\.?|MAHALLES[İI])\b', caseSensitive: false),
    RegExp(r'\b(SOK\.?|SOKAK|CD\.?|CADDE|BULVARI?)\b', caseSensitive: false),
    RegExp(r'\bNO[:/ ]?\s*\d+', caseSensitive: false),
    RegExp(r'\bV\.?D\.?\b', caseSensitive: false),
  ];

  final RegExp rxVatToken = RegExp(r'[%º°oO]\s?\d{1,2}');

  bool _isForbiddenNameLine(String s) {
    final u = s.toUpperCase();
    if (u.contains('TARİH') || u.contains('SAAT') || u.contains('FİŞ NO')) {
      return true;
    }
    for (final rx in _forbiddenNameHints) {
      if (rx.hasMatch(s)) return true;
    }
    return false;
  }

  bool isPriceOnlyLine(String l) {
    final noLetters = !RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(l);
    return noLetters && rxPriceAtEnd.hasMatch(l);
  }

  int _guessBodyStartSmart(List<String> lines) {
    final n = lines.length;

    int searchEnd = n;
    for (var i = 0; i < n; i++) {
      final u = lines[i].toUpperCase();
      if (u.contains('TOPKDV') ||
          u.contains('TOPLAM') ||
          u.contains('KDV ORANI')) {
        searchEnd = i;
        break;
      }
    }

    bool looksLikeName(String s) {
      final hasLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(s);
      final hasPrice = rxPriceAtEnd.hasMatch(s);
      return hasLetters && !hasPrice && !_isForbiddenNameLine(s);
    }

    var run = 0;
    for (var i = 0; i < searchEnd; i++) {
      if (looksLikeName(lines[i])) {
        run++;
        if (run >= 3) {
          final start = i - run + 1;
          final end = (i + 12 < searchEnd) ? i + 12 : searchEnd - 1;
          int priceHits = 0, vatHits = 0;
          for (var k = start; k <= end; k++) {
            if (rxPriceAtEnd.hasMatch(lines[k])) priceHits++;
            if (rxVatToken.hasMatch(lines[k])) vatHits++;
          }
          if (priceHits >= 1 && vatHits >= 2) {
            print('[BODY] start=$start (>=3 name-like + lookahead price/vat)');
            return start;
          }
        }
      } else {
        run = 0;
      }
    }

    for (var i = 0; i < searchEnd; i++) {
      if (!looksLikeName(lines[i])) continue;
      for (var k = i + 1; k < n && k <= i + 15 && k < searchEnd; k++) {
        if (isPriceOnlyLine(lines[k]) ||
            rxQtyUnit.hasMatch(lines[k]) ||
            rxWeightUnit.hasMatch(lines[k])) {
          print('[BODY] start=$i (name + later price within 15)');
          return i;
        }
      }
    }

    for (var i = 0; i < searchEnd; i++) {
      final u = lines[i].toUpperCase();
      if (rxPriceAtEnd.hasMatch(lines[i]) &&
          !u.contains('TOPLAM') &&
          !u.contains('TOPKDV')) {
        print('[BODY] fallback start=$i');
        return i;
      }
    }
    print('[BODY] fallback start=10');
    return (n < 10) ? n : 10;
  }
}
