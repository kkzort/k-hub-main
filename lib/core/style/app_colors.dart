import 'dart:ui';
import 'package:flutter/material.dart';

class AppColors {
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(true);
  static bool get isDark => isDarkNotifier.value;

  // ─── Primary (Mavi-Turkuaz) ───
  static Color get primary => isDark
      ? const Color(0xFF29B6F6)
      : const Color(0xFF0277BD);
  static Color get primaryLight => isDark
      ? const Color(0xFF29B6F6).withValues(alpha: 0.15)
      : const Color(0xFF0277BD).withValues(alpha: 0.08);
  static Color get primaryDark => isDark
      ? const Color(0xFF0288D1)
      : const Color(0xFF01579B);

  // ─── Accent (Turkuaz-Cyan) ───
  static Color get accent => const Color(0xFF00E5FF);

  // ─── Surfaces ───
  static Color get background => isDark
      ? const Color(0xFF0A0D10)   // Nötr koyu (hafif mavi)
      : const Color(0xFFF8F9FC);  // Premium soğuk beyaz
  static Color get surface => isDark
      ? const Color(0xFF131820)   // Nötr koyu kart
      : const Color(0xFFFFFFFF);
  static Color get surfaceSecondary => isDark
      ? const Color(0xFF1A2030)   // Nötr orta koyu
      : const Color(0xFFF0F2F7);  // Soğuk açık gri

  // ─── Liquid Glass ───
  static Color get glass => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.75);
  static Color get glassStrong => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.88);
  static Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFD0D5E0).withValues(alpha: 0.40);
  static Color get glassHighlight => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.white.withValues(alpha: 0.95);
  static double get glassBlur => isDark ? 30.0 : 20.0;

  // ─── Text ───
  static Color get textHeader => isDark
      ? const Color(0xFFF0F0F0)
      : const Color(0xFF0F1724);  // Derin koyu mavi — premium kontrast
  static Color get textBody => isDark
      ? const Color(0xFF8A95A3)
      : const Color(0xFF3D4A5C);  // Zengin gri-mavi
  static Color get textTertiary => isDark
      ? const Color(0xFF5A6578)
      : const Color(0xFF6B7A8D);  // Orta gri-mavi

  // ─── Borders & Dividers ───
  static Color get border => isDark
      ? const Color(0xFF1E2430)
      : const Color(0xFFE2E5ED);  // Hassas soğuk gri
  static Color get divider => isDark
      ? const Color(0xFF161B24)
      : const Color(0xFFEEF0F5);  // Çok ince ayırıcı

  // ─── Shadows ───
  static Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.40)
      : const Color(0xFF1A2540).withValues(alpha: 0.06);  // Mavi tint gölge
  static Color get shadowMedium => isDark
      ? Colors.black.withValues(alpha: 0.50)
      : const Color(0xFF1A2540).withValues(alpha: 0.10);

  // ─── Status ───
  static Color get success => const Color(0xFF66BB6A);
  static Color get error => const Color(0xFFEF5350);
  static Color get warning => const Color(0xFFFFB74D);

  // ─── Navigation ───
  static Color get navInactive => isDark
      ? const Color(0xFF5A6578)
      : const Color(0xFF8892A2);

  static void toggleTheme() {
    isDarkNotifier.value = !isDarkNotifier.value;
  }

  // ─── Liquid Glass Widget Helpers ───
  static Widget glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double borderRadius = 16,
    double? blur,
    Color? color,
    double borderWidth = 0.5,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur ?? glassBlur,
            sigmaY: blur ?? glassBlur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? glass,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: glassBorder,
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
