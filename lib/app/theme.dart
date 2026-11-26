import 'package:flutter/material.dart';

/// The Noel palette (v1.0.0): a night sky over snow, with Christmas red, green and gold.
class NoelColors {
  // Night sky, top to horizon.
  static const skyTop = Color(0xFF06122A);
  static const skyHigh = Color(0xFF14305A);
  static const skyLow = Color(0xFF2B5A86);
  static const skyHorizon = Color(0xFF4C80A8);

  static const auroraGreen = Color(0xFF3DFFB0);
  static const auroraPurple = Color(0xFF8A7CFF);
  static const sparkle = Color(0xFFFFF3C4);
  static const moon = Color(0xFFFFF4D2);
  static const mountainFar = Color(0xFF1E3E66);
  static const mountainNear = Color(0xFF183457);
  static const ridge = Color(0xFFE6F0F7);
  static const pine = Color(0xFF14324F);
  static const window = Color(0xFFFFC857);

  /// Bright snow: the front hill (top to bottom) and the home screen's button area.
  static const snowLight = Color(0xFFFFFFFF);
  static const snowShade = Color(0xFFD9E8F3);
  static const snow = Color(0xFFF4F8FB);

  /// Behind the parent lock on the snow.
  static const lockBg = Color(0xFFE3ECF3);

  static const red = Color(0xFFE53935);

  /// Candy-cane red: text on white (5.6:1), the traced ink.
  static const deepRed = Color(0xFFC62828);
  static const hatRed = Color(0xFFD32F2F);
  static const green = Color(0xFF2E7D32);
  static const gold = Color(0xFFFFC940);

  // Fairy lights.
  static const lightRed = Color(0xFFFF5252);
  static const lightGreen = Color(0xFF69F0AE);
  static const lightBlue = Color(0xFF40C4FF);

  /// Dark text on white cards (14:1).
  static const ink = Color(0xFF14305A);

  /// Text on the night sky.
  static const onSky = Colors.white;

  /// Soft gold halo for hints and highlights.
  static const glow = Color(0xFFFFE082);

  /// Drop shadow of white cards on the night sky.
  static const shadow = Color(0xFF020814);
}

/// Old ice names, kept only so code from branches started before the Noel theme still
/// compiles; the values are Noel colours. Use [NoelColors] in new code.
class IceColors {
  static const sky = NoelColors.snow;
  static const ice = NoelColors.snowShade;
  static const frost = NoelColors.snowShade;
  static const deep = NoelColors.ink;
  static const glow = NoelColors.glow;
}

/// The parent area keeps the light Material look of earlier versions.
const _parentSeed = Color(0xFF1E5AA8);
const _parentBackground = Color(0xFFE6F6FF);

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _parentSeed),
      scaffoldBackgroundColor: _parentBackground,
      useMaterial3: true,
    );
