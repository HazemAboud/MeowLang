import 'package:flutter/material.dart';

const TextTheme _appTextTheme = TextTheme(
  displayLarge: TextStyle(color: Colors.black87, fontSize: 34, fontWeight: FontWeight.bold),
  headlineMedium: TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w600),
  titleLarge: TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w600),
  titleMedium: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(color: Colors.black54, fontSize: 16),
  bodyLarge: TextStyle(color: Colors.black87, fontSize: 18),
  bodyMedium: TextStyle(color: Colors.black87, fontSize: 16),
  bodySmall: TextStyle(color: Colors.black54, fontSize: 14),
  labelLarge: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(color: Colors.black54, fontSize: 12),
);

ThemeData _createTheme(Color seed) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
    ),
    textTheme: _appTextTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        shadowColor: seed.withOpacity(0.5),
      ),
    ),
  );
}

final ThemeData orangeTheme = _createTheme(Colors.deepOrange);

class ThemeProvider extends ValueNotifier<ThemeData> {
  ThemeProvider() : super(orangeTheme);  

  void setOrange() => value = orangeTheme;

  void setColor(Color color) {
    value = _createTheme(color);
    notifyListeners();
  }

}
