import 'dart:math';
import '../models/receipt_models.dart';
import 'receipt_patterns.dart';

class ReceiptParser2 {
  // YENİ: Sadece header parse et
  ReceiptHeader parseHeaderOnly(String text) {
    final lines =
        text
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    return _parseHeader(lines); // parseFull içinde kullandığın iç fonksiyon
  }

  // ReceiptParseResult parseFull(String rawText) {
  //   final lines =
  //       rawText
  //           .split(RegExp(r'[\r\n]+'))
  //           .map((e) => normalizeSpaces(e))
  //           .where((e) => e.isNotEmpty)
  //           .toList();

  //   // Body başlangıcını ÖNCE bul (ilk %KDV + satır sonu fiyat görülen satır)
  //   final bodyStart = _guessBodyStartSmart(lines);

  //   // Header’ı, bodyStart’tan ÖNCEKİ bölümden çıkar (ürün satırları karışmasın)
  //   final header = _parseHeader(lines, endExclusive: bodyStart);

  //   // Gövde ve toplamlar
  //   final bodyLines =
  //       bodyStart < lines.length ? lines.sublist(bodyStart) : <String>[];
  //   final body = _parseBody(bodyLines);
  //   final totals = _parseTotals(lines);

  //   // Misc (opsiyonel)
  //   final misc = <String>[];
  //   for (final l in lines.reversed) {
  //     if (rxProvision.hasMatch(l) || rxPaymentMethod.hasMatch(l)) continue;
  //     final u = l.toUpperCase();
  //     if (u.contains('İADE') || u.contains('GARANT') || u.contains('SERVİS')) {
  //       misc.add(l);
  //     }
  //     if (misc.length > 6) break;
  //   }

  //   return ReceiptParseResult(
  //     header: header,
  //     items: body.items,
  //     discounts: body.discounts,
  //     totals: totals,
  //     misc: misc.reversed.toList(),
  //   );
  // }

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

      // saat: önce LABELLED (Saat 17.58), yoksa sadece ":"’lu saat kabul
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

      // telefon (yalnızca etiketli veya klasik biçim)
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

      // vergi no (10 hane ipucu)
      final digit = rxTenElevenDigits.firstMatch(l);
      if (digit != null) {
        final s = digit.group(0)!;
        if (s.length == 10) {
          taxNumber = s;
          score += 0.6;
        }
      }

      // adres (stop kelimesi gelene kadar)
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

    // işletme adı
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

  // ————— BODY —————
  // Alt/özet alan anahtarları – ürün adı değildir
  // Ad/başlık sayılmayacak ipuçları
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
    // Adres/başlık ipuçları
    RegExp(r'\b(MH\.?|MAH\.?|MAHALLES[İI])\b', caseSensitive: false),
    RegExp(r'\b(SOK\.?|SOKAK|CD\.?|CADDE|BULVARI?)\b', caseSensitive: false),
    RegExp(r'\bNO[:/ ]?\s*\d+', caseSensitive: false),
    RegExp(r'\bV\.?D\.?\b', caseSensitive: false), // Vergi dairesi kısaltması
  ];

  final RegExp rxVatToken = RegExp(r'[%º°oO]\s?\d{1,2}'); // %8, %18 vb

  bool _isForbiddenNameLine(String s) {
    final u = s.toUpperCase();
    if (u.contains('TARİH') || u.contains('SAAT') || u.contains('FİŞ NO'))
      return true;
    for (final rx in _forbiddenNameHints) {
      if (rx.hasMatch(s)) return true;
    }
    return false;
  }

  // Sadece fiyat satırı mı? (harf yok, sondaki fiyat)
  bool isPriceOnlyLine(String l) {
    final noLetters = !RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(l);
    return noLetters && rxPriceAtEnd.hasMatch(l);
  }

  bool _looksLikeProductLine(String l) {
    final u = l.toUpperCase();

    // top/bottom alanlarını dışla
    if (u.contains('TOPLAM') || u.contains('TOPKDV')) return false;
    if (rxPaymentMethod.hasMatch(l) || rxProvision.hasMatch(l)) return false;

    // sonda fiyat şart
    if (!rxPriceAtEnd.hasMatch(l)) return false;

    // tipik ipuçları
    if (rxVat.hasMatch(l)) return true; // %01 / º18 / o8 …
    if (rxQtyUnit.hasMatch(l)) return true; // 3 x 6,95
    if (rxWeightUnit.hasMatch(l)) return true; // 1,535 kg x 14,90

    // KDV OCR'da düşerse: "ad + rakamlar + sonda fiyat" kombinasyonu
    final hasLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(l);
    final hasDigits = RegExp(r'\d').hasMatch(l);
    if (hasLetters && hasDigits) return true;

    return false;
  }

  // ——— BODY START BUL ———

  // Artık “ürün adı + sonraki satırlarda fiyat” desenini de gözetiyor
  int _guessBodyStartSmart(List<String> lines) {
    final n = lines.length;

    // Toplam/KDV tablosundan ÖNCE arayacağız
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

    // 1) Peş peşe ≥3 "isim gibi" satır + İLERİDE (≤12 satır) en az 1 fiyat VE 2 KDV token
    var run = 0;
    for (var i = 0; i < searchEnd; i++) {
      if (looksLikeName(lines[i])) {
        run++;
        if (run >= 3) {
          final start = i - run + 1;
          // lookahead penceresi
          final end = (i + 12 < searchEnd) ? i + 12 : searchEnd - 1;
          int priceHits = 0, vatHits = 0;
          for (var k = start; k <= end; k++) {
            if (rxPriceAtEnd.hasMatch(lines[k])) priceHits++;
            if (rxVatToken.hasMatch(lines[k])) vatHits++;
          }
          if (priceHits >= 1 && vatHits >= 2) {
            print('[BODY] start=$start (≥3 name-like + lookahead price/vat)');
            return start;
          }
        }
      } else {
        run = 0;
      }
    }

    // 2) Alternatif: isim gibi satır + ≤15 satır içinde fiyat/qty/weight
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

    // 3) Fallback: ilk ürün fiyatı görünen satır (toplamlar hariç)
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

  // ——— BODY PARSE: SIRALI EŞLEŞTİRME ———
  _BodyParse _parseBody(List<String> lines) {
    final items = <LineItem>[];
    final discounts = <DiscountLine>[];

    bool inTotalsBlock = false;
    bool inTaxTable = false; // "KDV Oranı KDV Dahil Tutar" tablosu

    final pendingNames = <String>[];
    final pendingVat = <int?>[];
    int? lastItemIndex;

    // bool inTaxTable = false;

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final u = raw.toUpperCase();
      print('[BODY L$i] "$raw"');

      if (rxDivider.hasMatch(raw)) {
        inTaxTable = false;
        continue;
      }
      if (u.contains('KDV ORANI') && u.contains('KDV DAH')) {
        // "KDV Oranı  KDV Dahil Tutar"
        inTaxTable = true;
        continue;
      }
      if (inTaxTable) {
        // Bu bloktaki fiyatlar ürün DEĞİL → atla
        continue;
      }

      // Ürün adı adayı: fiyat yok, alt bilgi değil
      final hasLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(raw);
      final hasPrice = rxPriceAtEnd.hasMatch(raw);
      final isNameCandidate =
          hasLetters && !hasPrice && !_isForbiddenNameLine(raw);
      if (isNameCandidate) {
        final name = raw.replaceAll(rxVat, '').trim();
        if (name.isNotEmpty) {
          pendingNames.add(name);
          pendingVat.add(null);
          print('  + queued name="$name" (pending=${pendingNames.length})');
        }
        continue;
      }

      // ... kalan mevcut “adet/weight → eşle”, “sadece fiyat → önceki ada bağla”
      // bloklarınız aynı kalsın.
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final u = raw.toUpperCase();
      print('[BODY L$i] "$raw"');

      // ---- Bölüm kontrolü
      if (rxDivider.hasMatch(raw)) {
        inTotalsBlock = false;
        inTaxTable = false;
        continue;
      }
      if (u.contains('KDV ORANI') && u.contains('KDV DAHIL')) {
        inTaxTable = true;
        continue;
      }
      if (u.contains('TOPKDV') ||
          u.contains('TOPLAM') ||
          rxPaymentMethod.hasMatch(raw) ||
          rxProvision.hasMatch(raw)) {
        inTotalsBlock = true;
        continue;
      }

      // ---- Sadece KDV yüzdesi satırı
      final onlyVat = RegExp(r'^[%º°oO]\s?(\d{1,2})$');
      final mVatOnly = onlyVat.firstMatch(raw.trim());
      if (mVatOnly != null) {
        final v = int.tryParse(mVatOnly.group(1)!);
        if (v != null) {
          if (pendingNames.isNotEmpty) {
            pendingVat[pendingVat.length - 1] = v;
            print('  ↳ set pending VAT=$v to "${pendingNames.last}"');
          } else if (lastItemIndex != null &&
              lastItemIndex! >= 0 &&
              lastItemIndex! < items.length &&
              items[lastItemIndex!].vatPercent == null) {
            items[lastItemIndex!] = items[lastItemIndex!].copyWith(
              vatPercent: v,
            );
            print('  ↳ set last item VAT=$v');
          }
        }
        continue;
      }

      // ---- Ürün adı adayı (alt bilgi değil, fiyat da yok)
      final hasLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(raw);
      final hasPrice = rxPriceAtEnd.hasMatch(raw);
      final isNameCandidate =
          hasLetters &&
          !hasPrice &&
          !inTotalsBlock &&
          !inTaxTable &&
          !_isForbiddenNameLine(raw);

      if (isNameCandidate) {
        final name = raw.replaceAll(rxVat, '').trim();
        if (name.isNotEmpty) {
          pendingNames.add(name);
          pendingVat.add(null);
          print('  + queued name="$name" (pending=${pendingNames.length})');
        }
        continue;
      }

      // ---- Adet/weight satırı -> sıradaki ada bağla (toplam/kdv tablosunda değilsek)
      if ((rxQtyUnit.hasMatch(raw) || rxWeightUnit.hasMatch(raw)) &&
          !inTotalsBlock &&
          !inTaxTable) {
        // ... (sizdeki aynı hesap kodu; değişmeden bırakın)
        // Not: burada mevcut queue eşleştirme mantığınızla devam edin
      }

      // ---- Sadece fiyat satırı -> sıradaki ada bağla (toplam/kdv tablosunda değilsek)
      if (isPriceOnlyLine(raw) && !inTotalsBlock && !inTaxTable) {
        // ... (sizdeki aynı “price-only → queue” kodu)
      }

      // Diğerleri: atla (header/alt bilgi)
    }

    return _BodyParse(items: items, discounts: discounts);
  }

  String _flushNameBuffer(List<String> buf) {
    final s = buf.join(' ').replaceAll(rxVat, '').trim();
    buf.clear();
    return s.isEmpty ? 'Ürün' : s;
  }

  String _flushWithPrefix(List<String> buf, String name) {
    if (buf.isEmpty) return name;
    final combined = '${buf.join(" ")} $name';
    buf.clear();
    return combined.trim();
  }

  // ————— TOTALS —————

  ReceiptTotals _parseTotals(List<String> lines) {
    double? topKdv;
    double? total;
    String? paymentMethod;
    String? bank;
    String? provisionNo;

    for (final l in lines) {
      final u = l.toUpperCase();

      if (u.contains('TOPKDV')) {
        final m = rxPriceAtEnd.firstMatch(l);
        if (m != null) topKdv = parsePrice(m.group(1)!);
      }
      if (u.contains('TOPLAM')) {
        final m = rxPriceAtEnd.firstMatch(l);
        if (m != null) total = parsePrice(m.group(1)!);
      }

      final pm = rxPaymentMethod.firstMatch(l);
      if (pm != null) {
        paymentMethod = pm.group(0);
        final bankHit = RegExp(
          r'(akbank|yapı?kredi|finansbank|ziraat|halkbank|vakıf|i[sş]bank|garanti)',
          caseSensitive: false,
        ).firstMatch(l);
        if (bankHit != null) bank = bankHit.group(0);
      }

      final pv = rxProvision.firstMatch(l);
      if (pv != null) provisionNo = pv.group(1);
    }

    return ReceiptTotals(
      topKdv: topKdv,
      total: total,
      paymentMethod: paymentMethod,
      bank: bank,
      provisionNo: provisionNo,
    );
  }
}

class _BodyParse {
  final List<LineItem> items;
  final List<DiscountLine> discounts;
  _BodyParse({required this.items, required this.discounts});
}
