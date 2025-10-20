// lib/screens/edit_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/invoice_state.dart';
import '../widgets/invoice_field_widget.dart';
import '../models/invoice_model.dart';

class EditInvoiceScreen extends StatefulWidget {
  const EditInvoiceScreen({super.key});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  @override
  Widget build(BuildContext context) {
    final s = Provider.of<InvoiceState>(context);
    final inv = s.current;
    if (inv == null)
      return Scaffold(body: Center(child: Text('Geçerli fatura yok')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatura Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await s.saveCurrent();
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Oluşturulma: ${inv.createdAt.toLocal()}'),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: inv.fields.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                s.reorderFields(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final f = inv.fields[index];
                return InvoiceFieldWidget(
                  key: ValueKey(f.id),
                  field: f,
                  onRemove: () {
                    s.removeField(f.id);
                  },
                  onUpdate: (newVal) {
                    s.updateFieldValue(f.id, newVal);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // elle alan ekleme
                    final newF = InvoiceField(name: 'Yeni Alan', value: '');
                    s.addField(newF);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Alan Ekle'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await s.saveCurrent();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Tamam'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
