// lib/models/invoice_model.dart
import 'package:uuid/uuid.dart';

/// Fatura / fiş verisini tutan model.
/// JSON serialize/deserialize'ı kolaylaştırmak için basit yapı.
class InvoiceField {
  String id;
  String name; // alan ismi (örn. "Tarih", "Tutar", "TC")
  String value; // OCR'den gelen/değiştirilen değer
  bool validated; // doğrulama sonucu (örn. TC doğrulandı mı)

  InvoiceField({
    String? id,
    required this.name,
    required this.value,
    this.validated = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'validated': validated,
  };

  static InvoiceField fromJson(Map<String, dynamic> j) => InvoiceField(
    id: j['id'],
    name: j['name'],
    value: j['value'],
    validated: j['validated'] ?? false,
  );
}

class InvoiceModel {
  String id;
  DateTime createdAt;
  List<InvoiceField> fields;

  InvoiceModel({String? id, DateTime? createdAt, List<InvoiceField>? fields})
    : id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now(),
      fields = fields ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  static InvoiceModel fromJson(Map<String, dynamic> j) => InvoiceModel(
    id: j['id'],
    createdAt: DateTime.parse(j['createdAt']),
    fields:
        (j['fields'] as List<dynamic>)
            .map((e) => InvoiceField.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
  );
}
