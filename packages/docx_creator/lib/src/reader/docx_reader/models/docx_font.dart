import 'package:equatable/equatable.dart';

/// Represents the w:rFonts element properties.
///
/// Ensures fidelity by preserving distinct font families for different script types.
class DocxFont extends Equatable {
  /// The font used for ASCII characters (0-127).
  final String? ascii;

  /// The font used for High ANSI characters (128-255).
  final String? hAnsi;

  /// The font used for Complex Script characters (Arabic, etc.).
  final String? cs;

  /// The font used for East Asian characters.
  final String? eastAsia;

  /// The hint attribute (e.g. 'eastAsia').
  final String? hint;

  /// Theme font for ASCII characters.
  final String? asciiTheme;

  /// Theme font for High ANSI characters.
  final String? hAnsiTheme;

  /// Theme font for Complex Script characters.
  final String? csTheme;

  /// Theme font for East Asian characters.
  final String? eastAsiaTheme;

  const DocxFont({
    this.ascii,
    this.hAnsi,
    this.cs,
    this.eastAsia,
    this.hint,
    this.asciiTheme,
    this.hAnsiTheme,
    this.csTheme,
    this.eastAsiaTheme,
  });

  /// Creates a DocxFont with a single family for all slots (convenience).
  factory DocxFont.family(String family) {
    return DocxFont(
      ascii: family,
      hAnsi: family,
      cs: family,
      eastAsia: family,
    );
  }

  /// Changes the font family for all non-null slots, or sets all if none set.
  DocxFont withFamily(String family) {
    return DocxFont(
      ascii: family,
      hAnsi: family,
      cs: family,
      eastAsia: family,
      hint: hint,
      asciiTheme: asciiTheme,
      hAnsiTheme: hAnsiTheme,
      csTheme: csTheme,
      eastAsiaTheme: eastAsiaTheme,
    );
  }

  DocxFont copyWith({
    String? ascii,
    String? hAnsi,
    String? cs,
    String? eastAsia,
    String? hint,
    String? asciiTheme,
    String? hAnsiTheme,
    String? csTheme,
    String? eastAsiaTheme,
  }) {
    return DocxFont(
      ascii: ascii ?? this.ascii,
      hAnsi: hAnsi ?? this.hAnsi,
      cs: cs ?? this.cs,
      eastAsia: eastAsia ?? this.eastAsia,
      hint: hint ?? this.hint,
      asciiTheme: asciiTheme ?? this.asciiTheme,
      hAnsiTheme: hAnsiTheme ?? this.hAnsiTheme,
      csTheme: csTheme ?? this.csTheme,
      eastAsiaTheme: eastAsiaTheme ?? this.eastAsiaTheme,
    );
  }

  /// Merges this font with another, letting the other override non-null values.
  DocxFont merge(DocxFont? other) {
    if (other == null) return this;
    return DocxFont(
      ascii: other.ascii ?? ascii,
      hAnsi: other.hAnsi ?? hAnsi,
      cs: other.cs ?? cs,
      eastAsia: other.eastAsia ?? eastAsia,
      hint: other.hint ?? hint,
      asciiTheme: other.asciiTheme ?? asciiTheme,
      hAnsiTheme: other.hAnsiTheme ?? hAnsiTheme,
      csTheme: other.csTheme ?? csTheme,
      eastAsiaTheme: other.eastAsiaTheme ?? eastAsiaTheme,
    );
  }

  /// Returns the primary font family (ascii) for simple usage.
  String? get family => ascii ?? hAnsi ?? eastAsia ?? cs;

  @override
  List<Object?> get props => [
        ascii,
        hAnsi,
        cs,
        eastAsia,
        hint,
        asciiTheme,
        hAnsiTheme,
        csTheme,
        eastAsiaTheme,
      ];
}
