import 'package:flutter/material.dart';

ThemeData buildPublicTheme({
  required Color seed,
  required Color scaffold,
}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: seed,
  );

  return base.copyWith(
    scaffoldBackgroundColor: scaffold,
    cardTheme: CardThemeData(
      color: Colors.white.withAlpha(230),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: seed.withAlpha(110)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: seed.withAlpha(190), width: 1.3),
      ),
      isDense: true,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scaffold,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
