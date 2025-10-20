// // lib/screens/scan_screen.dart
// import 'dart:io';
// import 'package:data_sender/services/receipt_body_parser.dart'
//     show LineItem; // sadece modelini kullanacağız
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/ocr_service.dart';
// import '../state/invoice_state.dart';
// import '../models/invoice_model.dart';
// import '../services/validators.dart';
// import 'edit_invoice_screen.dart';
// import '../theme/app_theme.dart';
// import '../services/receipt_parser.dart';
// import '../models/receipt_header.dart';

// class ScanScreen extends StatefulWidget {
//   final bool fromFiles; // true ise dosyadan (foto ya da PDF)
//   const ScanScreen({super.key, this.fromFiles = false});

//   @override
//   State<ScanScreen> createState() => _ScanScreenState();
// }

// class _ScanScreenState extends State<ScanScreen> {
//   final OcrService _ocr = OcrService();
//   bool _busy = false;
//   String? _lastError;

//   Future<void> _scanCamera() async {
//     await _runScan(pickMode: PickMode.camera);
//   }

//   Future<void> _scanFromFiles() async {
//     await _runScan(pickMode: PickMode.files);
//   }

//   // ---------------------- yardımcılar (yalnızca bu dosyada) ----------------------

//   // OCR sayılarını Double'a çevir (1.234,56 -> 1234.56)
//   double? _toAmount(String s) {
//     final m = RegExp(r'([0-9]{1,3}(?:[.\s][0-9]{3})*,[0-9]{2})').firstMatch(s);
//     if (m == null) return null;
//     final norm = m
//         .group(1)!
//         .replaceAll(RegExp(r'[.\s]'), '')
//         .replaceAll(',', '.');
//     return double.tryParse(norm);
//   }

//   // satır bir fiyat satırı mı?  *9,95  / ⁎22,50  / ✱3,50 ...
//   bool _isPriceLine(String s) {
//     final price = _toAmount(s);
//     if (price == null) return false;
//     // başında '*' benzeri bir sembol var mı?
//     final hasStar = RegExp(
//       r'^[\*\u204E\u00D7\u2715\u2731\u22C6\u2219]?\s*',
//     ).hasMatch(s);
//     return hasStar;
//   }

//   // satır KDV yüzdesi mi?  %8  %18  %01 (bazı fişlerde %01)
//   int? _vatFromLine(String s) {
//     final m = RegExp(r'%\s*([0-9]{1,2})').firstMatch(s);
//     if (m == null) return null;
//     return int.tryParse(m.group(1)!);
//   }

//   // başlık/ayraç olabilecek anahtarlar
//   final _stopWords = <String>{
//     'TOPLAM',
//     'TOPKDV',
//     'KDV Oranı KDV Dahil Tutar',
//     'KREDI KARTI',
//     'NAKIT',
//     'Müsteri ismi:',
//     'MÜŞTERİ İSMİ:',
//     'EKO NO',
//     'Belge No',
//     'Mersis No',
//   };

//   // Body başlangıcını tahmin et: önce '%..' görülen ve
//   // en yakın 5 satır içinde bir fiyat ('*..') bulunan ilk blok.
//   int _findBodyStartIndex(List<String> lines, void Function(String) log) {
//     for (int i = 0; i < lines.length; i++) {
//       final v = _vatFromLine(lines[i]);
//       if (v == null) continue;

//       // Ürünün adı bir önceki ya da aynı blok içinde olur; yakınlarda fiyat aranır
//       final windowEnd = (i + 5).clamp(0, lines.length - 1);
//       bool hasPriceSoon = false;
//       for (int j = i; j <= windowEnd; j++) {
//         if (_isPriceLine(lines[j])) {
//           hasPriceSoon = true;
//           break;
//         }
//       }
//       // başlık kelimelerinin içinde kalmasın
//       final prev = i > 0 ? lines[i - 1] : '';
//       final looksLikeName =
//           prev.isNotEmpty &&
//           !_stopWords.any(
//             (w) => prev.toUpperCase().contains(w.toUpperCase()),
//           ) &&
//           !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(prev) &&
//           _toAmount(prev) == null;

//       if (hasPriceSoon && looksLikeName) {
//         log('▶ body start by pattern at L$i: "${lines[i]}"');
//         return i - 1; // ürün adı satırından başlat
//       }
//     }
//     log('… body start not found; fallback to 0');
//     return 0;
//   }

//   // Body’yi satır satır çıkar.
//   // Basit model: [Ad] -> (vat satırı) -> (birkaç satır sonra) fiyat satırı
//   List<LineItem> _parseBody(List<String> lines, void Function(String) log) {
//     final items = <LineItem>[];
//     if (lines.isEmpty) return items;

//     final start = _findBodyStartIndex(lines, log);
//     int? pendingVat;
//     String? pendingName;

//     for (int i = start; i < lines.length; i++) {
//       final s = lines[i];

//       if (_stopWords.any((w) => s.toUpperCase().contains(w.toUpperCase()))) {
//         log('— stop at L$i "$s"');
//         break;
//       }

//       final maybeVat = _vatFromLine(s);
//       if (maybeVat != null) {
//         pendingVat = maybeVat;
//         continue;
//       }

//       if (_isPriceLine(s)) {
//         final price = _toAmount(s);
//         if (price != null && pendingName != null) {
//           items.add(
//             LineItem(
//               name: pendingName!,
//               totalPrice: price,
//               vatPercent: pendingVat,
//             ),
//           );
//           log(
//             '  √ ITEM name="$pendingName" vat=${pendingVat ?? '-'} total=$price',
//           );
//           // aynı kalemde ardışık fiyatlar gelmiyorsa adı sıfırla
//           pendingName = null;
//           continue;
//         }
//       }

//       // Bu nokta ürün adı olabilir (sayı/fiyat değil, saat değil)
//       final isNumberish = _toAmount(s) != null || RegExp(r'^\d').hasMatch(s);
//       final isTime = RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s);
//       if (!isNumberish && !isTime) {
//         pendingName = s;
//         log('  + queue NAME "$s"');
//       }
//     }

//     return items;
//   }

//   // TOPKDV/TOPLAM çek
//   ({double? topkdv, double? toplam}) _extractTotals(List<String> lines) {
//     double? topkdv;
//     double? toplam;

//     for (int i = 0; i < lines.length; i++) {
//       final s = lines[i].toUpperCase();
//       if (s.contains('TOPKDV')) {
//         // aynı satırda ya da bir sonraki satırda olabilir
//         topkdv =
//             _toAmount(lines[i]) ??
//             (i + 1 < lines.length ? _toAmount(lines[i + 1]) : null);
//       } else if (s.contains('TOPLAM')) {
//         toplam =
//             _toAmount(lines[i]) ??
//             (i + 1 < lines.length ? _toAmount(lines[i + 1]) : null);
//       }
//     }
//     return (topkdv: topkdv, toplam: toplam);
//   }

//   String _formatLineItem(LineItem it) {
//     final parts = <String>[];
//     parts.add(it.name);
//     if (it.vatPercent != null) parts.add('%${it.vatPercent}');
//     parts.add('= ${it.totalPrice.toStringAsFixed(2)}');
//     return parts.join('  ');
//   }

//   // -----------------------------------------------------------------------------

//   Future<void> _runScan({required PickMode pickMode}) async {
//     setState(() {
//       _busy = true;
//       _lastError = null;
//     });

//     try {
//       debugPrint('[SCAN] start pickMode=$pickMode');
//       final text = await _ocr.pickAndRecognize(mode: pickMode);
//       if (text == null || text.trim().isEmpty) {
//         setState(() {
//           _busy = false;
//           _lastError = 'Metin bulunamadı veya iptal edildi.';
//         });
//         return;
//       }

//       // ---- State hazırlığı
//       final s = Provider.of<InvoiceState>(context, listen: false);
//       final inv = s.current ?? InvoiceModel();
//       s.setCurrent(inv);
//       inv.fields.clear();

//       // ---- HEADER
//       final header = ReceiptParser2().parseHeaderOnly(text);

//       void add(String name, String? value) {
//         if (value != null && value.trim().isNotEmpty) {
//           inv.fields.add(InvoiceField(name: name, value: value.trim()));
//         }
//       }

//       add('İşletme Adı', header.businessName);
//       add('Adres', header.address);
//       add('Telefon', header.phone);
//       add('Vergi Dairesi', header.taxOffice);
//       add('Vergi No', header.taxNumber);
//       if (header.date != null) {
//         add('Tarih', header.date!.toIso8601String().split('T').first);
//       }
//       add('Saat', header.time);
//       add('Fiş No', header.receiptNo);

//       // ---- BODY
//       final lines =
//           text
//               .split(RegExp(r'[\r\n]+'))
//               .map((s) => s.trim())
//               .where((s) => s.isNotEmpty)
//               .toList();

//       debugPrint('[SEQ] parsing started; lines=${lines.length}');
//       final items = _parseBody(lines, (m) => debugPrint('[SEQ] $m'));
//       final totals = _extractTotals(lines);

//       for (final it in items) {
//         inv.fields.add(
//           InvoiceField(
//             name: 'Ürün',
//             value: _formatLineItem(it),
//             validated: false,
//           ),
//         );
//       }

//       if (totals.topkdv != null) {
//         inv.fields.add(
//           InvoiceField(
//             name: 'TOPKDV',
//             value: totals.topkdv!.toStringAsFixed(2),
//           ),
//         );
//       }
//       if (totals.toplam != null) {
//         inv.fields.add(
//           InvoiceField(
//             name: 'TOPLAM',
//             value: totals.toplam!.toStringAsFixed(2),
//           ),
//         );
//       }

//       debugPrint('[SCAN] pickAndRecognize returned length=${text.length}');
//       await s.saveCurrent();
//       debugPrint('[SCAN] saveCurrent ok, fields=${inv.fields.length}');

//       if (!mounted) return;
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => const EditInvoiceScreen()),
//       );
//     } catch (e, st) {
//       debugPrint('[SCAN] EX: $e\n$st');
//       setState(() {
//         _lastError = e.toString();
//       });
//     } finally {
//       if (mounted) setState(() => _busy = false);
//       debugPrint('[SCAN] done.');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (widget.fromFiles) {
//       WidgetsBinding.instance.addPostFrameCallback((_) => _scanFromFiles());
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Scaffold(
//       body: Column(
//         children: [
//           const GradientHeader(title: 'Belge Tara'),
//           Expanded(
//             child: Center(
//               child:
//                   _busy
//                       ? const CircularProgressIndicator()
//                       : Padding(
//                         padding: const EdgeInsets.all(20),
//                         child: Card(
//                           child: Padding(
//                             padding: const EdgeInsets.all(18),
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(
//                                   Icons.document_scanner,
//                                   size: 56,
//                                   color: cs.primary,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 const Text(
//                                   'Kaynak Seç',
//                                   style: TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: ElevatedButton.icon(
//                                         onPressed: _scanCamera,
//                                         icon: const Icon(Icons.photo_camera),
//                                         label: const Text('Kameradan Tara'),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: ElevatedButton.icon(
//                                         onPressed: _scanFromFiles,
//                                         icon: const Icon(Icons.folder_open),
//                                         label: const Text(
//                                           'Dosyadan Tara (Foto/PDF)',
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 if (_lastError != null) ...[
//                                   const SizedBox(height: 12),
//                                   Text(
//                                     _lastError!,
//                                     style: const TextStyle(color: Colors.red),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// lib/screens/scan_screen.dart
// lib/screens/scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ocr_service.dart';
import '../state/invoice_state.dart';
import '../models/invoice_model.dart';
import '../services/validators.dart';
import 'edit_invoice_screen.dart';
import '../theme/app_theme.dart';
import '../services/receipt_parser.dart'; // ReceiptParser2
import '../models/receipt_header.dart';

// --- Body parserlar: isim çakışmasını önlemek için prefix kullanıyoruz
import '../services/receipt_body_parser.dart' as seq; // satır-satır parser
import '../services/receipt_body_parser_coord.dart'
    as coord; // koordinat tabanlı (opsiyonel)

class ScanScreen extends StatefulWidget {
  final bool fromFiles; // true ise dosyadan (foto ya da PDF)
  const ScanScreen({super.key, this.fromFiles = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final OcrService _ocr = OcrService();
  bool _busy = false;
  String? _lastError;

  Future<void> _scanCamera() async {
    await _runScan(pickMode: PickMode.camera);
  }

  Future<void> _scanFromFiles() async {
    await _runScan(pickMode: PickMode.files);
  }

  Future<void> _runScan({required PickMode pickMode}) async {
    setState(() {
      _busy = true;
      _lastError = null;
    });

    try {
      debugPrint('[SCAN] start pickMode=$pickMode');
      final text = await _ocr.pickAndRecognize(mode: pickMode);

      if (text == null || text.trim().isEmpty) {
        setState(() {
          _busy = false;
          _lastError = 'Metin bulunamadı veya iptal edildi.';
        });
        return;
      }

      // Ham ML Kit metnini kullanıcıya göster (dikey scroll’lu)
      await _showRawTextDialog(text);

      // ---- State hazırlığı
      final s = Provider.of<InvoiceState>(context, listen: false);
      final inv = s.current ?? InvoiceModel();
      s.setCurrent(inv);
      inv.fields.clear();

      // ---- HEADER: sadece header parse et (parseFull yok)
      final header = ReceiptParser2().parseHeaderOnly(text);

      void addField(String name, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          inv.fields.add(InvoiceField(name: name, value: value.trim()));
        }
      }

      addField('İşletme Adı', header.businessName);
      addField('Adres', header.address);
      addField('Telefon', header.phone);
      addField('Vergi Dairesi', header.taxOffice);
      addField('Vergi No', header.taxNumber);
      if (header.date != null) {
        addField('Tarih', header.date!.toIso8601String().split('T').first);
      }
      addField('Saat', header.time);
      addField('Fiş No', header.receiptNo);

      // ---- BODY: önce koordinat tabanlı denenebilir (istersen aç)
      List<coord.LineItem> itemsCoord = const [];
      // Eğer OcrService içinde ML Kit element’larını expose ediyorsan aşağıyı aç:
      final elements =
          _ocr.lastElements; // ör: RecognizedText / TextElement list
      if (elements != null && elements.isNotEmpty) {
        itemsCoord = coord.parseByGeometry(
          elements: elements,
          log: (m) => debugPrint('[COORD] $m'),
        );
      }

      // ---- Sequential fallback veya birincil yol
      final lines =
          text
              .split(RegExp(r'[\r\n]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      debugPrint('[SEQ] parsing started; lines=${lines.length}');
      final itemsSeq = seq.parseBodySequential(
        lines,
        log: (m) => debugPrint('[SEQ] $m'),
      );

      // Hangisini kullanacağımıza karar verelim
      List<_UiLineItem> lineItems;
      if (itemsCoord.isNotEmpty) {
        // koordinat parser sonucu UI modeline dönüştür
        lineItems =
            itemsCoord
                .map(
                  (it) => _UiLineItem(
                    name: it.name,
                    total: it.totalPrice,
                    vatPercent: it.vatPercent,
                    formatted: coord.formatLineItem(it),
                  ),
                )
                .toList();
      } else {
        // sequential sonucu UI modeline dönüştür
        lineItems =
            itemsSeq
                .map(
                  (it) => _UiLineItem(
                    name: it.name,
                    total: it.totalPrice,
                    vatPercent: it.vatPercent?.toDouble(),
                    formatted: seq.formatLineItem(it),
                  ),
                )
                .toList();
      }

      // Toplamlar
      final totals = seq.extractTotals(lines);

      // ---- UI modeline ürünleri ve toplamları ekle
      for (final it in lineItems) {
        inv.fields.add(
          InvoiceField(name: 'Ürün', value: it.formatted, validated: false),
        );
      }

      if (totals.topkdv != null) {
        inv.fields.add(
          InvoiceField(
            name: 'TOPKDV',
            value: totals.topkdv!.toStringAsFixed(2),
          ),
        );
      }
      if (totals.toplam != null) {
        inv.fields.add(
          InvoiceField(
            name: 'TOPLAM',
            value: totals.toplam!.toStringAsFixed(2),
          ),
        );
      }

      debugPrint('[SCAN] pickAndRecognize returned length=${text.length}');
      await s.saveCurrent();
      debugPrint('[SCAN] saveCurrent ok, fields=${inv.fields.length}');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EditInvoiceScreen()),
      );
    } catch (e, st) {
      debugPrint('[SCAN] EX: $e\n$st');
      setState(() {
        _lastError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      debugPrint('[SCAN] done.');
    }
  }

  /// Ham OCR metnini gösteren, dikey scroll’lu dialog
  Future<void> _showRawTextDialog(String text) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Ham OCR Metni (ML Kit)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Kapat', style: TextStyle(color: cs.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.fromFiles) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanFromFiles());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Belge Tara'),
          Expanded(
            child: Center(
              child:
                  _busy
                      ? const CircularProgressIndicator()
                      : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.document_scanner,
                                  size: 56,
                                  color: cs.primary,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Kaynak Seç',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _scanCamera,
                                        icon: const Icon(Icons.photo_camera),
                                        label: const Text('Kameradan Tara'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _scanFromFiles,
                                        icon: const Icon(Icons.folder_open),
                                        label: const Text(
                                          'Dosyadan Tara (Foto/PDF)',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_lastError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _lastError!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UI’ye yazmadan önce iki parser’ın ortaklaştırılmış çıktısı
class _UiLineItem {
  final String name;
  final double total;
  final double? vatPercent;
  final String formatted;

  _UiLineItem({
    required this.name,
    required this.total,
    required this.vatPercent,
    required this.formatted,
  });
}
