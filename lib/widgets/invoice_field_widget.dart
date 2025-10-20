// lib/widgets/invoice_field_widget.dart
import 'package:flutter/material.dart';
import '../models/invoice_model.dart';

/// Her bir fatura alanını gösteren widget.
/// - alan adı düzenlenebilir
/// - alan değeri düzenlenebilir
/// - sürükle-bırak (reorderable list ile çalışacak şekilde key'e ihtiyaç var)
class InvoiceFieldWidget extends StatefulWidget {
  final InvoiceField field;
  final void Function() onRemove;
  final void Function(String) onUpdate;

  const InvoiceFieldWidget({
    super.key,
    required this.field,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<InvoiceFieldWidget> createState() => _InvoiceFieldWidgetState();
}

class _InvoiceFieldWidgetState extends State<InvoiceFieldWidget> {
  late TextEditingController _nameCtl;
  late TextEditingController _valCtl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.field.name);
    _valCtl = TextEditingController(text: widget.field.value);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _valCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: widget.key,
      title:
          _editingName
              ? TextField(
                controller: _nameCtl,
                onSubmitted: (_) {
                  setState(() => _editingName = false);
                  // kullanıcı alan adını manuel değiştirdi -> güncelleme callback yok ama value değişmedi
                },
              )
              : GestureDetector(
                onDoubleTap: () => setState(() => _editingName = true),
                child: Row(
                  children: [
                    Text(
                      widget.field.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.field.validated) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
      subtitle: TextField(
        controller: _valCtl,
        maxLines: null,
        decoration: const InputDecoration(border: InputBorder.none),
        onChanged: (v) {
          widget.onUpdate(v);
        },
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: widget.onRemove,
      ),
    );
  }
}
