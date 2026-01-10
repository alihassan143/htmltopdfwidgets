import '../../../../docx_creator.dart';

/// Represents the fully resolved (effective) style for an element.
///
/// Unlike [DocxStyle], which stores individual style definitions that may have
/// null values requiring inheritance lookup, [ResolvedStyle] contains the
/// final computed values after resolving the entire style inheritance chain.
///
/// This is useful for UI rendering where you need to know the actual
/// formatting that will be applied.
///
/// Example:
/// ```dart
/// final resolver = StyleResolver(context.styles);
/// final resolved = resolver.resolveRun('MyStyle', directProps: runProps);
/// print(resolved.fontSize); // Always non-null - defaults applied
/// ```
class ResolvedStyle {
  // Paragraph properties
  final DocxAlign align;
  final String? shadingFill;
  final int spacingAfter;
  final int spacingBefore;
  final int lineSpacing;
  final int indentLeft;
  final int indentRight;
  final int indentFirstLine;

  // Run properties
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxTextDecoration decoration;
  final DocxColor color;
  final double fontSize;
  final String fontFamily;
  final DocxHighlight highlight;
  final bool isSuperscript;
  final bool isSubscript;
  final bool isAllCaps;
  final bool isSmallCaps;
  final bool isDoubleStrike;
  final bool isOutline;
  final bool isShadow;
  final bool isEmboss;
  final bool isImprint;
  final DocxBorderSide? textBorder;

  // Borders
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;

  const ResolvedStyle({
    this.align = DocxAlign.left,
    this.shadingFill,
    this.spacingAfter = 0,
    this.spacingBefore = 0,
    this.lineSpacing = 240, // Default single spacing in twips
    this.indentLeft = 0,
    this.indentRight = 0,
    this.indentFirstLine = 0,
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decoration = DocxTextDecoration.none,
    this.color = DocxColor.black,
    this.fontSize = 11.0, // Default 11pt
    this.fontFamily = 'Calibri',
    this.highlight = DocxHighlight.none,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.isDoubleStrike = false,
    this.isOutline = false,
    this.isShadow = false,
    this.isEmboss = false,
    this.isImprint = false,
    this.textBorder,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
  });

  /// Creates a fully resolved style from an unresolved DocxStyle.
  factory ResolvedStyle.fromDocxStyle(DocxStyle style) {
    return ResolvedStyle(
      align: style.align ?? DocxAlign.left,
      shadingFill: style.shadingFill,
      spacingAfter: style.spacingAfter ?? 0,
      spacingBefore: style.spacingBefore ?? 0,
      lineSpacing: style.lineSpacing ?? 240,
      indentLeft: style.indentLeft ?? 0,
      indentRight: style.indentRight ?? 0,
      indentFirstLine: style.indentFirstLine ?? 0,
      fontWeight: style.fontWeight ?? DocxFontWeight.normal,
      fontStyle: style.fontStyle ?? DocxFontStyle.normal,
      decoration: style.decoration ?? DocxTextDecoration.none,
      color: style.color ?? DocxColor.black,
      fontSize: style.fontSize ?? 11.0,
      fontFamily: style.fontFamily ?? 'Calibri',
      highlight: style.highlight ?? DocxHighlight.none,
      isSuperscript: style.isSuperscript ?? false,
      isSubscript: style.isSubscript ?? false,
      isAllCaps: style.isAllCaps ?? false,
      isSmallCaps: style.isSmallCaps ?? false,
      isDoubleStrike: style.isDoubleStrike ?? false,
      isOutline: style.isOutline ?? false,
      isShadow: style.isShadow ?? false,
      isEmboss: style.isEmboss ?? false,
      isImprint: style.isImprint ?? false,
      textBorder: style.textBorder,
      borderTop: style.borderTop,
      borderBottom: style.borderBottomSide,
      borderLeft: style.borderLeft,
      borderRight: style.borderRight,
    );
  }

  /// Creates a copy with only specified values overridden.
  ResolvedStyle copyWith({
    DocxAlign? align,
    String? shadingFill,
    int? spacingAfter,
    int? spacingBefore,
    int? lineSpacing,
    int? indentLeft,
    int? indentRight,
    int? indentFirstLine,
    DocxFontWeight? fontWeight,
    DocxFontStyle? fontStyle,
    DocxTextDecoration? decoration,
    DocxColor? color,
    double? fontSize,
    String? fontFamily,
    DocxHighlight? highlight,
    bool? isSuperscript,
    bool? isSubscript,
    bool? isAllCaps,
    bool? isSmallCaps,
    bool? isDoubleStrike,
    bool? isOutline,
    bool? isShadow,
    bool? isEmboss,
    bool? isImprint,
    DocxBorderSide? textBorder,
    DocxBorderSide? borderTop,
    DocxBorderSide? borderBottom,
    DocxBorderSide? borderLeft,
    DocxBorderSide? borderRight,
  }) {
    return ResolvedStyle(
      align: align ?? this.align,
      shadingFill: shadingFill ?? this.shadingFill,
      spacingAfter: spacingAfter ?? this.spacingAfter,
      spacingBefore: spacingBefore ?? this.spacingBefore,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      indentLeft: indentLeft ?? this.indentLeft,
      indentRight: indentRight ?? this.indentRight,
      indentFirstLine: indentFirstLine ?? this.indentFirstLine,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      highlight: highlight ?? this.highlight,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isSubscript: isSubscript ?? this.isSubscript,
      isAllCaps: isAllCaps ?? this.isAllCaps,
      isSmallCaps: isSmallCaps ?? this.isSmallCaps,
      isDoubleStrike: isDoubleStrike ?? this.isDoubleStrike,
      isOutline: isOutline ?? this.isOutline,
      isShadow: isShadow ?? this.isShadow,
      isEmboss: isEmboss ?? this.isEmboss,
      isImprint: isImprint ?? this.isImprint,
      textBorder: textBorder ?? this.textBorder,
      borderTop: borderTop ?? this.borderTop,
      borderBottom: borderBottom ?? this.borderBottom,
      borderLeft: borderLeft ?? this.borderLeft,
      borderRight: borderRight ?? this.borderRight,
    );
  }
}

/// Resolves style inheritance chains to produce effective styles.
///
/// This class handles the DOCX style hierarchy:
/// 1. Document defaults
/// 2. Named style (with basedOn inheritance)
/// 3. Direct properties
class StyleResolver {
  final Map<String, DocxStyle> _styles;
  final Map<String, ResolvedStyle> _cache = {};

  /// Default document style values.
  static const defaultStyle = ResolvedStyle();

  StyleResolver(this._styles);

  /// Resolves a paragraph style by ID, caching the result.
  ///
  /// Returns the fully resolved style with all inheritance applied.
  ResolvedStyle resolveParagraphStyle(String? styleId) {
    if (styleId == null) return defaultStyle;

    // Check cache
    if (_cache.containsKey(styleId)) {
      return _cache[styleId]!;
    }

    // Resolve inheritance chain
    final resolved = _resolveChain(styleId);
    _cache[styleId] = resolved;
    return resolved;
  }

  /// Resolves a run (character) style, combining paragraph style with
  /// run-specific overrides.
  ResolvedStyle resolveRunStyle({
    String? paragraphStyleId,
    String? runStyleId,
    DocxStyle? directProps,
  }) {
    // Start with paragraph style
    var resolved = resolveParagraphStyle(paragraphStyleId);

    // Apply run style if present
    if (runStyleId != null && _styles.containsKey(runStyleId)) {
      final runStyle = _resolveChain(runStyleId);
      resolved = _mergeResolved(resolved, runStyle);
    }

    // Apply direct properties
    if (directProps != null) {
      resolved = _applyDirect(resolved, directProps);
    }

    return resolved;
  }

  ResolvedStyle _resolveChain(String styleId) {
    final style = _styles[styleId];
    if (style == null) return defaultStyle;

    // Resolve parent first
    ResolvedStyle base = defaultStyle;
    if (style.basedOn != null && style.basedOn != styleId) {
      base = _resolveChain(style.basedOn!);
    }

    // Apply this style's properties
    return _applyDirect(base, style);
  }

  ResolvedStyle _mergeResolved(ResolvedStyle base, ResolvedStyle overlay) {
    return ResolvedStyle(
      align: overlay.align,
      shadingFill: overlay.shadingFill ?? base.shadingFill,
      spacingAfter:
          overlay.spacingAfter != 0 ? overlay.spacingAfter : base.spacingAfter,
      spacingBefore: overlay.spacingBefore != 0
          ? overlay.spacingBefore
          : base.spacingBefore,
      lineSpacing:
          overlay.lineSpacing != 240 ? overlay.lineSpacing : base.lineSpacing,
      indentLeft:
          overlay.indentLeft != 0 ? overlay.indentLeft : base.indentLeft,
      indentRight:
          overlay.indentRight != 0 ? overlay.indentRight : base.indentRight,
      indentFirstLine: overlay.indentFirstLine != 0
          ? overlay.indentFirstLine
          : base.indentFirstLine,
      fontWeight: overlay.fontWeight != DocxFontWeight.normal
          ? overlay.fontWeight
          : base.fontWeight,
      fontStyle: overlay.fontStyle != DocxFontStyle.normal
          ? overlay.fontStyle
          : base.fontStyle,
      decoration: overlay.decoration != DocxTextDecoration.none
          ? overlay.decoration
          : base.decoration,
      color: overlay.color != DocxColor.black ? overlay.color : base.color,
      fontSize: overlay.fontSize != 11.0 ? overlay.fontSize : base.fontSize,
      fontFamily: overlay.fontFamily != 'Calibri'
          ? overlay.fontFamily
          : base.fontFamily,
      highlight: overlay.highlight != DocxHighlight.none
          ? overlay.highlight
          : base.highlight,
      isSuperscript: overlay.isSuperscript || base.isSuperscript,
      isSubscript: overlay.isSubscript || base.isSubscript,
      isAllCaps: overlay.isAllCaps || base.isAllCaps,
      isSmallCaps: overlay.isSmallCaps || base.isSmallCaps,
      isDoubleStrike: overlay.isDoubleStrike || base.isDoubleStrike,
      isOutline: overlay.isOutline || base.isOutline,
      isShadow: overlay.isShadow || base.isShadow,
      isEmboss: overlay.isEmboss || base.isEmboss,
      isImprint: overlay.isImprint || base.isImprint,
      textBorder: overlay.textBorder ?? base.textBorder,
      borderTop: overlay.borderTop ?? base.borderTop,
      borderBottom: overlay.borderBottom ?? base.borderBottom,
      borderLeft: overlay.borderLeft ?? base.borderLeft,
      borderRight: overlay.borderRight ?? base.borderRight,
    );
  }

  ResolvedStyle _applyDirect(ResolvedStyle base, DocxStyle direct) {
    return ResolvedStyle(
      align: direct.align ?? base.align,
      shadingFill: direct.shadingFill ?? base.shadingFill,
      spacingAfter: direct.spacingAfter ?? base.spacingAfter,
      spacingBefore: direct.spacingBefore ?? base.spacingBefore,
      lineSpacing: direct.lineSpacing ?? base.lineSpacing,
      indentLeft: direct.indentLeft ?? base.indentLeft,
      indentRight: direct.indentRight ?? base.indentRight,
      indentFirstLine: direct.indentFirstLine ?? base.indentFirstLine,
      fontWeight: direct.fontWeight ?? base.fontWeight,
      fontStyle: direct.fontStyle ?? base.fontStyle,
      decoration: direct.decoration ?? base.decoration,
      color: direct.color ?? base.color,
      fontSize: direct.fontSize ?? base.fontSize,
      fontFamily: direct.fontFamily ?? base.fontFamily,
      highlight: direct.highlight ?? base.highlight,
      isSuperscript: direct.isSuperscript ?? base.isSuperscript,
      isSubscript: direct.isSubscript ?? base.isSubscript,
      isAllCaps: direct.isAllCaps ?? base.isAllCaps,
      isSmallCaps: direct.isSmallCaps ?? base.isSmallCaps,
      isDoubleStrike: direct.isDoubleStrike ?? base.isDoubleStrike,
      isOutline: direct.isOutline ?? base.isOutline,
      isShadow: direct.isShadow ?? base.isShadow,
      isEmboss: direct.isEmboss ?? base.isEmboss,
      isImprint: direct.isImprint ?? base.isImprint,
      textBorder: direct.textBorder ?? base.textBorder,
      borderTop: direct.borderTop ?? base.borderTop,
      borderBottom: direct.borderBottomSide ?? base.borderBottom,
      borderLeft: direct.borderLeft ?? base.borderLeft,
      borderRight: direct.borderRight ?? base.borderRight,
    );
  }

  /// Clears the resolution cache.
  void clearCache() => _cache.clear();
}
