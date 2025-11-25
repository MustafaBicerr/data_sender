// import 'dart:io';
// import 'dart:typed_data';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:pdfx/pdfx.dart';

// enum PickMode { camera, files }

// class OcrService {
//   final ImagePicker _picker = ImagePicker();

//   // --- küçük yardımcı: kontrollü log ---
//   void _log(String msg) {
//     // debugPrint wrapWidth ile uzun logları kesmez:
//     debugPrint('[OCR] $msg');
//   }

//   Future<String?> pickAndRecognize({required PickMode mode}) async {
//     _log('pickAndRecognize mode=$mode');
//     final sw = Stopwatch()..start();

//     try {
//       if (mode == PickMode.camera) {
//         final file = await _pickImageFromCamera();
//         _log('camera: _pickImageFromCamera -> ${file?.path}');
//         if (file == null) return null;

//         if (file.path.toLowerCase().endsWith('.pdf')) {
//           _log('camera: got PDF, rasterizing first page…');
//           final img = await _rasterizePdfFirstPage(
//             File(file.path),
//             dpiScale: 2.0,
//           );
//           _log('camera: raster result -> ${img?.path}');
//           if (img == null) return null;
//           final text = await _recognizeImage(img);
//           _log('camera: OCR text length = ${text.length}');
//           return text;
//         } else {
//           final text = await _recognizeImage(file);
//           _log('camera: OCR text length = ${text.length}');
//           return text;
//         }
//       } else {
//         // FILES
//         _log('files: opening picker…');
//         final result = await FilePicker.platform.pickFiles(
//           type: FileType.custom,
//           allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
//           withData: false,
//         );
//         _log(
//           'files: result is null? ${result == null}, count=${result?.files.length}',
//         );
//         if (result == null || result.files.isEmpty) return null;

//         final path = result.files.single.path!;
//         _log('files: picked path=$path');
//         if (path.toLowerCase().endsWith('.pdf')) {
//           _log('files: PDF selected, rasterizing…');
//           final imageFile = await _rasterizePdfFirstPage(
//             File(path),
//             dpiScale: 2.0,
//           );
//           _log('files: raster result -> ${imageFile?.path}');
//           if (imageFile == null) return null;
//           final text = await _recognizeImage(imageFile);
//           _log('files: OCR text length = ${text.length}');
//           return text;
//         } else {
//           final text = await _recognizeImage(File(path));
//           _log('files: OCR text length = ${text.length}');
//           return text;
//         }
//       }
//     } catch (e, st) {
//       _log('pickAndRecognize EX: $e\n$st');
//       rethrow;
//     } finally {
//       _log('pickAndRecognize done in ${sw.elapsedMilliseconds} ms');
//     }
//   }

//   // ——————————————————————————————————————————————————————————————

//   Future<File?> _pickImageFromCamera() async {
//     _log('_pickImageFromCamera: using flutter_doc_scanner…');
//     try {
//       final dynamic scanned = await FlutterDocScanner().getScannedDocumentAsPdf(
//         page: 4,
//       );
//       _log('_pickImageFromCamera: scanned runtimeType=${scanned.runtimeType}');
//       _log('_pickImageFromCamera: scanned str=$scanned');

//       final path = _extractPath(scanned);
//       _log('_pickImageFromCamera: extracted path=$path');

//       if (path != null) {
//         final f = File(path);
//         final exists = await f.exists();
//         final size = exists ? (await f.length()) : -1;
//         _log(
//           '_pickImageFromCamera: file exists=$exists, size=$size bytes, ext=${p.extension(path)}',
//         );
//         return exists ? f : null;
//       }

//       // fallback: image picker (kamera)
//       _log(
//         '_pickImageFromCamera: doc_scanner returned no path, fallback to ImagePicker…',
//       );
//       final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
//       _log('_pickImageFromCamera: image_picker -> ${picked?.path}');
//       if (picked == null) return null;
//       final f = File(picked.path);
//       final exists = await f.exists();
//       _log('_pickImageFromCamera: fallback file exists=$exists');
//       return exists ? f : null;
//     } on PlatformException catch (e) {
//       _log('_pickImageFromCamera PlatformException: $e');
//       return null;
//     } catch (e, st) {
//       _log('_pickImageFromCamera EX: $e\n$st');
//       return null;
//     }
//   }

//   // 1) Path çıkarıcıyı pdfUri / imageUri / uri için genişlet
//   String? _extractPath(dynamic scanned) {
//     if (scanned == null) return null;

//     // Düz string dönerse
//     if (scanned is String) return _normalizeMaybeUri(scanned);

//     // Liste gelirse ilk elemana bak
//     if (scanned is List && scanned.isNotEmpty) {
//       return _extractPath(scanned.first);
//     }

//     // Map dönerse yaygın anahtarları kontrol et
//     if (scanned is Map) {
//       // log için istersen:
//       // debugPrint('[OCR] _extractPath map keys=${scanned.keys.map((e)=>e.toString()).toList()}');

//       final candidates = <String>[
//         'path', 'filePath', 'pdfPath', // bazı sürümler
//         'pdfUri', 'imageUri', 'uri', // SENDE GÖRÜLEN: pdfUri
//       ];

//       for (final key in candidates) {
//         final v = scanned[key];
//         if (v is String && v.isNotEmpty) {
//           return _normalizeMaybeUri(v);
//         }
//       }
//     }

//     return null;
//   }

//   // 2) URI ise path'e çevir, değilse olduğu gibi dön
//   String _normalizeMaybeUri(String input) {
//     // file:///… ise doğrudan path'e çevir
//     if (input.startsWith('file://')) {
//       try {
//         return Uri.parse(input).toFilePath();
//       } catch (_) {
//         // parse edemezse en azından 'file://' prefix'ini söküp deneriz
//         return input.replaceFirst('file://', '');
//       }
//     }
//     // content:// gelirse burada ek çözüm gerekir (sende file://)
//     return input;
//   }

//   // ——————————————————————————————————————————————————————————————

//   Future<File?> _rasterizePdfFirstPage(
//     File pdfFile, {
//     double dpiScale = 2.0,
//   }) async {
//     final sw = Stopwatch()..start();
//     _log('_rasterizePdfFirstPage: in=${pdfFile.path}');
//     try {
//       final exists = await pdfFile.exists();
//       final size = exists ? (await pdfFile.length()) : -1;
//       _log('_rasterizePdfFirstPage: pdf exists=$exists, size=$size bytes');

//       if (!exists) return null;
//       final doc = await PdfDocument.openFile(pdfFile.path);
//       _log('_rasterizePdfFirstPage: pages=${doc.pagesCount}');
//       if (doc.pagesCount < 1) return null;

//       final page = await doc.getPage(1);
//       final targetW = page.width * dpiScale;
//       final targetH = page.height * dpiScale;
//       _log(
//         '_rasterizePdfFirstPage: render size=${targetW}x$targetH, scale=$dpiScale',
//       );

//       final pageImage = await page.render(
//         width: targetW,
//         height: targetH,
//         format: PdfPageImageFormat.png,
//       );
//       await page.close();

//       if (pageImage == null) {
//         _log('_rasterizePdfFirstPage: render returned null image');
//         await doc.close();
//         return null;
//       }

//       final dir = await getTemporaryDirectory();
//       final out = File(
//         p.join(
//           dir.path,
//           'ocr_pdf_${DateTime.now().millisecondsSinceEpoch}.png',
//         ),
//       );
//       await out.writeAsBytes(pageImage.bytes, flush: true);
//       final outSize = await out.length();
//       _log('_rasterizePdfFirstPage: out=${out.path}, size=$outSize bytes');

//       await doc.close();
//       return out;
//     } catch (e, st) {
//       _log('_rasterizePdfFirstPage EX: $e\n$st');
//       return null;
//     } finally {
//       _log('_rasterizePdfFirstPage done in ${sw.elapsedMilliseconds} ms');
//     }
//   }

//   Future<String> _recognizeImage(File imageFile) async {
//     final sw = Stopwatch()..start();
//     try {
//       final exists = await imageFile.exists();
//       final size = exists ? (await imageFile.length()) : -1;
//       _log(
//         '_recognizeImage: file=${imageFile.path}, exists=$exists, size=$size',
//       );

//       final inputImage = InputImage.fromFile(imageFile);

//       // Script belirt: latin (çoğu fatura için yeterli)
//       final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
//       final result = await recognizer.processImage(inputImage);
//       await recognizer.close();

//       final text = result.text;
//       final preview = text.replaceAll('\n', ' ').take(120);
//       _log('_recognizeImage: chars=${text.length}, preview="$preview"');
//       return text;
//     } catch (e, st) {
//       _log('_recognizeImage EX: $e\n$st');
//       rethrow;
//     } finally {
//       _log('_recognizeImage done in ${sw.elapsedMilliseconds} ms');
//     }
//   }
// }

// // küçük extension: log önizleme için
// extension _Take on String {
//   String take(int n) => (length <= n) ? this : substring(0, n) + '…';
// }

// lib/services/ocr_service.dart
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum PickMode { camera, files }

/// Küçük veri sınıfları (koordinat tabanlı parse için)
class OcrElement {
  final String text;
  final Rect box;
  OcrElement({required this.text, required this.box});
  double get centerX => box.left + box.width / 2;
  double get centerY => box.top + box.height / 2;
  double get height => box.height;
}

class OcrResult {
  final String fullText;
  final List<OcrElement> elements;
  OcrResult({required this.fullText, required this.elements});
  bool get hasGeometry => elements.isNotEmpty;
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final ImagePicker _imagePicker = ImagePicker();

  // 🟢 son taramanın ham sonucu
  OcrResult? lastResult;

  // 🟢 sadece element listesine kolay erişim için getter
  List<OcrElement> get lastElements => lastResult?.elements ?? [];
  // final TextRecognizer _recognizer = TextRecognizer(
  //   script: TextRecognitionScript.latin,
  // );

  /// Mevcut çağrıları bozmamak için koruduk.
  Future<String?> pickAndRecognize({required PickMode mode}) async {
    final res = await pickAndRecognizeWithGeometry(mode: mode);
    return res?.fullText;
  }

  /// Yeni: tek string + koordinatlar
  Future<OcrResult?> pickAndRecognizeWithGeometry({
    required PickMode mode,
  }) async {
    try {
      debugPrint('[OCR] pickAndRecognize mode=$mode');

      // — Şimdilik sadece dosyadan (foto/pdf -> raster) akışı veriyoruz:
      // (Projende kamera varsa aynı şekilde InputImage.fromFile kullan)
      File? file;

      if (mode == PickMode.files) {
        debugPrint('[OCR] files: opening picker…');
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        );

        if (res == null || res.files.isEmpty) {
          debugPrint('[OCR] files: user cancelled');
          return null;
        }
        final path = res.files.single.path!;
        file = File(path);
        debugPrint('[OCR] files: picked path=$path');
      } else if (mode == PickMode.camera) {
        // 📷 KAMERADAN TARA
        final picked = await _imagePicker.pickImage(source: ImageSource.camera);
        if (picked == null) return null;
        file = File(picked.path);
      } else {
        // Kamerayı da kullanacaksan burada kendi image picker akışını ekleyebilirsin.
        // Şimdilik dosya ile aynı davranalım:
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png'],
        );
        if (res == null || res.files.isEmpty) return null;
        file = File(res.files.single.path!);
      }

      if (file == null || !file.existsSync()) return null;

      debugPrint(
        '[OCR] _recognizeImage: file=${file.path}, exists=${file.existsSync()}, size=${file.lengthSync()}',
      );
      final input = InputImage.fromFile(file);
      final sw = Stopwatch()..start();
      final recognized = await _recognizer.processImage(input);
      debugPrint(
        '[OCR] _recognizeImage: chars=${recognized.text.length}, preview="${recognized.text.substring(0, recognized.text.length.clamp(0, 120))}…"',
      );
      debugPrint('[OCR] _recognizeImage done in ${sw.elapsedMilliseconds} ms');

      // Geometri topla
      final elems = <OcrElement>[];
      for (final b in recognized.blocks) {
        for (final l in b.lines) {
          for (final e in l.elements) {
            final r = e.boundingBox;
            if (r == null) continue;
            elems.add(OcrElement(text: e.text, box: r));
          }
        }
      }

      lastResult = OcrResult(fullText: recognized.text, elements: elems);
      return lastResult;

      // return OcrResult(fullText: recognized.text, elements: elems);
    } catch (e, st) {
      debugPrint('[OCR] EX: $e\n$st');
      return null;
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
