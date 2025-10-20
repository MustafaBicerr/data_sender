// lib/services/storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_model.dart';

/// Dosya tabanlı (file-state) storage.
/// - Her fatura için ayrı json dosyası
/// - Tüm faturalar index dosyasında tutulur
class StorageService {
  static const _indexFile = 'invoices_index.json';

  Future<Directory> _appDir() async => await getApplicationDocumentsDirectory();

  Future<File> _fileForId(String id) async {
    final dir = await _appDir();
    return File('${dir.path}/invoice_$id.json');
  }

  Future<File> _index() async {
    final dir = await _appDir();
    return File('${dir.path}/$_indexFile');
  }

  Future<List<InvoiceModel>> loadAll() async {
    final idx = await _index();
    if (!idx.existsSync()) return [];
    final text = await idx.readAsString();
    final list = (jsonDecode(text) as List<dynamic>).cast<String>();
    final out = <InvoiceModel>[];
    for (final id in list) {
      final f = await _fileForId(id);
      if (!f.existsSync()) continue;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      out.add(InvoiceModel.fromJson(j));
    }
    return out;
  }

  Future<void> saveInvoice(InvoiceModel inv) async {
    final f = await _fileForId(inv.id);
    await f.writeAsString(jsonEncode(inv.toJson()));
    // index update
    final idx = await _index();
    List<String> list = [];
    if (idx.existsSync()) {
      list =
          (jsonDecode(await idx.readAsString()) as List<dynamic>)
              .cast<String>();
      if (!list.contains(inv.id)) list.add(inv.id);
    } else {
      list = [inv.id];
    }
    await idx.writeAsString(jsonEncode(list));
  }

  Future<void> deleteInvoice(String id) async {
    final f = await _fileForId(id);
    if (f.existsSync()) await f.delete();
    final idx = await _index();
    if (!idx.existsSync()) return;
    final list =
        (jsonDecode(await idx.readAsString()) as List<dynamic>).cast<String>();
    list.remove(id);
    await idx.writeAsString(jsonEncode(list));
  }
}
