// lib/screens/scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ocr_service.dart';
import '../state/invoice_state.dart';
import '../models/invoice_model.dart';
import 'edit_invoice_screen.dart';
import '../theme/app_theme.dart';
import '../services/receipt_parser.dart'; // ReceiptParser2

import '../services/receipt_body_parser.dart' as seq; // satir satir parser

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

      // Ham OCR metnini goster (istersen bu dialogu kapatabilirsin)
      await _showRawTextDialog(text);

      // ---- State hazirligi
      final s = Provider.of<InvoiceState>(context, listen: false);
      final inv = s.current ?? InvoiceModel();
      s.setCurrent(inv);
      inv.fields.clear();

      // 🧠 Tum fisi tek seferde parse et
      final parser = ReceiptParser2();
      final parseResult = parser.parseFull(
        text,
        elements: _ocr.lastElements, // koordinat parser icin
        log: (m) => debugPrint('[PARSE] $m'),
      );

      // ----- InvoiceModel icine header alanlarini yaz
      void addField(String name, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          inv.fields.add(InvoiceField(name: name, value: value.trim()));
        }
      }

      final h = parseResult.header;
      addField('İşletme Adı', h.businessName);
      addField('Adres', h.address);
      addField('Telefon', h.phone);
      addField('Vergi Dairesi', h.taxOffice);
      addField('Vergi No', h.taxNumber);
      if (h.date != null) {
        addField('Tarih', h.date!.toIso8601String().split('T').first);
      }
      addField('Saat', h.time);
      addField('Fiş No', h.receiptNo);

      // ----- InvoiceModel icine ürünleri ve toplamları yaz
      for (final item in parseResult.items) {
        final formatted = seq.formatLineItem(item); // receipt_body_parser.dart
        inv.fields.add(
          InvoiceField(name: 'Ürün', value: formatted, validated: false),
        );
      }

      final totals = parseResult.totals;
      if (totals.topKdv != null) {
        inv.fields.add(
          InvoiceField(
            name: 'TOPKDV',
            value: totals.topKdv!.toStringAsFixed(2),
          ),
        );
      }
      if (totals.total != null) {
        inv.fields.add(
          InvoiceField(name: 'TOPLAM', value: totals.total!.toStringAsFixed(2)),
        );
      }

      debugPrint('[SCAN] saveCurrent start; fields=${inv.fields.length}');
      await s.saveCurrent();
      debugPrint('[SCAN] saveCurrent ok');

      if (!mounted) return;

      // Yeni format: EditInvoiceScreen'e ReceiptParseResult gonderiyoruz
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditInvoiceScreen(receipt: parseResult),
        ),
      );
    } catch (e, st) {
      debugPrint('[SCAN] EX: $e\n$st');
      setState(() {
        _lastError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      debugPrint('[SCAN] done.');
    }
  }

  /// Ham OCR metnini goster
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
                                  'Kaynak Sec',
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
