// lib/services/validators.dart
/// Burada TC Kimlik doğrulama algoritması ve bazı basit regex doğrulamaları var.
/// Daha fazla ülke/alan için algoritma ekleyebiliriz.

class Validators {
  /// Türkiye TC Kimlik Numarası doğrulaması.
  /// 11 rakam, ilk rakam 0 olamaz.
  /// 10. rakam = ( (sum odd (1..9) * 7) - sum even (2..8) ) mod 10
  /// 11. rakam = sum(first 10 digits) mod 10
  static bool isValidTCKN(String s) {
    final cleaned = s.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 11) return false;
    if (cleaned[0] == '0') return false;
    final digits = cleaned.split('').map(int.parse).toList();
    final sumOdd = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
    final sumEven = digits[1] + digits[3] + digits[5] + digits[7];
    final tenth = ((sumOdd * 7) - sumEven) % 10;
    final sumFirst10 = digits.sublist(0, 10).reduce((a, b) => a + b);
    final eleventh = sumFirst10 % 10;
    return digits[9] == tenth && digits[10] == eleventh;
  }

  /// Basit vergi kimlik numarası kontrolü (Türkiye: 10 haneli).
  static bool looksLikeTaxId(String s) {
    final cleaned = s.replaceAll(RegExp(r'\D'), '');
    return cleaned.length == 10; // placeholder
  }

  /// Basit fatura numarası için regex (alfa-numerik ve -/_ karakterleri)
  static bool looksLikeInvoiceNo(String s) {
    final cleaned = s.trim();
    return RegExp(r'^[A-Za-z0-9\-_\/]{3,50}$').hasMatch(cleaned);
  }

  /// Tarih tespiti: yyyy-mm-dd veya dd.mm.yyyy gibi formatları yakalamaya çalış.
  static bool looksLikeDate(String s) {
    final clean = s.trim();
    if (RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}$').hasMatch(clean)) return true;
    if (RegExp(r'^\d{1,2}[.]\d{1,2}[.]\d{4}$').hasMatch(clean)) return true;
    return false;
  }

  /// Tutar/para alanı için basit regex (örn. 1,234.56 ya da 1234,56 veya 1234)
  static bool looksLikeAmount(String s) {
    final cleaned = s.replaceAll(' ', '');
    return RegExp(r'^[\d\.,]+$').hasMatch(cleaned);
  }
}
