import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF5B7CFF); // mavi-mor arası ton
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F8FB),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: Colors.black87,
      ),
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

/// Gradient başlık şeridi (her ekranda üstte kullanıyoruz)
class GradientHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  const GradientHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEADING
                if (leading != null) ...[leading!, const SizedBox(width: 12)],

                // TITLE (merkeze denk gelsin diye Expanded)
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // ACTIONS
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ],
            ),
          ),
          // if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
