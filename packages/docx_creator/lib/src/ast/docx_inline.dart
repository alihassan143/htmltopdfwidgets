import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

/// A styled text run within a paragraph.
///
/// ## Basic
/// ```dart
/// DocxText('Hello')
/// ```
///
/// ## Styled
/// ```dart
/// DocxText.bold('Important')
/// DocxText.italic('Emphasis')
/// DocxText('Custom', color: DocxColor.red, fontSize: 14)
/// DocxText('Brand', color: DocxColor('#4285F4'))
/// ```
class DocxText extends DocxInline {
  final String content;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxTextDecoration decoration;
  final DocxColor? color;
  final DocxHighlight highlight;
  final double? fontSize;
  final String? fontFamily;
  final double? characterSpacing;
  final String? href;

  final bool isSuperscript;
  final bool isSubscript;
  final bool isAllCaps;
  final bool isSmallCaps;
  final bool isDoubleStrike;
  final bool isOutline;
  final bool isShadow;
  final bool isEmboss;
  final bool isImprint;

  const DocxText(
    this.content, {
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decoration = DocxTextDecoration.none,
    this.color,
    this.highlight = DocxHighlight.none,
    this.fontSize,
    this.fontFamily,
    this.characterSpacing,
    this.href,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.isDoubleStrike = false,
    this.isOutline = false,
    this.isShadow = false,
    this.isEmboss = false,
    this.isImprint = false,
    super.id,
  });

  // ============================================================
  // SIMPLE CONSTRUCTORS
  // ============================================================

  /// Bold text.
  const DocxText.bold(
    this.content, {
    this.color,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Italic text.
  const DocxText.italic(
    this.content, {
    this.color,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.italic,
        decoration = DocxTextDecoration.none,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Bold and italic text.
  const DocxText.boldItalic(
    this.content, {
    this.color,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.italic,
        decoration = DocxTextDecoration.none,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Underlined text.
  const DocxText.underline(
    this.content, {
    this.color,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.underline,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Strikethrough text.
  const DocxText.strike(
    this.content, {
    this.color,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.strikethrough,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Hyperlink text.
  const DocxText.link(
    this.content, {
    required this.href,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.underline,
        color = DocxColor.blue,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Inline code text.
  const DocxText.code(this.content, {this.fontSize, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.lightGray,
        fontFamily = 'Courier New',
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Highlighted text.
  const DocxText.highlighted(
    this.content, {
    this.highlight = DocxHighlight.yellow,
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Superscript text (e.g., x²).
  const DocxText.superscript(this.content, {this.fontSize, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        characterSpacing = null,
        href = null,
        isSuperscript = true,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Subscript text (e.g., H₂O).
  const DocxText.subscript(this.content, {this.fontSize, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = true,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// ALL CAPS text.
  const DocxText.allCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = true,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  /// Small Caps text.
  const DocxText.smallCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = true,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false;

  // ============================================================
  // COPYWITH
  // ============================================================

  DocxText copyWith({
    String? content,
    DocxFontWeight? fontWeight,
    DocxFontStyle? fontStyle,
    DocxTextDecoration? decoration,
    DocxColor? color,
    DocxHighlight? highlight,
    double? fontSize,
    String? fontFamily,
    double? characterSpacing,
    String? href,
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
    return DocxText(
      content ?? this.content,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      color: color ?? this.color,
      highlight: highlight ?? this.highlight,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      characterSpacing: characterSpacing ?? this.characterSpacing,
      href: href ?? this.href,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isSubscript: isSubscript ?? this.isSubscript,
      isAllCaps: isAllCaps ?? this.isAllCaps,
      isSmallCaps: isSmallCaps ?? this.isSmallCaps,
      isDoubleStrike: isDoubleStrike ?? this.isDoubleStrike,
      isOutline: isOutline ?? this.isOutline,
      isShadow: isShadow ?? this.isShadow,
      isEmboss: isEmboss ?? this.isEmboss,
      isImprint: isImprint ?? this.isImprint,
      id: id,
    );
  }

  // ============================================================
  // COMPUTED
  // ============================================================

  bool get isBold => fontWeight == DocxFontWeight.bold;
  bool get isItalic => fontStyle == DocxFontStyle.italic;
  bool get isUnderline => decoration == DocxTextDecoration.underline;
  bool get isStrike => decoration == DocxTextDecoration.strikethrough;
  bool get isLink => href != null;

  String? get effectiveColorHex => color?.hex;

  // ============================================================
  // AST
  // ============================================================

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        if (_hasFormatting) {
          builder.element(
            'w:rPr',
            nest: () {
              if (isBold) builder.element('w:b');
              if (isItalic) builder.element('w:i');
              if (isUnderline) {
                builder.element(
                  'w:u',
                  nest: () {
                    builder.attribute('w:val', 'single');
                  },
                );
              }
              if (isStrike) builder.element('w:strike');
              if (isDoubleStrike) builder.element('w:dstrike');
              if (isOutline) builder.element('w:outline');
              if (isShadow) builder.element('w:shadow');
              if (isEmboss) builder.element('w:emboss');
              if (isImprint) builder.element('w:imprint');
              if (isAllCaps) builder.element('w:caps');
              if (isSmallCaps) builder.element('w:smallCaps');
              if (isSuperscript || isSubscript) {
                builder.element(
                  'w:vertAlign',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      isSuperscript ? 'superscript' : 'subscript',
                    );
                  },
                );
              }
              if (effectiveColorHex != null) {
                builder.element(
                  'w:color',
                  nest: () {
                    builder.attribute('w:val', effectiveColorHex!);
                  },
                );
              }
              if (fontSize != null) {
                builder.element(
                  'w:sz',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      (fontSize! * 2).toInt().toString(),
                    );
                  },
                );
                builder.element(
                  'w:szCs',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      (fontSize! * 2).toInt().toString(),
                    );
                  },
                );
              }
              if (fontFamily != null) {
                builder.element(
                  'w:rFonts',
                  nest: () {
                    builder.attribute('w:ascii', fontFamily!);
                    builder.attribute('w:hAnsi', fontFamily!);
                  },
                );
              }
              if (highlight != DocxHighlight.none) {
                builder.element(
                  'w:highlight',
                  nest: () {
                    builder.attribute('w:val', highlight.name);
                  },
                );
              }
              if (characterSpacing != null) {
                builder.element(
                  'w:spacing',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      characterSpacing!.toInt().toString(),
                    );
                  },
                );
              }
            },
          );
        }

        builder.element(
          'w:t',
          nest: () {
            if (content.startsWith(' ') || content.endsWith(' ')) {
              builder.attribute('xml:space', 'preserve');
            }
            builder.text(content);
          },
        );
      },
    );
  }

  bool get _hasFormatting =>
      isBold ||
      isItalic ||
      isUnderline ||
      isStrike ||
      isDoubleStrike ||
      isOutline ||
      isShadow ||
      isEmboss ||
      isImprint ||
      isAllCaps ||
      isSmallCaps ||
      isSuperscript ||
      isSubscript ||
      effectiveColorHex != null ||
      fontSize != null ||
      fontFamily != null ||
      highlight != DocxHighlight.none ||
      characterSpacing != null;
}

/// A line break.
class DocxLineBreak extends DocxInline {
  const DocxLineBreak({super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element('w:br');
      },
    );
  }
}

/// A tab character.
class DocxTab extends DocxInline {
  const DocxTab({super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element('w:tab');
      },
    );
  }
}
