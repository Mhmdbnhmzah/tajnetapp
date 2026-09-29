import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── TajNet Core Palette (Light Theme) ───────────────────
  static const Color primaryColor   = Color(0xFF0088FF);   // أزرق سماوي حيوى
  static const Color primaryLight   = Color(0xFFE0F2FE);   // أزرق سماوي خفيف
  static const Color primaryDark    = Color(0xFF0055FF);   // أزرق ملكي

  static const Color accentGold     = Color(0xFFD97706);   // ذهبي دافئ واضح
  static const Color accentCyan     = Color(0xFF059669);   // أخضر زمردي
  static const Color accentPurple   = Color(0xFF7C3AED);   // بنفسجي مريح

  // ─── Light Backgrounds & Surfaces ───────────────────────
  static const Color backgroundColor        = Color(0xFFF4F7FC); // خلفية فاتحة مريحة للعين
  static const Color surfaceColor           = Color(0xFFFFFFFF); // سطح البطاقات (أبيض ناصع)
  static const Color surfaceColorElevated   = Color(0xFFF8FAFC); // سطح مرتفع (رمادي ناعم)
  static const Color borderColor            = Color(0xFFE2E8F0); // حد فاتح أنيق

  // ─── Backward Compatibility Aliases ─────────────────────
  static const Color secondaryBackgroundColor = surfaceColor;
  static const Color cardBorderColor          = borderColor;

  // ─── Text ───────────────────────────────────────────────
  static const Color textColor     = Color(0xFF0F172A); // كحلي غامق واضح جداً للقرائية
  static const Color subtitleColor = Color(0xFF64748B); // رمادي ناعم للنصوص الثانوية
  static const Color errorColor    = Color(0xFFEF4444); // أحمر مشرق
  static const Color successColor  = Color(0xFF10B981); // أخضر ناجح
  static const Color warningColor  = Color(0xFFF59E0B); // برتقالي تحذيري

  // ─── Gradients ──────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0055FF), Color(0xFF00A3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF00A3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Generates a unique, deterministic gradient based on package profile name or price.
  static LinearGradient getCategoryGradient(String profilePrice) {
    final clean = profilePrice.trim().toLowerCase();
    if (clean.isEmpty) return primaryGradient;

    final hash = clean.hashCode.abs();

    const categoryGradients = [
      LinearGradient(
        colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF7B2FF7), Color(0xFF00C6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF00F5A0), Color(0xFF0072FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFFFB300), Color(0xFFFF8C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];

    return categoryGradients[hash % categoryGradients.length];
  }

  // ─── Shadows & Elevation ────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: const Color(0xFF0088FF).withValues(alpha: 0.2),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get purpleGlow => [
    BoxShadow(
      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0088FF).withValues(alpha: 0.03),
      blurRadius: 30,
      offset: const Offset(0, 2),
    ),
  ];

  // ─── Card Decoration ────────────────────────────────────
  static BoxDecoration get glassCard => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderColor, width: 1),
    boxShadow: cardShadow,
  );

  static BoxDecoration glassCardWithRadius(double radius) => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: 1),
    boxShadow: cardShadow,
  );

  // ─── Light Theme Data ───────────────────────────────────
  static ThemeData get darkTheme { // Preserving getter name for compatibility
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentGold,
        surface: surfaceColor,
        error: errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textColor),
        titleTextStyle: GoogleFonts.tajawal(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: GoogleFonts.tajawalTextTheme(const TextTheme(
        displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: subtitleColor),
        labelLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      )),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) return const Color(0xFFE2E8F0);
            return primaryColor;
          }),
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Tajawal'),
        labelStyle: const TextStyle(color: subtitleColor, fontFamily: 'Tajawal'),
        prefixIconColor: subtitleColor,
        suffixIconColor: subtitleColor,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF94A3B8),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Tajawal'),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontFamily: 'Tajawal'),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        titleTextStyle: const TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }
}

// ─── TajNet Background Widget (Light Theme) ──────────────────────────────────
class TajNetBackground extends StatelessWidget {
  final Widget child;
  const TajNetBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Stack(
        children: [
          // Top-right soft cyan orb
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00A3FF).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-left soft purple orb
          Positioned(
            bottom: -60,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── TajNet Gradient Button ──────────────────────────────────────────────────
class TajNetButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final List<Color>? gradientColors;
  final double height;
  final double borderRadius;
  final bool fullWidth;

  const TajNetButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.gradientColors,
    this.height = 50,
    this.borderRadius = 14,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [const Color(0xFF0055FF), const Color(0xFF00A3FF)];
    final isDisabled = onPressed == null || isLoading;
    final btn = GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? [const Color(0xFFCBD5E1), const Color(0xFFCBD5E1)]
                : colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isDisabled ? [] : [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : child,
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

// ─── TajNet Card ─────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.gradient,
    this.onTap,
    this.radius = 18,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? AppTheme.surfaceColor) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? AppTheme.borderColor,
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      ),
    );
  }
}

// ─── TajNet AppBar (Light Mode) ──────────────────────────────────────────────
class TajNetAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;
  final Widget? leading;

  const TajNetAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = false,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: leading,
        title: showLogo
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/img/logo.jpeg', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                ],
              )
            : ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
        actions: actions,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
      ),
    );
  }
}

// ─── TajNet Divider ──────────────────────────────────────────────────────────
class NeonDivider extends StatelessWidget {
  final Color? color;
  const NeonDivider({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        color: color ?? AppTheme.borderColor,
      ),
    );
  }
}

// ─── Shared UI Components ────────────────────────────────────────────────────
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

/// 🎨 نظام ألوان وتدرجات حيوية وديناميكية مميزة لكل فئة باقة كروت
class PackageColorHelper {
  static final List<PackagePalette> palettes = [
    // 0. أزرق سماوي نيون (Cyan / Electric Blue)
    const PackagePalette(
      gradientColors: [Color(0xFF0055FF), Color(0xFF00A3FF)],
      accentColor: Color(0xFF0088FF),
    ),
    // 1. بنفسجي ملكي (Royal Purple / Violet)
    const PackagePalette(
      gradientColors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
      accentColor: Color(0xFF7C3AED),
    ),
    // 2. أخضر زمردي نيون (Emerald Green / Teal)
    const PackagePalette(
      gradientColors: [Color(0xFF059669), Color(0xFF10B981)],
      accentColor: Color(0xFF059669),
    ),
    // 3. برتقالي وذهبي مشرق (Amber Gold / Orange)
    const PackagePalette(
      gradientColors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
      accentColor: Color(0xFFD97706),
    ),
    // 4. وردي وقرمزي زاهي (Neon Pink / Magenta)
    const PackagePalette(
      gradientColors: [Color(0xFFDB2777), Color(0xFFEC4899)],
      accentColor: Color(0xFFDB2777),
    ),
    // 5. تيفاني وسماوي نيون (Mint Tiffany)
    const PackagePalette(
      gradientColors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
      accentColor: Color(0xFF0284C7),
    ),
    // 6. أحمر مرجاني وياقوتي (Crimson Coral)
    const PackagePalette(
      gradientColors: [Color(0xFFDC2626), Color(0xFFEF4444)],
      accentColor: Color(0xFFDC2626),
    ),
    // 7. نيلي داكن وبنفسجي ليلكي (Indigo Violet)
    const PackagePalette(
      gradientColors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
      accentColor: Color(0xFF4F46E5),
    ),
    // 8. أزرق ياوقوتي عميق (Sapphire Blue)
    const PackagePalette(
      gradientColors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
      accentColor: Color(0xFF2563EB),
    ),
    // 9. أخضر ليموني نيون (Lime Cyber)
    const PackagePalette(
      gradientColors: [Color(0xFF65A30D), Color(0xFF84CC16)],
      accentColor: Color(0xFF65A30D),
    ),
    // 10. نحاسي وذهبي دافئ (Bronze Copper)
    const PackagePalette(
      gradientColors: [Color(0xFFB45309), Color(0xFFD97706)],
      accentColor: Color(0xFFB45309),
    ),
    // 11. ياقوتي مرجاني مشرق (Ruby Rose)
    const PackagePalette(
      gradientColors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
      accentColor: Color(0xFFE11D48),
    ),
    // 12. بنفسجي ارجواني (Deep Orchid)
    const PackagePalette(
      gradientColors: [Color(0xFF9333EA), Color(0xFFC084FC)],
      accentColor: Color(0xFF9333EA),
    ),
    // 13. أخضر تركوازي (Ocean Teal)
    const PackagePalette(
      gradientColors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
      accentColor: Color(0xFF0D9488),
    ),
    // 14. برتقالي حار وناري (Fiery Orange)
    const PackagePalette(
      gradientColors: [Color(0xFFC2410C), Color(0xFFF97316)],
      accentColor: Color(0xFFC2410C),
    ),
    // 15. بنفسجي ليلكي داكن (Midnight Violet)
    const PackagePalette(
      gradientColors: [Color(0xFF6B21A8), Color(0xFFA855F7)],
      accentColor: Color(0xFF6B21A8),
    ),
  ];

  /// Parsing custom HEX color string safely (e.g., "#FF5733" or "0xFF5733" or "FF5733")
  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    try {
      String cleanHex = hexString.trim().replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (e) {
      debugPrint('Invalid hex color format: $hexString');
    }
    return null;
  }

  /// الحصول على اللوحة واللون الخاص بكل فئة كروت بشكل متميز وثابت (تدعم كود HEX مخصص أو التوليد التلقائي)
  static PackagePalette getPalette(String profilePrice, {String? customHex, int index = 0}) {
    // 0. استخدام كود HEX المخصص إذا تم إدخاله من الإدارة
    final customColor = parseHexColor(customHex);
    if (customColor != null) {
      final HSLColor hsl = HSLColor.fromColor(customColor);
      final Color lighterColor = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
      return PackagePalette(
        gradientColors: [customColor, lighterColor],
        accentColor: customColor,
      );
    }

    final clean = profilePrice.trim();
    if (clean.isEmpty) {
      return palettes[index % palettes.length];
    }

    // 1. استخراج القيمة الرقمية من اسم الفئة (مثلاً: 200 أو 500)
    final numMatch = RegExp(r'\d+').firstMatch(clean);
    if (numMatch != null) {
      final number = int.tryParse(numMatch.group(0)!) ?? 0;
      if (number > 0) {
        // توزيع ذكي يضمن تلوين كل رقم (200، 500، 1000...) بلون مختلف وفريد
        final mappedIndex = ((number * 17) + (number ~/ 50)) % palettes.length;
        return palettes[mappedIndex];
      }
    }

    // 2. حساب Hash من الأحرف إذا لم تحتوي الفئة على أرقام
    final int hash = clean.codeUnits.fold(0, (prev, elem) => prev + elem * 31).abs();
    return palettes[hash % palettes.length];
  }
}

class PackagePalette {
  final List<Color> gradientColors;
  final Color accentColor;

  const PackagePalette({
    required this.gradientColors,
    required this.accentColor,
  });

  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
