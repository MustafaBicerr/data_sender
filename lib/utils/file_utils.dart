// lib/utils/file_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;

/// Basit yardımcı metodlar (dosya isimlendirme vb.)
String safeFileName(String s) {
  return s.replaceAll(RegExp(r'[^A-Za-z0-9_\-\.]'), '_');
}

Future<bool> fileExists(String path) async {
  return File(path).exists();
}
