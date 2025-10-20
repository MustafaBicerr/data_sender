// lib/state/invoice_state.dart
import 'package:flutter/material.dart';
import '../models/invoice_model.dart';
import '../services/storage_service.dart';

/// ChangeNotifier tabanlı invoice state.
/// - bir invoice üzerinde düzenleme yapma
/// - tüm faturaları yükleme / kaydetme
class InvoiceState extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<InvoiceModel> invoices = [];
  InvoiceModel? current;

  Future<void> loadAll() async {
    invoices = await _storage.loadAll();
    notifyListeners();
  }

  void createNewInvoice() {
    current = InvoiceModel();
    notifyListeners();
  }

  void setCurrent(InvoiceModel inv) {
    current = inv;
    notifyListeners();
  }

  Future<void> saveCurrent() async {
    if (current == null) return;
    await _storage.saveInvoice(current!);
    await loadAll();
  }

  Future<void> deleteInvoice(String id) async {
    await _storage.deleteInvoice(id);
    await loadAll();
  }

  void updateFieldValue(String fieldId, String newValue) {
    if (current == null) return;
    final fIndex = current!.fields.indexWhere((f) => f.id == fieldId);
    if (fIndex == -1) return;
    current!.fields[fIndex].value = newValue;
    current!.fields[fIndex].validated = false; // yeniden doğrula
    notifyListeners();
  }

  void reorderFields(int oldIndex, int newIndex) {
    if (current == null) return;
    final list = current!.fields;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    notifyListeners();
  }

  void addField(InvoiceField f) {
    current?.fields.add(f);
    notifyListeners();
  }

  void removeField(String id) {
    current?.fields.removeWhere((f) => f.id == id);
    notifyListeners();
  }
}
