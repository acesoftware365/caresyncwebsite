import 'package:flutter/material.dart';

ThemeData buildPublicTheme() {
  const seed = Color(0xFFFFB3C7);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: seed,
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFFFFBFD),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: const Color(0xFFFFFBFD),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
