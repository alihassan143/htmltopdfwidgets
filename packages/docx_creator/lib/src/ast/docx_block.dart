import 'package:xml/xml.dart';

import '../core/defaults.dart';
import '../core/enums.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// A paragraph containing styled text and inline elements.
///
/// [DocxParagraph] is the primary block-level element for text content.
/// It can contain multiple [DocxText] runs with different formatting.
///
/// ## Basic Usage
/// ```dart
/// DocxParagraph(children: [
///   DocxText('Hello, '),
///   DocxText.bold('World'),
///   DocxText('!'),
/// ])
/// ```
///
/// ## Heading Shortcut
/// ```dart
/// DocxParagraph.heading1('Chapter 1: Introduction')
/// DocxParagraph.heading2('Section 1.1')
/// ```
///
/// ## Simple Text Shortcut
/// ```dart
/// DocxParagraph.text('A simple paragraph with just text.')
/// ```
///
/// ## Fluent API
/// ```dart
/// DocxParagraph()
///   .add(DocxText('Hello'))
///   .add(DocxText.bold(' World'))
///   .align(DocxAlign.center)
/// ```
class DocxParagraph extends DocxBlock {
  /// Child elements (typically [DocxText] runs).
  final List<DocxInline> children;

  /// Text alignment.
  final DocxAlign align;

  /// Style ID (e.g., 'Normal', 'Heading1').
  final String? styleId;

  /// Spacing after paragraph in twips.
  final int? spacingAfter;

  /// Spacing before paragraph in twips.
  final int? spacingBefore;

  /// Line spacing in twips (240 = single, 360 = 1.5, 480 = double).
  final int? lineSpacing;

  /// Left indentation in twips.
  final int? indentLeft;

  /// Right indentation in twips.
  final int? indentRight;

  /// First line indentation in twips (can be negative for hanging indent).
  final int? indentFirstLine;

  /// Bottom border style.
  final DocxBorder? borderBottom;

  /// Background shading color hex.
  final String? shadingFill;

  /// Outline level for TOC (0-8, null for body text).
  final int? outlineLevel;

  /// Whether to insert a page break before this paragraph.
  final bool pageBreakBefore;

  /// Numbering ID for list items.
  final int? numId;

  /// Indentation level for list items (0-based).
  final int? ilvl;

  /// Creates a paragraph with specified children and formatting.
  const DocxParagraph({
    this.children = const [],
    this.align = DocxAlign.left,
    this.styleId,
    this.spacingAfter,
    this.spacingBefore,
    this.lineSpacing,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.borderBottom,
    this.shadingFill,
    this.outlineLevel,
    this.pageBreakBefore = false,
    this.numId,
    this.ilvl,
    super.id,
  });

  // ============================================================
  // CONVENIENCE CONSTRUCTORS
  // ============================================================

  /// Creates a simple paragraph with plain text.
  ///
  /// ```dart
  /// DocxParagraph.text('This is a simple paragraph.')
  /// ```
  factory DocxParagraph.text(
    String text, {
    DocxAlign align = DocxAlign.left,
    double? fontSize,
    String? fontFamily,
  }) {
    return DocxParagraph(
      align: align,
      children: [DocxText(text, fontSize: fontSize, fontFamily: fontFamily)],
    );
  }

  /// Creates a heading paragraph.
  ///
  /// ```dart
  /// DocxParagraph.heading(DocxHeadingLevel.h1, 'Main Title')
  /// ```
  factory DocxParagraph.heading(
    DocxHeadingLevel level,
    String text, {
    DocxAlign align = DocxAlign.left,
  }) {
    return DocxParagraph(
      styleId: level.styleId,
      align: align,
      children: [
        DocxText(text),
      ],
    );
  }

  /// Creates an H1 heading.
  factory DocxParagraph.heading1(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h1, text, align: align);

  /// Creates an H2 heading.
  factory DocxParagraph.heading2(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h2, text, align: align);

  /// Creates an H3 heading.
  factory DocxParagraph.heading3(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h3, text, align: align);

  /// Creates an H4 heading.
  factory DocxParagraph.heading4(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h4, text, align: align);

  /// Creates an H5 heading.
  factory DocxParagraph.heading5(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h5, text, align: align);

  /// Creates an H6 heading.
  factory DocxParagraph.heading6(
    String text, {
    DocxAlign align = DocxAlign.left,
  }) =>
      DocxParagraph.heading(DocxHeadingLevel.h6, text, align: align);

  /// Creates a blockquote paragraph.
  factory DocxParagraph.quote(String text) {
    return DocxParagraph(
      indentLeft: 720, // 0.5 inch
      styleId: DocxStyleIds.quote,
      children: [DocxText.italic(text)],
    );
  }

  /// Creates a code block paragraph.
  factory DocxParagraph.code(String code) {
    return DocxParagraph(
      shadingFill: 'F5F5F5',
      children: [DocxText.code(code)],
    );
  }

  // ============================================================
  // FLUENT API
  // ============================================================

  /// Returns a copy with the specified child added.
  DocxParagraph add(DocxInline child) {
    return copyWith(children: [...children, child]);
  }

  /// Returns a copy with the specified alignment.
  DocxParagraph aligned(DocxAlign newAlign) {
    return copyWith(align: newAlign);
  }

  /// Returns a copy with the specified style.
  DocxParagraph styled(String newStyleId) {
    return copyWith(styleId: newStyleId);
  }

  /// Returns a copy with specified modifications.
  DocxParagraph copyWith({
    List<DocxInline>? children,
    DocxAlign? align,
    String? styleId,
    int? spacingAfter,
    int? spacingBefore,
    int? lineSpacing,
    int? indentLeft,
    int? indentRight,
    int? indentFirstLine,
    DocxBorder? borderBottom,
    String? shadingFill,
    int? outlineLevel,
    bool? pageBreakBefore,
    int? numId,
    int? ilvl,
  }) {
    return DocxParagraph(
      children: children ?? this.children,
      align: align ?? this.align,
      styleId: styleId ?? this.styleId,
      spacingAfter: spacingAfter ?? this.spacingAfter,
      spacingBefore: spacingBefore ?? this.spacingBefore,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      indentLeft: indentLeft ?? this.indentLeft,
      indentRight: indentRight ?? this.indentRight,
      indentFirstLine: indentFirstLine ?? this.indentFirstLine,
      borderBottom: borderBottom ?? this.borderBottom,
      shadingFill: shadingFill ?? this.shadingFill,
      outlineLevel: outlineLevel ?? this.outlineLevel,
      pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
      numId: numId ?? this.numId,
      ilvl: ilvl ?? this.ilvl,
      id: id,
    );
  }

  // ============================================================
  // AST VISITOR
  // ============================================================

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitParagraph(this);
  }

  // ============================================================
  // XML GENERATION
  // ============================================================

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:p',
      nest: () {
        // Paragraph properties
        if (_hasProperties) {
          builder.element(
            'w:pPr',
            nest: () {
              if (styleId != null) {
                builder.element(
                  'w:pStyle',
                  nest: () {
                    builder.attribute('w:val', styleId!);
                  },
                );
              }
              if (align != DocxAlign.left) {
                builder.element(
                  'w:jc',
                  nest: () {
                    builder.attribute('w:val', align.name);
                  },
                );
              }
              if (spacingAfter != null ||
                  spacingBefore != null ||
                  lineSpacing != null) {
                builder.element(
                  'w:spacing',
                  nest: () {
                    if (spacingAfter != null) {
                      builder.attribute('w:after', spacingAfter.toString());
                    }
                    if (spacingBefore != null) {
                      builder.attribute('w:before', spacingBefore.toString());
                    }
                    if (lineSpacing != null) {
                      builder.attribute('w:line', lineSpacing.toString());
                    }
                  },
                );
              }
              if (indentLeft != null ||
                  indentRight != null ||
                  indentFirstLine != null) {
                builder.element(
                  'w:ind',
                  nest: () {
                    if (indentLeft != null) {
                      builder.attribute('w:left', indentLeft.toString());
                    }
                    if (indentRight != null) {
                      builder.attribute('w:right', indentRight.toString());
                    }
                    if (indentFirstLine != null) {
                      builder.attribute(
                        'w:firstLine',
                        indentFirstLine.toString(),
                      );
                    }
                  },
                );
              }
              if (borderBottom != null && borderBottom != DocxBorder.none) {
                builder.element(
                  'w:pBdr',
                  nest: () {
                    builder.element(
                      'w:bottom',
                      nest: () {
                        builder.attribute('w:val', borderBottom!.xmlValue);
                        builder.attribute('w:sz', '4');
                        builder.attribute('w:space', '1');
                        builder.attribute('w:color', 'auto');
                      },
                    );
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
              if (outlineLevel != null) {
                builder.element(
                  'w:outlineLvl',
                  nest: () {
                    builder.attribute('w:val', outlineLevel.toString());
                  },
                );
              }
              if (pageBreakBefore) {
                builder.element('w:pageBreakBefore');
              }
              if (numId != null) {
                builder.element(
                  'w:numPr',
                  nest: () {
                    builder.element(
                      'w:ilvl',
                      nest: () {
                        builder.attribute('w:val', (ilvl ?? 0).toString());
                      },
                    );
                    builder.element(
                      'w:numId',
                      nest: () {
                        builder.attribute('w:val', numId.toString());
                      },
                    );
                  },
                );
              }
            },
          );
        }

        // Child runs
        for (var child in children) {
          child.buildXml(builder);
        }
      },
    );
  }

  bool get _hasProperties =>
      styleId != null ||
      align != DocxAlign.left ||
      spacingAfter != null ||
      spacingBefore != null ||
      lineSpacing != null ||
      indentLeft != null ||
      indentRight != null ||
      indentFirstLine != null ||
      borderBottom != null ||
      shadingFill != null ||
      outlineLevel != null ||
      pageBreakBefore ||
      numId != null;
}
