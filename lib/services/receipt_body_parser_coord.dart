// lib/services/receipt_body_parser_coord.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'ocr_service.dart'; // OcrElement icin
import '../models/receipt_models.dart' as rm;

/// Gorunur format (UI icin tek satir string)
String formatLineItem(rm.LineItem it) {
  final parts = <String>[];
  parts.add(it.name);
  if (it.vatPercent != null) {
    parts.add('%${it.vatPercent}');
  }
  parts.add('= ${it.totalPrice.toStringAsFixed(2)}');
  return parts.join('  ');
}

// —————— Yardimci regexler ——————
final _moneyRe = RegExp(r'(?<!\d)(\d{1,3}(?:\.\d{3})*,\d{2})(?!\d)');
final _vatRe = RegExp(r'%\s*([0-9]{1,2})');
final _starRe = RegExp(r'^[\*\u204E\u2715\u2731\u22C6\u00D7\u2219]$');

double? _parseMoneyTR(String s) {
  final m = _moneyRe.firstMatch(s);
  if (m == null) return null;
  var t = m.group(1)!;
  t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

int? _parseVat(String s) {
  final m = _vatRe.firstMatch(s);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

bool _isMoney(String s) => _moneyRe.hasMatch(s);
bool _isVat(String s) => _vatRe.hasMatch(s);

double _median(Iterable<double> xs) {
  final a = xs.toList()..sort();
  if (a.isEmpty) return 0;
  final mid = a.length ~/ 2;
  return a.length.isOdd ? a[mid] : (a[mid - 1] + a[mid]) / 2.0;
}

/// Y koordinatina gore satira gruplama
List<List<OcrElement>> _clusterRows(
  List<OcrElement> all, {
  void Function(String m)? log,
}) {
  if (all.isEmpty) return [];
  all.sort((a, b) => a.centerY.compareTo(b.centerY));
  final heights = all.map((e) => e.height).toList()..sort();
  final lineH = heights[heights.length ~/ 2]; // median
  final tol = max(2.0, lineH * 0.65); // tolerans
  final rows = <List<OcrElement>>[];

  var current = <OcrElement>[all.first];
  for (int i = 1; i < all.length; i++) {
    final prev = current.last;
    final e = all[i];
    if ((e.centerY - prev.centerY).abs() <= tol) {
      current.add(e);
    } else {
      rows.add(current);
      current = [e];
    }
  }
  rows.add(current);

  // Satirlari soldan saga sirala
  for (final r in rows) {
    r.sort((a, b) => a.box.left.compareTo(b.box.left));
  }
  log?.call(
    '[COORD] rows=${rows.length}, tol=${tol.toStringAsFixed(1)}, lineH=${lineH.toStringAsFixed(1)}',
  );
  return rows;
}

/// Sag (fiyat) ve orta (KDV) kolon x-merkezleri
({double rightX, double? midX}) _estimateBands(List<List<OcrElement>> rows) {
  final priceXs = <double>[];
  final vatXs = <double>[];
  for (final r in rows) {
    for (final e in r) {
      if (_isMoney(e.text)) priceXs.add(e.centerX);
      if (_isVat(e.text)) vatXs.add(e.centerX);
    }
  }
  final rightX = _median(priceXs);
  final midX = vatXs.isEmpty ? null : _median(vatXs);
  return (rightX: rightX, midX: midX);
}

bool _near(double v, double center, double band) => (v - center).abs() <= band;

/// Koordinat tabanli satir parsesi.
/// Baslangici otomatik bulur, bitiste TOPLAM / TOPKDV / KDV Orani ile durur.
List<rm.LineItem> parseByGeometry({
  required List<OcrElement> elements,
  void Function(String m)? log,
}) {
  final items = <rm.LineItem>[];
  if (elements.isEmpty) return items;

  final rows = _clusterRows(elements, log: log);
  if (rows.isEmpty) return items;

  final bands = _estimateBands(rows);
  final bandTol = (elements.map((e) => e.box.width).toList()..sort());
  final tolX =
      (bandTol.isEmpty ? 20.0 : max(20.0, bandTol[(bandTol.length ~/ 2)] * .9));

  bool started = false;

  for (int i = 0; i < rows.length; i++) {
    final r = rows[i];
    final rText = r.map((e) => e.text).join(' ');

    // Bitis kontrolu
    if (RegExp(
      r'\b(TOPLAM|TOPKDV|KDV\s*Orani)\b',
      caseSensitive: false,
    ).hasMatch(rText)) {
      if (started) break;
    }

    // Sag bandaki para: en sagdaki para
    final rightC = bands.rightX;
    final priceCandidates = r.where((e) => _isMoney(e.text)).toList();
    OcrElement? priceEl;
    if (priceCandidates.isNotEmpty) {
      priceCandidates.sort((a, b) => a.centerX.compareTo(b.centerX));
      priceEl = priceCandidates.last;
      // Yeterince sagda mi? Gerekirse tolX ile kontrol edebilirsin.
      if (!_near(priceEl.centerX, rightC, tolX)) {
        // farkli duzenlerde sag band kayabilir; yine de kullan
      }
    }

    // Orta band (KDV)
    OcrElement? vatEl;
    if (bands.midX != null) {
      final midC = bands.midX!;
      final mids =
          r.where((e) => _isVat(e.text)).toList()..sort(
            (a, b) =>
                (a.centerX - midC).abs().compareTo((b.centerX - midC).abs()),
          );
      if (mids.isNotEmpty) vatEl = mids.first;
    } else {
      final mids = r.where((e) => _isVat(e.text)).toList();
      if (mids.isNotEmpty) vatEl = mids.first;
    }

    // Name: kalanlar (tek karakter star vs. haric)
    final nameEls = <OcrElement>[];
    for (final e in r) {
      if (identical(e, priceEl) || identical(e, vatEl)) continue;
      if (_isMoney(e.text)) continue;
      if (_starRe.hasMatch(e.text)) continue;
      nameEls.add(e);
    }
    final name = nameEls.map((e) => e.text).join(' ').trim();

    final price = priceEl == null ? null : _parseMoneyTR(priceEl.text);
    final vat = vatEl == null ? null : _parseVat(vatEl.text);

    final isValidRow = name.isNotEmpty && price != null;
    if (!started && isValidRow) {
      started = true;
    }
    if (started && isValidRow) {
      items.add(rm.LineItem(name: name, totalPrice: price!, vatPercent: vat));
      log?.call(
        '[COORD] + item: name="$name"  vat=$vat  total=${price!.toStringAsFixed(2)}',
      );
    }
  }

  return items;
}
