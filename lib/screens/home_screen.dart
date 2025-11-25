// lib/screens/home_screen.dart
import 'package:data_sender/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/invoice_state.dart';
import 'scan_screen.dart';
import 'edit_invoice_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/invoice_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    Provider.of<InvoiceState>(context, listen: false).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = Provider.of<InvoiceState>(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Faturalarım',
            actions: [
              IconButton(
                onPressed: () async {
                  await _auth.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Çıkış',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Expanded(
                //   child: ElevatedButton.icon(
                //     icon: const Icon(Icons.photo_camera),
                //     label: const Text('Kameradan Tara'),
                //     onPressed: () {
                //       s.createNewInvoice();
                //       Navigator.of(context).push(
                //         MaterialPageRoute(
                //           builder: (_) => const ScanScreen(fromFiles: false),
                //         ),
                //       );
                //     },
                //   ),
                // ),
                // const SizedBox(width: 12),
                // Expanded(
                //   child: ElevatedButton.icon(
                //     icon: const Icon(Icons.folder_open),
                //     label: const Text('Dosyadan Tara'),
                //     onPressed: () {
                //       s.createNewInvoice();
                //       Navigator.of(context).push(
                //         MaterialPageRoute(
                //           builder: (_) => const ScanScreen(fromFiles: true),
                //         ),
                //       );
                //     },
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                s.invoices.isEmpty
                    ? _EmptyHint(cs: cs)
                    : ListView.builder(
                      itemCount: s.invoices.length,
                      itemBuilder: (context, i) {
                        final inv = s.invoices[i];
                        return _InvoiceCard(
                          inv: inv,
                          onOpen: () {
                            s.setCurrent(inv);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditInvoiceScreen(),
                              ),
                            );
                          },
                          onDelete: () async {
                            await s.deleteInvoice(inv.id);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final s = Provider.of<InvoiceState>(context, listen: false);
          s.createNewInvoice();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
        },
        label: const Text('Yeni Tarama'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.cs});
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 42, color: cs.primary),
              const SizedBox(height: 8),
              const Text(
                'Hiç fatura yok',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('Kameradan veya dosyadan tarayıp ekleyebilirsin.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel inv;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _InvoiceCard({
    required this.inv,
    required this.onOpen,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primary.withOpacity(.1),
          child: Icon(Icons.receipt, color: cs.primary),
        ),
        title: Text('Fatura ${inv.id.substring(0, 6)}'),
        subtitle: Text('Oluşturma: ${inv.createdAt.toLocal()}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        onTap: onOpen,
      ),
    );
  }
}
