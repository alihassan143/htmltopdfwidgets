/// Measurement utilities for DOCX/OOXML values.
///
/// OOXML uses several measurement units:
/// - **EMU (English Metric Units)**: 914400 per inch, used in DrawingML
/// - **Twips**: 1440 per inch (1/20th of a point), used in WordprocessingML
/// - **Half-points**: 1/144th of an inch, used for font sizes
///
/// To maintain precision during round-trips, all measurements should be
/// stored as integers in their native unit (EMU or Twips), then converted
/// to display units (points, inches) only when needed.
library;

// =============================================================================
// EMU (English Metric Units) - Used in DrawingML (wp:extent, positions)
// =============================================================================

/// EMU to other unit conversions
extension EmuToOther on int {
  /// Converts EMUs to points (1 pt = 12700 EMU)
  double get emuToPoints => this / 12700.0;

  /// Converts EMUs to inches (1 inch = 914400 EMU)
  double get emuToInches => this / 914400.0;

  /// Converts EMUs to centimeters
  double get emuToCm => this / 360000.0;

  /// Converts EMUs to millimeters
  double get emuToMm => this / 36000.0;

  /// Converts EMUs to pixels at 96 DPI
  double get emuToPixels96 => this / 9525.0;
}

/// Points to EMU conversion
extension PointsToEmu on double {
  /// Converts points to EMUs (1 pt = 12700 EMU)
  int get pointsToEmu => (this * 12700).round();
}

/// Inches to EMU conversion
extension InchesToEmu on double {
  /// Converts inches to EMUs (1 inch = 914400 EMU)
  int get inchesToEmu => (this * 914400).round();
}

// =============================================================================
// Twips - Used in WordprocessingML (w:spacing, w:ind, w:pgMar)
// =============================================================================

/// Twips to other unit conversions
extension TwipsToOther on int {
  /// Converts twips to points (1 pt = 20 twips)
  double get twipsToPoints => this / 20.0;

  /// Converts twips to inches (1 inch = 1440 twips)
  double get twipsToInches => this / 1440.0;

  /// Converts twips to centimeters
  double get twipsToCm => this / 566.929;

  /// Converts twips to millimeters
  double get twipsToMm => this / 56.6929;
}

/// Points to Twips conversion
extension PointsToTwips on double {
  /// Converts points to twips (1 pt = 20 twips)
  int get pointsToTwips => (this * 20).round();
}

/// Inches to Twips conversion
extension InchesToTwips on double {
  /// Converts inches to twips (1 inch = 1440 twips)
  int get inchesToTwips => (this * 1440).round();
}

// =============================================================================
// Half-Points - Used for font sizes (w:sz)
// =============================================================================

/// Half-points to other unit conversions
extension HalfPointsToOther on int {
  /// Converts half-points to points
  double get halfPointsToPoints => this / 2.0;
}

/// Points to half-points conversion
extension PointsToHalfPoints on double {
  /// Converts points to half-points
  int get pointsToHalfPoints => (this * 2).round();
}

// =============================================================================
// Eighths of a Point - Used for border widths (w:sz in borders)
// =============================================================================

/// Eighths of a point to other unit conversions
extension EighthPointsToOther on int {
  /// Converts eighths of a point to points
  double get eighthPointsToPoints => this / 8.0;
}

/// Points to eighths of a point conversion
extension PointsToEighthPoints on double {
  /// Converts points to eighths of a point
  int get pointsToEighthPoints => (this * 8).round();
}

// =============================================================================
// Percentage Values - Used in table widths (w:tblW with type="pct")
// =============================================================================

/// Percentage (in fiftieths of a percent) conversions
extension FiftiethsPercentToOther on int {
  /// Converts fiftieths of a percent to actual percentage (0-100)
  double get fiftiethsToPercent => this / 50.0;
}

/// Percentage to fiftieths conversion
extension PercentToFiftieths on double {
  /// Converts percentage (0-100) to fiftieths of a percent
  int get percentToFiftieths => (this * 50).round();
}

// =============================================================================
// Common DOCX Measurement Constants
// =============================================================================

/// Common measurement constants for DOCX documents.
class DocxMeasurements {
  DocxMeasurements._();

  // Standard page sizes in twips
  static const int letterWidthTwips = 12240; // 8.5 inches
  static const int letterHeightTwips = 15840; // 11 inches
  static const int a4WidthTwips = 11906; // 210mm
  static const int a4HeightTwips = 16838; // 297mm

  // Standard margins in twips
  static const int defaultMarginTwips = 1440; // 1 inch
  static const int narrowMarginTwips = 720; // 0.5 inch

  // EMU constants
  static const int emuPerInch = 914400;
  static const int emuPerPoint = 12700;
  static const int emuPerCm = 360000;

  // Twips constants
  static const int twipsPerInch = 1440;
  static const int twipsPerPoint = 20;
}
