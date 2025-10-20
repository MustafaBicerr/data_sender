import 'package:intl/intl.dart';

// Tarih: dd.mm.yyyy | dd/mm/yyyy | dd-mm-yyyy | dd mm yyyy
final RegExp rxDate = RegExp(
  r'(?:(?:0?[1-9]|[12][0-9]|3[01])(?:[.\-/\s])(?:0?[1-9]|1[012])(?:[.\-/\s])(?:\d{2,4}))',
  caseSensitive: false,
);

// SAAT (PRIMARY): hh:mm (":" zorunlu) -> “1.25 L” gibi ürün değerleriyle çakışmaz
final RegExp rxTimeColon = RegExp(
  r'\b([01]?\d|2[0-3]):[0-5]\d(?:[:.][0-5]\d)?\b',
);

// SAAT (LABELLED): "Saat 17.58" gibi noktalı formatı SADECE etiket varsa al
final RegExp rxTimeLabelled = RegExp(
  r'\bsaat[:\s]*([01]?\d|2[0-3])[.:][0-5]\d(?:[.:][0-5]\d)?\b',
  caseSensitive: false,
);

// Telefon (yalnızca etiketli ya da tipik biçimler)
final RegExp rxPhoneLabel = RegExp(
  r'\b(tel\.?|telefon)\b',
  caseSensitive: false,
);
final RegExp rxPhoneClassic = RegExp(
  r'(\+?90|0)?\s*\(?\d{3,4}\)?[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}',
);

// 10-11 haneli rakam (VKN/TCKN adayı)
final RegExp rxTenElevenDigits = RegExp(r'\b\d{10,11}\b');

// Fiş No
final RegExp rxReceiptNo = RegExp(
  r'(fiş\s*no|fis\s*no|fiş:|f\.?no)\s*[:#\-]*\s*([A-Za-z0-9\-\/]{2,12})',
  caseSensitive: false,
);

// Vergi dairesi
final RegExp rxTaxOfficeKey = RegExp(
  r'\bvergi\s*da[iı]resi\b',
  caseSensitive: false,
);

// Header’ı durduran anahtarlar (adres toplamayı keser)
final RegExp rxHeaderStopWords = RegExp(
  r'\b(bilgi\s*f(i|ı)şi|tür[:\s]|müşteri|belge\s*no|ettn|e[-\s]?arşiv|fiş\s*no|tar(i|ı)h|saat)\b',
  caseSensitive: false,
);

// Sadece "fiyat" satırı mı? (yazı yok, sonda fiyat var)
bool isPriceOnlyLine(String l) {
  final noLetters = !RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(l);
  return noLetters && rxPriceAtEnd.hasMatch(l);
}

// Divider
final RegExp rxDivider = RegExp(r'^[-—–_=\.]{5,}$');

// Ürün kalıpları
// Eski:
// final RegExp rxVat = RegExp(r'%\s?(\d{1,2})');

// Yeni: %, º, °, o, O (OCR sapmaları) hepsini kabul et
final RegExp rxVat = RegExp(r'[%º°oO]\s?(\d{1,2})');
// final RegExp rxPriceAtEnd = RegExp(r'[*]?\s*([0-9]+[.,][0-9]{2})\s*$');
// (Aynı kalabilir ama net olsun diye) fiyat regex'ini satır sonu boşluklarına toleranslı tutuyoruz
final RegExp rxPriceAtEnd = RegExp(r'[*]?\s*([0-9]+[.,][0-9]{2})\s*$');
final RegExp rxQtyUnit = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*[xX]\s*([0-9]+[.,][0-9]{2})',
);
final RegExp rxWeightUnit = RegExp(
  r'(\d+(?:[.,]\d+)?)[ ]*(kg|g)\s*[xX]?\s*([0-9]+[.,][0-9]{2})',
  caseSensitive: false,
);

// ARA TOP / ARA TOPLAM
final RegExp rxAraTopHeader = RegExp(
  r'^ara\s*top(lam)?\.?$',
  caseSensitive: false,
);
final RegExp rxDiscountValue = RegExp(
  r'([-+*]?\s*[0-9]+[.,][0-9]{2})\s*-\s*[Dd]$',
);

// Ödeme & provizyon
final RegExp rxPaymentMethod = RegExp(
  r'(kredi\s*kart[ıi]|banka\s*kart[ıi]|nakit)',
  caseSensitive: false,
);
final RegExp rxProvision = RegExp(
  r'provizyon\s*no[:\s]*([0-9]+)',
  caseSensitive: false,
);

// ——— helpers ———

double? parsePrice(String raw) {
  final cleaned = raw.replaceAll('*', '').replaceAll(' ', '');
  final withDot =
      cleaned.contains(',')
          ? cleaned.replaceAll('.', '').replaceAll(',', '.')
          : cleaned;
  try {
    return double.parse(withDot);
  } catch (_) {
    return null;
  }
}

int? parseVat(String line) {
  final m = rxVat.firstMatch(line);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

DateTime? tryParseDateFlexible(String s) {
  final cleaned = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final sep =
      cleaned.contains('/')
          ? '/'
          : (cleaned.contains('.') ? '.' : (cleaned.contains('-') ? '-' : ' '));
  final parts = cleaned.split(sep);
  if (parts.length < 3) return null;
  try {
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    var year = int.parse(parts[2]);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

String normalizeSpaces(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
