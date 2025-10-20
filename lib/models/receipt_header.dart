// class ReceiptHeader {
//   final String? businessName;
//   final String? address;
//   final String? phone;
//   final String?
//   taxOffice; // vergi dairesi adı (opsiyonel - bazı fişlerde var bazılarında yok)
//   final String? taxNumber; // vergi numarası (VKN)
//   final DateTime? date; //fiş tarihisi
//   final String? time; // fiş saati
//   final String? receiptNo; //fiş no
//   final double confidence; // genel güven skoru (0-1)

//   ReceiptHeader({
//     this.businessName,
//     this.address,
//     this.phone,
//     this.taxOffice,
//     this.taxNumber,
//     this.date,
//     this.time,
//     this.receiptNo,
//     this.confidence = 0.0,
//   });

//   Map<String, dynamic> toJson() => {
//     'businessName': businessName,
//     'address': address,
//     'phone': phone,
//     'taxOffice': taxOffice,
//     'taxNumber': taxNumber,
//     'date': date?.toIso8601String(),
//     'time': time,
//     'receiptNo': receiptNo,
//     'confidence': confidence,
//   };
// }
