import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  dynamic _scannedDocuments;

  Future<void> scanDocument() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments =
          await FlutterDocScanner().getScannedDocumentAsPdf(page: 4) ??
          'Tanımlanamayan belge';
    } on PlatformException {
      scannedDocuments = 'Belgeyi tararken bir problem çıktı';
    }

    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fatura Uygulaması')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _scannedDocuments != null
                  ? Text(_scannedDocuments.toString())
                  : const Text("Taranan dosya yok"),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ElevatedButton(
          onPressed: () {
            scanDocument();
          },
          child: const Text("PDF/Fotoğraf tara"),
        ),
      ),
    );
  }
}
