// lib/services/receipt_body_parser.dart
import 'dart:math';

// Ana model
import '../models/receipt_models.dart';

/// Metni normalize et: bosluklari sadelestir, isaretleri duzenle
String normalizeText(String s) {
  var t = s;
  // olasi "superscript yildiz" / carpma isareti varyasyonlari
  t = t.replaceAll(RegExp(r'[×xX⋆∗•·▪∙•]'), '*');
  // birden fazla boslugu teke indir
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

/// "*, 9,95" benzeri tutarin yakalanmasi
double? _parseAmount(String s) {
  final t = normalizeText(s);
  // basinda * olabilen tek deger
  final m = RegExp(r'^\*?\s*([0-9]{1,3}(?:[.,][0-9]{2}))$').firstMatch(t);
  if (m != null) {
    return double.tryParse(
      m.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
    );
  }
  return null;
}

/// "3 x 6,95" desenini yakala
({double qty, double unit})? _parseQtyUnit(String s) {
  final t = normalizeText(s);
  final m = RegExp(
    r'^([0-9]+)\s*[xX×]\s*([0-9]{1,3}(?:[.,][0-9]{2}))$',
  ).firstMatch(t);
  if (m != null) {
    final q = double.tryParse(m.group(1)!);
    final u = double.tryParse(
      m.group(2)!.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (q != null && u != null) return (qty: q, unit: u);
  }
  return null;
}

/// "1,535 kg x 14,90" benzeri agirlik satiri
({double w, String unit, double price})? _parseWeightUnit(String s) {
  final t = normalizeText(s).toLowerCase();
  final m = RegExp(
    r'^([0-9]+(?:[.,][0-9]+)?)\s*(kg|g|gr)\s*[xX×]\s*([0-9]{1,3}(?:[.,][0-9]{2}))$',
  ).firstMatch(t);
  if (m != null) {
    final w = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    final unit = m.group(2)!;
    final p = double.tryParse(
      m.group(3)!.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (w != null && p != null) return (w: w, unit: unit, price: p);
  }
  return null;
}

/// "%18" gibi KDV yuzdesini cikar
int? extractVatPercent(String s) {
  final t = normalizeText(s);
  final m = RegExp(r'^%0*([0-9]{1,2})$').firstMatch(t);
  if (m != null) return int.tryParse(m.group(1)!);
  return null;
}

/// Toplam bloklarini ReceiptTotals olarak cikar (TOPKDV / TOPLAM)
ReceiptTotals extractTotals(List<String> lines) {
  double? topKdv;
  double? total;
  // paymentMethod / bank / provisionNo icin simdilik yalnizca null donuyoruz
  String? paymentMethod;
  String? bank;
  String? provisionNo;

  for (int i = 0; i < lines.length; i++) {
    final l = normalizeText(lines[i]).toUpperCase();

    if (l.contains('TOPKDV')) {
      // ayni satirda tutar olabilir
      final same = RegExp(r'([0-9]{1,3}(?:[.,][0-9]{2}))').firstMatch(l);
      if (same != null) {
        topKdv = double.parse(
          same.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
        );
      } else if (i + 1 < lines.length) {
        final nxt = _parseAmount(lines[i + 1]);
        if (nxt != null) topKdv = nxt;
      }
    }

    if (l.contains('TOPLAM')) {
      // once bir sonraki satira bak
      if (i + 1 < lines.length) {
        final nxt = _parseAmount(lines[i + 1]);
        if (nxt != null) total = nxt;
      }
      // son care: satirin icinde ara
      final same = RegExp(r'([0-9]{1,3}(?:[.,][0-9]{2}))').firstMatch(l);
      if (same != null) {
        total ??= double.parse(
          same.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
        );
      }
    }
  }

  return ReceiptTotals(
    topKdv: topKdv,
    total: total,
    paymentMethod: paymentMethod,
    bank: bank,
    provisionNo: provisionNo,
  );
}

/// Body baslangicini bulur: ardisaq satirlarda (en fazla next 6 satir)
/// bir KDV yuzdesi (%..) ve sonrasinda tutar gorulen ilk konum.
/// Donus: urun isim kuyugunun baslayacagi index.
int _findBodyStart(List<String> lines, {void Function(String)? log}) {
  int best = 0;
  for (int i = 0; i < lines.length; i++) {
    // Totallerin altina inmeyelim
    final upper = normalizeText(lines[i]).toUpperCase();
    if (upper.contains('KDV ORANI') ||
        upper.contains('KDV ORANI KDV DAHIL TUTAR')) {
      break;
    }

    // i sonrasindaki 6 satira bak: once bir %.. sonra fiyat
    bool seenVat = false;
    bool seenPriceAfterVat = false;
    for (int j = i + 1; j <= min(i + 6, lines.length - 1); j++) {
      final vat = extractVatPercent(lines[j]);
      final amt = _parseAmount(lines[j]);
      if (!seenVat && vat != null) {
        seenVat = true;
        continue;
      }
      if (seenVat && amt != null) {
        seenPriceAfterVat = true;
        break;
      }
    }
    if (seenVat && seenPriceAfterVat) {
      best = i;
      log?.call('▶ body start by pattern at L$i: "${lines[i]}"');
      return best;
    }
  }
  log?.call('▶ body start fallback = 0');
  return best;
}

/// Adi, KDV’yi ve toplami duzgun yazmak icin (UI icin)
String formatLineItem(LineItem it) {
  final parts = <String>[it.name];
  if (it.quantity != null) parts.add('${it.quantity!.toStringAsFixed(0)}x');
  if (it.weight != null) {
    final u = it.weightUnit ?? '';
    parts.add('${it.weight!.toStringAsFixed(3)}$u');
  }
  if (it.vatPercent != null) parts.add('%${it.vatPercent}');
  parts.add('= ${it.totalPrice.toStringAsFixed(2)}');
  return parts.join('  ');
}

/// Ana govdeyi satir satir cozer.
/// Donus: models/receipt_models.dart taki LineItem listesi.
List<LineItem> parseBodySequential(
  List<String> originalLines, {
  void Function(String)? log,
}) {
  // Normalize edilip bos olmayan satirlar
  final lines =
      originalLines.map(normalizeText).where((e) => e.isNotEmpty).toList();

  log?.call('parsing started; lines=${lines.length}');

  // 1) Body baslangici
  final start = _findBodyStart(lines, log: log);

  // 2) Kuyruk ve durum
  final nameQueue = <String>[];
  int? pendingVat;
  double?
  pendingUnitByQty; // 3 x 6,95 turunden ara bilgi (simdilik kullanmiyoruz)
  double? pendingWeight;
  String? pendingWeightUnit;
  double? pendingUnitByWeight;

  final items = <LineItem>[];

  bool looksLikeHeaderOrTotals(String u) {
    // ust bolum / alt toplamlar icin kaba filtre
    return u.contains('TOPLAM') ||
        u.contains('TOPKDV') ||
        u.contains('KDV ORANI') ||
        u.contains('KREDI KARTI') ||
        u.contains('NAKIT') ||
        u.contains('TUR:') ||
        u.contains('MUSTER') ||
        u.contains('BELGE NO') ||
        u.contains('ETTN') ||
        u.contains('FIS NO') ||
        u.contains('TARIH') ||
        u.contains('SAAT');
  }

  for (int i = start; i < lines.length; i++) {
    final raw = lines[i];
    final u = raw.toUpperCase();

    // Belli basli bloklarda cik
    if (looksLikeHeaderOrTotals(u)) {
      log?.call('— stop at L$i "$raw"');
      break;
    }

    // 3 x 6,95
    final qu = _parseQtyUnit(raw);
    if (qu != null) {
      pendingUnitByQty = qu.unit;
      // ileride istersen quantity de ekleyebiliriz
      log?.call('  ↳ remember QTY=${qu.qty} unit=${qu.unit}');
      continue;
    }

    // 1,535 kg x 14,90
    final wu = _parseWeightUnit(raw);
    if (wu != null) {
      pendingWeight = wu.w;
      pendingWeightUnit = wu.unit;
      pendingUnitByWeight = wu.price;
      log?.call('  ↳ remember WEIGHT=${wu.w}${wu.unit} unit=${wu.price}');
      continue;
    }

    // %18
    final vat = extractVatPercent(raw);
    if (vat != null) {
      pendingVat = vat;
      log?.call('  ↳ remember VAT=%$vat');
      continue;
    }

    // *9,95 gibi fiyat geldi mi?
    final amt = _parseAmount(raw);
    if (amt != null) {
      // isim kuyugundan son adi cek
      final name = nameQueue.isNotEmpty ? nameQueue.removeLast() : 'Urun';
      log?.call('  √ ITEM name="$name" vat=${pendingVat ?? '∅'} total=$amt');

      items.add(
        LineItem(
          name: name,
          totalPrice: amt,
          quantity: null, // seq parser unit price hesaplamiyor
          unitPrice: null,
          weightUnit: pendingWeightUnit,
          weight: pendingWeight,
          vatPercent: pendingVat,
          priceWasComputed: false,
        ),
      );

      // state sifirla
      pendingVat = null;
      pendingUnitByQty = null;
      pendingWeight = null;
      pendingWeightUnit = null;
      pendingUnitByWeight = null;
      continue;
    }

    // Buraya geldiyse; bu bir "isim" adayi
    if (!RegExp(r'^\d+$').hasMatch(raw)) {
      nameQueue.add(raw);
      log?.call('  + queue NAME "$raw" (len=${nameQueue.length})');
    }
  }

  return items;
}
