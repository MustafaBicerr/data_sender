// lib/services/receipt_body_parser.dart
import 'dart:math';

/// Basit satır kalemi modeli
class LineItem {
  final String name;
  final double? quantity; // örn. "3 x 6,95" için 3
  final double? weight; // örn. "1,535 kg"
  final String? weightUnit;
  final int? vatPercent; // %18
  final double totalPrice;

  LineItem({
    required this.name,
    required this.totalPrice,
    this.quantity,
    this.weight,
    this.weightUnit,
    this.vatPercent,
  });

  LineItem copyWith({
    String? name,
    double? totalPrice,
    double? quantity,
    double? weight,
    String? weightUnit,
    int? vatPercent,
  }) {
    return LineItem(
      name: name ?? this.name,
      totalPrice: totalPrice ?? this.totalPrice,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      vatPercent: vatPercent ?? this.vatPercent,
    );
  }
}

/// Toplamlar
class TotalsResult {
  double? toplam;
  double? topkdv;

  TotalsResult({this.toplam, this.topkdv});
}

/// Metni normalize et: boşlukları sadeleştir, süper-script * vs.
String normalizeText(String s) {
  var t = s;
  // olası "süperscript yıldız" / çarpı işareti varyasyonları
  t = t.replaceAll(RegExp(r'[×xX⋆∗•·▪∙•]'), '*');
  // Nokta / virgül karışımı
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

/// "*, 9,95" benzeri tutarın yakalanması
double? _parseAmount(String s) {
  final t = normalizeText(s);
  // başında * olabilen tek değer
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

/// "1,535 kg x 14,90" benzeri ağırlık satırı
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

/// "%18" gibi KDV yüzdesini çıkar
int? extractVatPercent(String s) {
  final t = normalizeText(s);
  final m = RegExp(r'^%0*([0-9]{1,2})$').firstMatch(t);
  if (m != null) return int.tryParse(m.group(1)!);
  return null;
}

/// Toplam bloklarını basitçe çıkar (TOPKDV / TOPLAM)
TotalsResult extractTotals(List<String> lines) {
  final res = TotalsResult();
  for (int i = 0; i < lines.length; i++) {
    final l = normalizeText(lines[i]).toUpperCase();
    if (l.contains('TOPKDV')) {
      // bir sonraki satır veya aynı satırda tutar olabilir
      // önce aynı satırda ara
      final same = RegExp(r'([0-9]{1,3}(?:[.,][0-9]{2}))').firstMatch(l);
      if (same != null) {
        res.topkdv = double.parse(
          same.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
        );
      } else if (i + 1 < lines.length) {
        final nxt = _parseAmount(lines[i + 1]);
        if (nxt != null) res.topkdv = nxt;
      }
    }
    if (l.contains('TOPLAM')) {
      // toplama en yakın sayı
      if (i + 1 < lines.length) {
        final nxt = _parseAmount(lines[i + 1]);
        if (nxt != null) res.toplam = nxt;
      }
      // son çare: satırın içinde ara
      final same = RegExp(r'([0-9]{1,3}(?:[.,][0-9]{2}))').firstMatch(l);
      if (same != null) {
        res.toplam ??= double.parse(
          same.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
        );
      }
    }
  }
  return res;
}

/// Body başlangıcını bulur: ardışık satırlarda (en fazla next 6 satır)
/// bir KDV yüzdesi (%..) ve sonrasında *li bir tutar görülen ilk konum.
/// Dönüş: ürün isim kuyruğunun başlayacağı index.
int _findBodyStart(List<String> lines, {void Function(String)? log}) {
  int best = 0;
  for (int i = 0; i < lines.length; i++) {
    // Totallerin altına inmeyelim
    final upper = normalizeText(lines[i]).toUpperCase();
    if (upper.contains('KDV ORANI') ||
        upper.contains('KDV ORANI KDV DAHIL TUTAR')) {
      break;
    }

    // i sonrası 6 satıra bak: önce bir %.., sonra *.., yani fiyat
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

/// Adı, KDV’yi ve toplamı düzgün yazmak için
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

/// Ana gövdeyi satır satır çözer.
/// Strateji:
/// 1) Body başlangıcını _findBodyStart ile kestir.
/// 2) “isim kuyruğu” (queue) tut: her metin satırı olası ürün adıdır.
/// 3) Bir yerde %.. gelirse pendingVat al; fiyat görünce kuyruğun son adını
///    kullanarak kalem oluştur (adı kaçmadığı için kayma olmaz).
List<LineItem> parseBodySequential(
  List<String> originalLines, {
  void Function(String)? log,
}) {
  // Normalize edilip boş olmayan satırlar
  final lines =
      originalLines.map(normalizeText).where((e) => e.isNotEmpty).toList();

  log?.call('parsing started; lines=${lines.length}');

  // 1) Body başlangıcı
  final start = _findBodyStart(lines, log: log);

  // 2) Kuyruk ve durum
  final nameQueue = <String>[];
  int? pendingVat;
  double? pendingUnitByQty; // 3 x 6,95 türünden ara bilgi
  double? pendingWeight;
  String? pendingWeightUnit;
  double? pendingUnitByWeight;

  final items = <LineItem>[];

  bool looksLikeHeaderOrTotals(String u) {
    // üst bölüm / alt toplamlar için kaba filtre
    return u.contains('TOPLAM') ||
        u.contains('TOPKDV') ||
        u.contains('KDV ORANI') ||
        u.contains('KREDI KARTI') ||
        u.contains('NAKIT') ||
        u.contains('TÜR:') ||
        u.contains('MÜSTERI') ||
        u.contains('BELGE NO') ||
        u.contains('ETTN') ||
        u.contains('FIS NO') ||
        u.contains('TARIH') ||
        u.contains('SAAT');
  }

  for (int i = start; i < lines.length; i++) {
    final raw = lines[i];
    final u = raw.toUpperCase();

    // Belli başlı bloklarda çık
    if (looksLikeHeaderOrTotals(u)) {
      log?.call('— stop at L$i "$raw"');
      break;
    }

    // 3 x 6,95
    final qu = _parseQtyUnit(raw);
    if (qu != null) {
      pendingUnitByQty = qu.unit;
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
      // isim kuyruğundan son adı çek
      final name = nameQueue.isNotEmpty ? nameQueue.removeLast() : 'Ürün';
      log?.call('  √ ITEM name="$name" vat=${pendingVat ?? '∅'} total=$amt');
      items.add(
        LineItem(
          name: name,
          totalPrice: amt,
          vatPercent: pendingVat,
          quantity: null,
          weight: pendingWeight,
          weightUnit: pendingWeightUnit,
        ),
      );
      // state’i sıfırla
      pendingVat = null;
      pendingUnitByQty = null;
      pendingWeight = null;
      pendingWeightUnit = null;
      pendingUnitByWeight = null;
      continue;
    }

    // Buraya geldiyse; bu bir “isim” adayıdır
    // “çok teknik” / “sayaç” gibi kelimeleri filtreleme
    if (!RegExp(r'^\d+$').hasMatch(raw)) {
      nameQueue.add(raw);
      log?.call('  + queue NAME "$raw" (len=${nameQueue.length})');
    }
  }

  return items;
}
