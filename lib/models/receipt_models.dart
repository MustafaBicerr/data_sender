// lib/models/receipt_models.dart
// Türkçe fişler için model seti

class ReceiptHeader {
  final String? businessName; // İşletme adı (üst satırlar, genelde büyük harf)
  final String? address; // Adres (Cadde/Sok./Mah./No... vb. anahtarlar)
  final String? phone; // Opsiyonel telefon
  final String? taxOffice; // Vergi dairesi adı (opsiyonel)
  final String? taxNumber; // Vergi numarası (10 hane)
  final DateTime? date; // Tarih (çeşitli formatlar)
  final String? time; // Saat (hh:mm[:ss])
  final String? receiptNo; // Fiş No (4-6 hane vs)
  final double confidence; // Parser güven puanı (0..1)
  const ReceiptHeader({
    this.businessName,
    this.address,
    this.phone,
    this.taxOffice,
    this.taxNumber,
    this.date,
    this.time,
    this.receiptNo,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'address': address,
      'phone': phone,
      'taxOffice': taxOffice,
      'taxNumber': taxNumber,
      'date': date?.toIso8601String(),
      'time': time,
      'receiptNo': receiptNo,
      'confidence': confidence,
    };
  }
}

class LineItem {
  final String name; // Ürün adı (uzun olabilir, satır kayabilir)
  final double? quantity; // Adet (örn: 3 X 6,95)
  final double? unitPrice; // Birim fiyat
  final String? weightUnit; // "kg" | "g" gibi
  final double? weight; // Ağırlık (örn: 1,535 kg)
  final int? vatPercent; // %01, %08, %18 vb.
  final double totalPrice; // Satır toplamı (adet*birim veya ağırlık*kg fiyat)
  final bool priceWasComputed; // Toplamı kendimiz mi hesapladık?

  const LineItem({
    required this.name,
    required this.totalPrice,
    this.quantity,
    this.unitPrice,
    this.weightUnit,
    this.weight,
    this.vatPercent,
    this.priceWasComputed = false,
  });
  // >>> BURAYI EKLEYİN <<<
  LineItem copyWith({
    String? name,
    double? quantity,
    double? weight,
    String? weightUnit,
    double? unitPrice,
    int? vatPercent,
    double? totalPrice,
    bool? priceWasComputed,
  }) {
    return LineItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      unitPrice: unitPrice ?? this.unitPrice,
      vatPercent: vatPercent ?? this.vatPercent,
      totalPrice: totalPrice ?? this.totalPrice,
      priceWasComputed: priceWasComputed ?? this.priceWasComputed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'weightUnit': weightUnit,
      'weight': weight,
      'vatPercent': vatPercent,
      'totalPrice': totalPrice,
      'priceWasComputed': priceWasComputed,
    };
  }
}

class DiscountLine {
  final String name; // İndirim satırı adı
  final double amount; // Negatif değer şeklinde normalize (örn: -3,00)
  const DiscountLine({required this.name, required this.amount});

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount};
  }
}

class ReceiptTotals {
  final double? topKdv; // TOPKDV
  final double? total; // TOPLAM
  final String? paymentMethod; // "KREDİ KARTI", "NAKİT", vb.
  final String? bank; // Opsiyonel banka adı
  final String? provisionNo; // Provizyon No
  const ReceiptTotals({
    this.topKdv,
    this.total,
    this.paymentMethod,
    this.bank,
    this.provisionNo,
  });
  Map<String, dynamic> toJson() {
    return {
      'topKdv': topKdv,
      'total': total,
      'paymentMethod': paymentMethod,
      'bank': bank,
      'provisionNo': provisionNo,
    };
  }
}

class ReceiptParseResult {
  final ReceiptHeader header;
  final List<LineItem> items;
  final List<DiscountLine> discounts;
  final ReceiptTotals totals;
  final List<String> misc; // Diğer yakalanamayan ama önemli olabilecek satırlar

  const ReceiptParseResult({
    required this.header,
    required this.items,
    required this.discounts,
    required this.totals,
    this.misc = const [],
  });
  Map<String, dynamic> toJson() {
    return {
      'header': header.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
      'discounts': discounts.map((e) => e.toJson()).toList(),
      'totals': totals.toJson(),
      'misc': misc,
    };
  }
}
