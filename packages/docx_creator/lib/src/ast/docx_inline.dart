import 'package:xml/xml.dart';

import '../core/enums.dart';
import '../reader/models/docx_font.dart';
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
  final String? shadingFill; // Background color hex
  final double? fontSize;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint.
  final String? themeTint;

  /// Theme color shade.
  final String? themeShade;

  /// Legacy font family (single string). Use [fonts] for granular control.
  final String? fontFamily;

  /// granular font properties.
  final DocxFont? fonts;
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

  /// Text border (box around text), from w:bdr element
  final DocxBorderSide? textBorder;

  const DocxText(
    this.content, {
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decoration = DocxTextDecoration.none,
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.fontFamily,
    this.fonts,
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
    this.textBorder,
    super.id,
  });

  // ============================================================
  // SIMPLE CONSTRUCTORS
  // ============================================================

  /// Bold text.
  const DocxText.bold(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Italic text.
  const DocxText.italic(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.italic,
        decoration = DocxTextDecoration.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Bold and italic text.
  const DocxText.boldItalic(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.italic,
        decoration = DocxTextDecoration.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Underlined text.
  const DocxText.underline(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.underline,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Strikethrough text.
  const DocxText.strike(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.strikethrough,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Hyperlink text.
  const DocxText.link(
    this.content, {
    required this.href,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.underline,
        color = DocxColor.blue,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Inline code text.
  const DocxText.code(this.content,
      {this.fontSize, this.shadingFill, this.color, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        highlight = DocxHighlight.none,
        fontFamily = 'Courier New',
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Highlighted text.
  const DocxText.highlighted(
    this.content, {
    this.highlight = DocxHighlight.yellow,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.color = DocxColor.black,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Superscript text (e.g., x²).
  const DocxText.superscript(this.content,
      {this.fontSize, this.shadingFill, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = true,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Subscript text (e.g., H₂O).
  const DocxText.subscript(this.content,
      {this.fontSize, this.shadingFill, super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = true,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// ALL CAPS text.
  const DocxText.allCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = true,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

  /// Small Caps text.
  const DocxText.smallCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decoration = DocxTextDecoration.none,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = true,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        textBorder = null;

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
    String? shadingFill,
    double? fontSize,
    String? themeColor,
    String? themeTint,
    String? themeShade,
    String? fontFamily,
    DocxFont? fonts,
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
    DocxBorderSide? textBorder,
  }) {
    return DocxText(
      content ?? this.content,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      color: color ?? this.color,
      highlight: highlight ?? this.highlight,
      shadingFill: shadingFill ?? this.shadingFill,
      fontSize: fontSize ?? this.fontSize,
      themeColor: themeColor ?? this.themeColor,
      themeTint: themeTint ?? this.themeTint,
      themeShade: themeShade ?? this.themeShade,
      fontFamily: fontFamily ?? this.fontFamily,
      fonts: fonts ?? this.fonts,
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
      textBorder: textBorder ?? this.textBorder,
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
              final effectiveFonts = fonts ??
                  (fontFamily != null ? DocxFont.family(fontFamily!) : null);
              if (effectiveFonts != null) {
                builder.element(
                  'w:rFonts',
                  nest: () {
                    if (effectiveFonts.ascii != null) {
                      builder.attribute('w:ascii', effectiveFonts.ascii!);
                    }
                    if (effectiveFonts.hAnsi != null) {
                      builder.attribute('w:hAnsi', effectiveFonts.hAnsi!);
                    }
                    if (effectiveFonts.cs != null) {
                      builder.attribute('w:cs', effectiveFonts.cs!);
                    }
                    if (effectiveFonts.eastAsia != null) {
                      builder.attribute('w:eastAsia', effectiveFonts.eastAsia!);
                    }
                    if (effectiveFonts.hint != null) {
                      builder.attribute('w:hint', effectiveFonts.hint!);
                    }
                    if (effectiveFonts.asciiTheme != null) {
                      builder.attribute(
                          'w:asciiTheme', effectiveFonts.asciiTheme!);
                    }
                    if (effectiveFonts.hAnsiTheme != null) {
                      builder.attribute(
                          'w:hAnsiTheme', effectiveFonts.hAnsiTheme!);
                    }
                    if (effectiveFonts.csTheme != null) {
                      builder.attribute('w:csTheme', effectiveFonts.csTheme!);
                    }
                    if (effectiveFonts.eastAsiaTheme != null) {
                      builder.attribute(
                          'w:eastAsiaTheme', effectiveFonts.eastAsiaTheme!);
                    }
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
              if (shadingFill != null) {
                builder.element(
                  'w:shd',
                  nest: () {
                    builder.attribute('w:val', 'clear');
                    builder.attribute('w:color', 'auto');
                    builder.attribute('w:fill', shadingFill!);
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
              // Text border (box around text)
              if (textBorder != null) {
                builder.element(
                  'w:bdr',
                  nest: () {
                    builder.attribute('w:val', textBorder!.style.xmlValue);
                    builder.attribute('w:sz', textBorder!.size.toString());
                    builder.attribute('w:space', textBorder!.space.toString());
                    builder.attribute('w:color', textBorder!.color.hex);
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
      fonts != null ||
      highlight != DocxHighlight.none ||
      characterSpacing != null ||
      textBorder != null;
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

/// A clickable checkbox (form field).
class DocxCheckbox extends DocxInline {
  final bool isChecked;
  final double? fontSize;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxColor? color;

  const DocxCheckbox({
    this.isChecked = false,
    this.fontSize,
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.color,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(
        DocxText(
          isChecked ? '☒' : '☐',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: color,
          fontSize: fontSize,
        ),
      );

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:sdt',
      nest: () {
        builder.element(
          'w:sdtPr',
          nest: () {
            builder.element(
              'w14:checkbox',
              nest: () {
                builder.element('w14:checked', nest: () {
                  builder.attribute('w14:val', isChecked ? '1' : '0');
                });
              },
            );
            builder.element('w:alias', nest: () {
              builder.attribute('w:val', 'Checkbox');
            });
            builder.element('w:tag', nest: () {
              builder.attribute('w:val', 'checkbox');
            });
          },
        );
        builder.element(
          'w:sdtContent',
          nest: () {
            builder.element(
              'w:r',
              nest: () {
                if (fontSize != null ||
                    fontWeight == DocxFontWeight.bold ||
                    fontStyle == DocxFontStyle.italic ||
                    color != null) {
                  builder.element(
                    'w:rPr',
                    nest: () {
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
                      }
                      if (fontWeight == DocxFontWeight.bold) {
                        builder.element('w:b');
                      }
                      if (fontStyle == DocxFontStyle.italic) {
                        builder.element('w:i');
                      }
                      if (color != null) {
                        builder.element('w:color', nest: () {
                          builder.attribute('w:val', color!.hex);
                        });
                      }
                    },
                  );
                }
                builder.element(
                  'w:t',
                  nest: () {
                    builder.text(isChecked ? '☒' : '☐');
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
