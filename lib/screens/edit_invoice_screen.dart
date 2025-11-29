// lib/screens/edit_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/invoice_state.dart';
import '../models/invoice_model.dart';

import '../models/receipt_models.dart';
import '../models/api_result.dart';
import '../services/middleware_service.dart';

class EditInvoiceScreen extends StatefulWidget {
  final ReceiptParseResult receipt; // <<< OCR'den gelen asıl veri

  const EditInvoiceScreen({super.key, required this.receipt});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  final MiddlewareService _middlewareService = MiddlewareService();
  bool _isSending = false;

  Future<void> _onSendToSapPressed() async {
    setState(() {
      _isSending = true;
    });

    final ApiResult result = await _middlewareService.sendReceipt(
      widget.receipt,
    );

    if (!mounted) return;

    setState(() {
      _isSending = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = Provider.of<InvoiceState>(context);
    final inv = s.current;
    final cs = Theme.of(context).colorScheme;

    if (inv == null) {
      return const Scaffold(body: Center(child: Text('Geçerli fatura yok')));
    }

    // Alanları header ve ürün olarak ayır
    final headerFields = <InvoiceField>[];
    final productFields = <InvoiceField>[];

    for (final f in inv.fields) {
      if (_isProductField(f)) {
        productFields.add(f);
      } else {
        headerFields.add(f);
      }
    }

    final createdAtText = _formatDateTime(inv.createdAt);

    final Color headerContainerColor = Colors.green;
    final Color productContainerColor = Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('Fatura Düzenle'), elevation: 0),
      body: Column(
        children: [
          // Oluşturulma bilgisi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oluşturulma',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAtText,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // İçerik scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1️⃣ HEADER ANA CONTAINER
                  if (headerFields.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      decoration: BoxDecoration(
                        color: headerContainerColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Fatura Başlık Bilgileri',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...headerFields.map(
                            (f) => _FieldCard(
                              field: f,
                              chipColor: cs.primary,
                              cardColor: Colors.white,
                              textColor: cs.onSurface.withOpacity(0.9),
                              onEdit:
                                  () => _showEditDialog(
                                    context: context,
                                    initialName: f.name,
                                    initialValue: f.value,
                                    onSaved: (newVal) {
                                      s.updateFieldValue(f.id, newVal);
                                    },
                                  ),
                              onRemove:
                                  () => _confirmDeleteField(
                                    context: context,
                                    onConfirm: () {
                                      s.removeField(f.id);
                                    },
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🔵 BAŞLIK BİLGİSİ EKLE BUTONU
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                top: BorderSide(
                                  color: cs.onSurface.withOpacity(0.12),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _AddFieldButton(
                              label: 'Başlık Bilgisi Ekle',
                              icon: Icons.add,
                              onTap: () {
                                _showAddFieldDialog(
                                  context: context,
                                  onAdd: (name, value) {
                                    final newField = InvoiceField(
                                      name: name,
                                      value: value,
                                    );
                                    s.addField(newField);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 2️⃣ ÜRÜNLER ANA CONTAINER
                  if (productFields.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      decoration: BoxDecoration(
                        color: productContainerColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Ürünler',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...productFields.map(
                            (f) => _FieldCard(
                              field: f,
                              chipColor: cs.secondary,
                              cardColor: cs.surface,
                              textColor: cs.onSurface.withOpacity(0.95),
                              onEdit:
                                  () => _showEditDialog(
                                    context: context,
                                    initialName: f.name,
                                    initialValue: f.value,
                                    onSaved: (newVal) {
                                      s.updateFieldValue(f.id, newVal);
                                    },
                                  ),
                              onRemove:
                                  () => _confirmDeleteField(
                                    context: context,
                                    onConfirm: () {
                                      s.removeField(f.id);
                                    },
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🟢 YENİ ÜRÜN BİLGİSİ EKLE BUTONU
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                top: BorderSide(
                                  color: cs.onSurface.withOpacity(0.12),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _AddFieldButton(
                              label: 'Yeni Ürün Bilgisi Ekle',
                              icon: Icons.add_shopping_cart,
                              onTap: () {
                                _showAddFieldDialog(
                                  context: context,
                                  onAdd: (name, value) {
                                    // Kullanıcı muhtemelen "Ürün" veya benzeri yazar;
                                    // yine de boş bırakırsa ürün sayılması için default verebiliriz.
                                    final effectiveName =
                                        (name.trim().isEmpty)
                                            ? 'Ürün'
                                            : name.trim();

                                    final newField = InvoiceField(
                                      name: effectiveName,
                                      value: value,
                                    );
                                    s.addField(newField);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Alt butonlar (alan ekle / kaydet / SAP'ye gönder)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Çalışmayı Kaydet
                  Expanded(
                    flex: 4,
                    child: ElevatedButton(
                      onPressed:
                          () => _confirmSendToSap(
                            context: context,
                            onConfirm: () async {
                              // TODO: Burada SAP'ye gönderme işlemini bağlayabilirsin.
                              await s.saveCurrent(); // simdilik kaydediyoruz
                            },
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Çalışmayı Kaydet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SAP'ye Gönder
                  Expanded(
                    flex: 4,
                    child: ElevatedButton(
                      onPressed:
                          () => _confirmSendToSap(
                            context: context,
                            onConfirm: () async {
                              // TODO: Burada SAP'ye gönderme işlemini bağlayabilirsin.
                              await s.saveCurrent(); // simdilik kaydediyoruz
                            },
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('SAP\'ye Gönder'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isProductField(InvoiceField f) {
    final name = f.name.toLowerCase();
    // Şimdilik "ürün" kelimesi geçenleri ürün kabul edelim
    return name.contains('ürün') || name.contains('urun');
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }

  Future<void> _showAddFieldDialog({
    required BuildContext context,
    required void Function(String name, String value) onAdd,
  }) async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yeni Alan Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Alan Başlığı',
                  hintText: 'Örn: Vergi No',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: 'Değer',
                  hintText: 'Örn: 1234567890',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // State’e yeni alanı ekle
      onAdd(nameController.text.trim(), valueController.text.trim());

      // Kullanıcıya bilgi ver
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Eklendi'),
              content: Text(
                '"${nameController.text.trim()}" alanı başarıyla eklendi.',
              ),
              actions: [
                TextButton(
                  child: const Text('Tamam'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _showEditDialog({
    required BuildContext context,
    required String initialName,
    required String initialValue,
    required ValueChanged<String> onSaved,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(initialName),
          content: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Değer',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      onSaved(controller.text);
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Güncellendi'),
            content: Text('"$initialName" alanı başarıyla güncellendi.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _confirmDeleteField({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Alan Silinsin mi?'),
          content: const Text('Bu alanı silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      onConfirm();
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Silindi'),
            content: const Text('Alan başarıyla silindi.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _confirmSaveWork({
    required BuildContext context,
    required Future<void> Function() onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Çalışmayı Kaydet'),
          content: const Text(
            'Mevcut düzenlemeleri kaydetmek istiyor musun?\n'
            'Daha sonra SAP\'ye gönderebilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await onConfirm();
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Kaydedildi'),
            content: const Text('Düzenlemeler başarıyla kaydedildi.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _confirmSendToSap({
    required BuildContext context,
    required Future<void> Function() onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('SAP\'ye Gönder'),
          content: const Text(
            'Bu faturayı SAP sistemine göndermek istiyor musun?\n'
            'Göndermeden önce alanları kontrol ettiğinden emin ol.',
          ),
          actions: [
            TextButton(
              onPressed: _isSending ? null : _onSendToSapPressed,
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await onConfirm();
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('İşlem Başlatıldı'),
            content: const Text(
              'Fatura SAP\'ye gönderilmek üzere işleme alındı.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    }
  }
}

/// Başlık chip'i + içerik kartı tek parça gibi görünen widget.
class _FieldCard extends StatelessWidget {
  final InvoiceField field;
  final Color chipColor;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _FieldCard({
    super.key,
    required this.field,
    required this.chipColor,
    required this.cardColor,
    required this.textColor,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // İçerik kartı
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(14, 16, 4, 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // içerik metni
                  Expanded(
                    child: Text(
                      field.value.isEmpty ? '—' : field.value,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                  // ikonlar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: chipColor,
                        ),
                        onPressed: onEdit,
                        tooltip: 'Düzenle',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: onRemove,
                        tooltip: 'Sil',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Başlık chip'i
          Positioned(
            left: 16,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                field.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFieldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddFieldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
