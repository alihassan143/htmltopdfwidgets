/// Utility class for converting DOCX units to Flutter logical pixels.
///
/// DOCX uses several internal unit systems:
/// - **Twips**: Twentieth of a point (1/1440 inch)
/// - **Half-points**: Used for font sizes (sz attribute)
/// - **EMU**: English Metric Units for images (914400 EMU = 1 inch)
class DocxUnits {
  DocxUnits._();

  /// Converts twips to logical pixels.
  ///
  /// Twips are 1/20th of a point. At 96 DPI:
  /// - 1 point = 96/72 pixels = 1.333 pixels
  /// - 1 twip = 1/20 point = 1.333/20 pixels = 0.0667 pixels
  ///
  /// Simplified: twips / 20 gives approximate pixel value.
  static double twipsToPixels(int twips) => twips / 20.0;

  /// Converts twips to pixels (nullable version).
  static double? twipsToPixelsOrNull(int? twips) =>
      twips != null ? twips / 20.0 : null;

  /// Converts half-points to logical pixels.
  ///
  /// Font sizes in DOCX are specified in half-points (sz attribute).
  /// For example, sz="24" means 12pt font.
  static double halfPointsToPixels(int halfPoints) => halfPoints / 2.0;

  /// Converts half-points to pixels (nullable version).
  static double? halfPointsToPixelsOrNull(int? halfPoints) =>
      halfPoints != null ? halfPoints / 2.0 : null;

  /// Converts EMU (English Metric Units) to logical pixels.
  ///
  /// EMU is used for image dimensions in DrawingML.
  /// 914400 EMU = 1 inch, and at 96 DPI: 1 inch = 96 pixels.
  /// So: 1 pixel = 914400 / 96 = 9525 EMU
  static double emuToPixels(int emu) => emu / 9525.0;

  /// Converts EMU to pixels (nullable version).
  static double? emuToPixelsOrNull(int? emu) =>
      emu != null ? emu / 9525.0 : null;

  /// Converts points to logical pixels.
  ///
  /// At 96 DPI: 1 point = 96/72 pixels ≈ 1.333 pixels.
  static double pointsToPixels(double points) => points * 1.333;

  /// Converts eighths of a point to pixels (used for border widths).
  ///
  /// Border widths use sz attribute in eighths of a point.
  /// For example, sz="4" means 0.5pt border.
  static double eighthsPointToPixels(int eighths) => (eighths / 8.0) * 1.333;

  /// Converts percentage width (used in tables) to fraction.
  ///
  /// DOCX table widths with type="pct" use 50ths of a percent.
  /// For example, w="5000" means 100% (5000/50 = 100).
  static double pctToFraction(int pct) => pct / 5000.0;
}
