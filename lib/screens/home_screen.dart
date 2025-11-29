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
import '../widgets/app_drawer.dart';
import '../models/receipt_models.dart'; // ReceiptParseResult icin

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
      // 📌 SOLDAKI DRAWER
      drawer: AppDrawer(
        items: [
          AppDrawerItem(
            title: 'Hesap Oluştur',
            icon: Icons.person_add_alt_1,
            routePage: const AuthScreen(),
          ),
          AppDrawerItem(
            title: 'Tüm Faturalar',
            icon: Icons.receipt_long,
            routePage: const HomeScreen(),
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔹 ÜST BAŞLIK / HEADER
          GradientHeader(
            title: 'Parla Bilgi Teknolojileri',
            leading: Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    tooltip: 'Menü',
                  ),
            ),
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

          const SizedBox(height: 16),

          // 🔹 İÇERİK
          Expanded(
            child:
                s.invoices.isEmpty
                    ? _EmptyHint(cs: cs)
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: s.invoices.length,
                      itemBuilder: (context, i) {
                        final inv = s.invoices[i];
                        return _InvoiceCard(
                          inv: inv,
                          onOpen: () {
                            // Secilen faturayi state’e koy
                            s.setCurrent(inv);

                            // Eski kayitlar icin stub ReceiptParseResult
                            final dummyReceipt = ReceiptParseResult(
                              header: const ReceiptHeader(),
                              items: const [],
                              discounts: const [],
                              totals: const ReceiptTotals(),
                            );

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => EditInvoiceScreen(
                                      receipt: dummyReceipt,
                                    ),
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

      // 🔹 YENİ TARAMA FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final s = Provider.of<InvoiceState>(context, listen: false);
          s.createNewInvoice();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Tarama'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long, size: 40, color: cs.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hiç fatura yok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sağ alttaki “Yeni Tarama” butonuyla\n'
                  'kameradan veya dosyadan fatura ekleyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withOpacity(.7)),
                ),
              ],
            ),
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

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                // Sol ikon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long, color: cs.primary, size: 24),
                ),
                const SizedBox(width: 12),

                // Orta kısım: fatura bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fatura ${inv.id.substring(0, 6)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Oluşturma: ${_formatDate(inv.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sağda sil butonu
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: cs.error.withOpacity(.9),
                  ),
                  onPressed: onDelete,
                  tooltip: 'Sil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
