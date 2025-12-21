import 'package:xml/xml.dart';

import 'docx_node.dart';

/// Drop cap style.
enum DocxDropCapStyle {
  /// No drop cap.
  none,

  /// Drop cap within the text margin.
  drop,

  /// Drop cap in the margin (outdented).
  margin,
}

/// A paragraph with drop cap styling (large initial letter).
///
/// Drop caps are used for decorative first letters in chapters or sections.
///
/// ## Example
/// ```dart
/// DocxDropCap(
///   letter: 'O',
///   lines: 3,
///   style: DocxDropCapStyle.drop,
///   restOfParagraph: [DocxText('nce upon a time...')],
/// )
/// ```
class DocxDropCap extends DocxBlock {
  /// The drop cap letter(s) - typically just the first letter.
  final String letter;

  /// Number of lines the drop cap spans (typically 2-4).
  final int lines;

  /// Drop cap style (drop or margin).
  final DocxDropCapStyle style;

  /// The rest of the paragraph content after the drop cap.
  final List<DocxInline> restOfParagraph;

  /// Font family for the drop cap letter.
  final String? fontFamily;

  /// Font size for the drop cap (in half-points, null = auto-calculated).
  final double? fontSize;

  /// Distance from text in twips.
  final int hSpace;

  const DocxDropCap({
    required this.letter,
    this.lines = 3,
    this.style = DocxDropCapStyle.drop,
    this.restOfParagraph = const [],
    this.fontFamily,
    this.fontSize,
    this.hSpace = 0,
    super.id,
  });

  DocxDropCap copyWith({
    String? letter,
    int? lines,
    DocxDropCapStyle? style,
    List<DocxInline>? restOfParagraph,
    String? fontFamily,
    double? fontSize,
    int? hSpace,
  }) {
    return DocxDropCap(
      letter: letter ?? this.letter,
      lines: lines ?? this.lines,
      style: style ?? this.style,
      restOfParagraph: restOfParagraph ?? this.restOfParagraph,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      hSpace: hSpace ?? this.hSpace,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitParagraph(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    // Drop cap is implemented as a paragraph with w:framePr
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        // Frame properties for drop cap
        builder.element('w:framePr', nest: () {
          builder.attribute('w:dropCap',
              style == DocxDropCapStyle.margin ? 'margin' : 'drop');
          builder.attribute('w:lines', lines.toString());
          builder.attribute('w:hSpace', hSpace.toString());
          builder.attribute('w:wrap', 'around');
          builder.attribute('w:vAnchor', 'text');
          builder.attribute('w:hAnchor', 'text');
        });
      });

      // The drop cap letter run
      builder.element('w:r', nest: () {
        builder.element('w:rPr', nest: () {
          // Large font size for drop cap
          if (fontSize != null) {
            builder.element('w:sz', nest: () {
              builder.attribute('w:val', (fontSize! * 2).toInt().toString());
            });
            builder.element('w:szCs', nest: () {
              builder.attribute('w:val', (fontSize! * 2).toInt().toString());
            });
          }
          if (fontFamily != null) {
            builder.element('w:rFonts', nest: () {
              builder.attribute('w:ascii', fontFamily!);
              builder.attribute('w:hAnsi', fontFamily!);
            });
          }
        });
        builder.element('w:t', nest: () {
          builder.text(letter);
        });
      });
    });

    // The rest of the paragraph follows as a separate paragraph
    if (restOfParagraph.isNotEmpty) {
      builder.element('w:p', nest: () {
        for (var inline in restOfParagraph) {
          inline.buildXml(builder);
        }
      });
    }
  }
}
