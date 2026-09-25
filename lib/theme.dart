// PCV · 主题系统（设计令牌）
// 深色 = Tokyo Night 基底 · 亮色 = Catppuccin Latte 基底
// 语义八色 + 强调色五选一 · 语法配色独立成套
import 'package:flutter/material.dart';

class Pal {
  final Brightness brightness;
  final Color root, surface, elev, hover, border, border2;
  final Color t1, t2, t3, t4;
  final Color blue, cyan, purple, green, yellow, orange, red, teal;

  const Pal({
    required this.brightness,
    required this.root,
    required this.surface,
    required this.elev,
    required this.hover,
    required this.border,
    required this.border2,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.t4,
    required this.blue,
    required this.cyan,
    required this.purple,
    required this.green,
    required this.yellow,
    required this.orange,
    required this.red,
    required this.teal,
  });

  bool get dark => brightness == Brightness.dark;
}

const darkPal = Pal(
  brightness: Brightness.dark,
  root: Color(0xFF1B1E2D),
  surface: Color(0xFF1F2335),
  elev: Color(0xFF24283B),
  hover: Color(0xFF292E42),
  border: Color(0xFF2C3149),
  border2: Color(0xFF363C58),
  t1: Color(0xFFC0CAF5),
  t2: Color(0xFF9AA2C7),
  t3: Color(0xFF565F89),
  t4: Color(0xFF414868),
  blue: Color(0xFF7AA2F7),
  cyan: Color(0xFF7DCFFF),
  purple: Color(0xFFBB9AF7),
  green: Color(0xFF9ECE6A),
  yellow: Color(0xFFE0AF68),
  orange: Color(0xFFFF9E64),
  red: Color(0xFFF7768E),
  teal: Color(0xFF73DACA),
);

const lightPal = Pal(
  brightness: Brightness.light,
  root: Color(0xFFE6E9EF),
  surface: Color(0xFFEFF1F5),
  elev: Color(0xFFFFFFFF),
  hover: Color(0xFFE2E5EC),
  border: Color(0xFFD5D9E2),
  border2: Color(0xFFC6CBD7),
  t1: Color(0xFF4C4F69),
  t2: Color(0xFF5C5F77),
  t3: Color(0xFF6C6F85),
  t4: Color(0xFF8C8FA1),
  blue: Color(0xFF1E66F5),
  cyan: Color(0xFF0D7A8C),
  purple: Color(0xFF8839EF),
  green: Color(0xFF3D9A29),
  yellow: Color(0xFFB07514),
  orange: Color(0xFFE05A00),
  red: Color(0xFFD20F39),
  teal: Color(0xFF117E84),
);

Pal palOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkPal : lightPal;

// ============ 强调色预设（五选一——色彩范围） ============

class AccentPreset {
  final String id;
  final String name;
  final Color dark;
  final Color light;
  const AccentPreset(this.id, this.name, this.dark, this.light);
}

const accentPresets = <AccentPreset>[
  AccentPreset('blue', '烟蓝', Color(0xFF7AA2F7), Color(0xFF1E66F5)),
  AccentPreset('cyan', '晴青', Color(0xFF7DCFFF), Color(0xFF0D7A8C)),
  AccentPreset('purple', '浅紫', Color(0xFFBB9AF7), Color(0xFF8839EF)),
  AccentPreset('green', '苔绿', Color(0xFF9ECE6A), Color(0xFF3D9A29)),
  AccentPreset('orange', '暖橙', Color(0xFFFF9E64), Color(0xFFE05A00)),
];

AccentPreset accentOf(String id) => accentPresets.firstWhere(
      (a) => a.id == id,
      orElse: () => accentPresets.first,
    );

// ============ 语法配色 ============

class SynPal {
  final Color keyword, func, string, comment, number, type, text, punct;
  const SynPal({
    required this.keyword,
    required this.func,
    required this.string,
    required this.comment,
    required this.number,
    required this.type,
    required this.text,
    required this.punct,
  });
}

SynPal synOf(Pal p) => p.dark
    ? const SynPal(
        keyword: Color(0xFFBB9AF7),
        func: Color(0xFF7AA2F7),
        string: Color(0xFF9ECE6A),
        comment: Color(0xFF565F89),
        number: Color(0xFFFF9E64),
        type: Color(0xFF2AC3DE),
        text: Color(0xFFC0CAF5),
        punct: Color(0xFF89DDFF),
      )
    : const SynPal(
        keyword: Color(0xFF8839EF),
        func: Color(0xFF1E66F5),
        string: Color(0xFF3D9A29),
        comment: Color(0xFF8C8FA1),
        number: Color(0xFFE05A00),
        type: Color(0xFF0D7A8C),
        text: Color(0xFF4C4F69),
        punct: Color(0xFF179299),
      );

// ============ 主题构建 ============

ThemeData buildPcvTheme({required bool dark, required AccentPreset accent}) {
  final p = dark ? darkPal : lightPal;
  final a = dark ? accent.dark : accent.light;
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: a,
    onPrimary: dark ? const Color(0xFF151A2E) : Colors.white,
    secondary: p.cyan,
    onSecondary: dark ? const Color(0xFF151A2E) : Colors.white,
    error: p.red,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.t1,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.root,
    dividerColor: p.border,
    splashColor: a.withValues(alpha: .08),
    highlightColor: a.withValues(alpha: .05),
    appBarTheme: AppBarTheme(
      backgroundColor: p.root,
      foregroundColor: p.t1,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: p.t1,
        letterSpacing: .2,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.elev,
      contentTextStyle: TextStyle(color: p.t1, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ============ 常用文本样式 ============

const kMonoFallback = ['monospace'];

TextStyle monoStyle({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.6,
}) =>
    TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: kMonoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
