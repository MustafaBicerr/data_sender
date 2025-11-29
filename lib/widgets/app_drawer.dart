// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';

/// Drawer içindeki her bir menü öğesini temsil eden model.
class AppDrawerItem {
  final String title;
  final IconData icon;
  final Widget routePage;

  const AppDrawerItem({
    required this.title,
    required this.icon,
    required this.routePage,
  });
}

/// Uygulama genelinde kullanabileceğin sade Drawer.
///
/// Örnek kullanım:
/// AppDrawer(
///   items: [
///     AppDrawerItem(
///       title: 'Hesap Oluştur',
///       icon: Icons.person_add,
///       routePage: const AuthScreen(),
///     ),
///   ],
/// )
class AppDrawer extends StatelessWidget {
  final List<AppDrawerItem> items;

  const AppDrawer({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üstte küçük bir firma başlığı
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: const Icon(Icons.apartment, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Parla Bilgi Teknolojileri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Menü',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder:
                    (_, __) => const Divider(height: 1, thickness: 0.3),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Icon(item.icon, color: cs.primary),
                    title: Text(item.title),
                    onTap: () {
                      Navigator.of(context).pop(); // drawer’ı kapat
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => item.routePage));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
