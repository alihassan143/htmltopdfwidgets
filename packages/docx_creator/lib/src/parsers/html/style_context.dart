import '../../core/enums.dart';

/// Style context for inline text formatting inheritance.
///
/// Tracks accumulated styles as we descend through HTML elements.
class HtmlStyleContext {
  final String? colorHex;
  final double? fontSize;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxTextDecoration decoration;
  final DocxHighlight highlight;
  final String? shadingFill;
  final String? href;
  final bool isLink;
  final bool isSuperscript;
  final bool isSubscript;
  final bool isAllCaps;
  final bool isSmallCaps;
  final bool isDoubleStrike;
  final bool isOutline;
  final bool isShadow;
  final bool isEmboss;
  final bool isImprint;

  const HtmlStyleContext({
    this.colorHex,
    this.fontSize,
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decoration = DocxTextDecoration.none,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.href,
    this.isLink = false,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.isDoubleStrike = false,
    this.isOutline = false,
    this.isShadow = false,
    this.isEmboss = false,
    this.isImprint = false,
  });

  HtmlStyleContext copyWith({
    String? colorHex,
    double? fontSize,
    DocxFontWeight? fontWeight,
    DocxFontStyle? fontStyle,
    DocxTextDecoration? decoration,
    DocxHighlight? highlight,
    String? shadingFill,
    String? href,
    bool? isLink,
    bool? isSuperscript,
    bool? isSubscript,
    bool? isAllCaps,
    bool? isSmallCaps,
    bool? isDoubleStrike,
    bool? isOutline,
    bool? isShadow,
    bool? isEmboss,
    bool? isImprint,
  }) {
    return HtmlStyleContext(
      colorHex: colorHex ?? this.colorHex,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      highlight: highlight ?? this.highlight,
      shadingFill: shadingFill ?? this.shadingFill,
      href: href ?? this.href,
      isLink: isLink ?? this.isLink,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isSubscript: isSubscript ?? this.isSubscript,
      isAllCaps: isAllCaps ?? this.isAllCaps,
      isSmallCaps: isSmallCaps ?? this.isSmallCaps,
      isDoubleStrike: isDoubleStrike ?? this.isDoubleStrike,
      isOutline: isOutline ?? this.isOutline,
      isShadow: isShadow ?? this.isShadow,
      isEmboss: isEmboss ?? this.isEmboss,
      isImprint: isImprint ?? this.isImprint,
    );
  }

  /// Merge style context with tag-based and CSS style updates.
  HtmlStyleContext mergeWith(
      String? tag, String style, String? Function(String) colorParser) {
    if ((tag == null || tag.isEmpty) && style.isEmpty) return this;

    var ctx = this;

    // Tag based updates
    if (tag != null) {
      switch (tag) {
        case 'b':
        case 'strong':
          ctx = ctx.copyWith(fontWeight: DocxFontWeight.bold);
          break;
        case 'i':
        case 'em':
          ctx = ctx.copyWith(fontStyle: DocxFontStyle.italic);
          break;
        case 'u':
          ctx = ctx.copyWith(decoration: DocxTextDecoration.underline);
          break;
        case 's':
        case 'del':
        case 'strike':
          ctx = ctx.copyWith(decoration: DocxTextDecoration.strikethrough);
          break;
        case 'sup':
          ctx = ctx.copyWith(isSuperscript: true);
          break;
        case 'sub':
          ctx = ctx.copyWith(isSubscript: true);
          break;
        case 'mark':
          ctx = ctx.copyWith(highlight: DocxHighlight.yellow);
          break;
      }
    }

    // Style attribute based updates
    if (style.isNotEmpty) {
      if (style.contains('font-weight') &&
          (style.contains('bold') || style.contains('700'))) {
        ctx = ctx.copyWith(fontWeight: DocxFontWeight.bold);
      }

      if (style.contains('font-style') && style.contains('italic')) {
        ctx = ctx.copyWith(fontStyle: DocxFontStyle.italic);
      }

      if (style.contains('text-decoration') && style.contains('underline')) {
        ctx = ctx.copyWith(decoration: DocxTextDecoration.underline);
      }

      if (style.contains('text-decoration') && style.contains('line-through')) {
        ctx = ctx.copyWith(decoration: DocxTextDecoration.strikethrough);
      }

      final sizeMatch = RegExp(r"font-size:\s*(\d+)").firstMatch(style);
      if (sizeMatch != null) {
        final fs = double.tryParse(sizeMatch.group(1)!);
        if (fs != null) ctx = ctx.copyWith(fontSize: fs);
      }

      // Color parsing
      final colorMatch = RegExp(
              r"(?<!-)color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
          .firstMatch(style);
      if (colorMatch != null) {
        final val = colorMatch.group(1);
        if (val != null) {
          final hex = colorParser(val);
          if (hex != null) ctx = ctx.copyWith(colorHex: hex);
        }
      }

      // Background Color (Shading)
      final bgMatch = RegExp(
              r"background-color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
          .firstMatch(style);
      if (bgMatch != null) {
        final bgVal = bgMatch.group(1)?.toLowerCase();
        if (bgVal != null) {
          final hex = colorParser(bgVal);
          if (hex != null) ctx = ctx.copyWith(shadingFill: hex);
        }
      }
    }

    return ctx;
  }

  /// Reset background color (for inheritance boundaries).
  /// NOTE: copyWith(shadingFill: null) doesn't work because null means "keep original".
  /// We need to explicitly create a new context without the shadingFill.
  HtmlStyleContext resetBackground() {
    return HtmlStyleContext(
      colorHex: colorHex,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      highlight: highlight,
      shadingFill: null, // Explicitly cleared
      href: href,
      isLink: isLink,
      isSuperscript: isSuperscript,
      isSubscript: isSubscript,
      isAllCaps: isAllCaps,
      isSmallCaps: isSmallCaps,
      isDoubleStrike: isDoubleStrike,
      isOutline: isOutline,
      isShadow: isShadow,
      isEmboss: isEmboss,
      isImprint: isImprint,
    );
  }
}

/// Parsed block-level styles (alignment, borders, shading).
class HtmlBlockStyles {
  final String? shadingFill;
  final String? colorHex;
  final DocxAlign align;
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;

  HtmlBlockStyles({
    this.shadingFill,
    this.colorHex,
    this.align = DocxAlign.left,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
  });
}
