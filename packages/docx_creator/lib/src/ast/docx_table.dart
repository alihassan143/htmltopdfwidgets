import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_block.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// Table styling options.
///
/// Use these to create professional looking tables.
class DocxTableStyle {
  /// Border style for all borders.
  final DocxBorder border;

  /// Border color (hex).
  final String borderColor;

  /// Border width in eighths of a point (4 = 0.5pt, 8 = 1pt).
  final int borderWidth;

  /// Header row background color.
  final String? headerFill;

  /// Alternating row colors (zebra striping).
  final String? evenRowFill;
  final String? oddRowFill;

  /// Cell padding in twips.
  final int cellPadding;

  /// Detailed border overrides.
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
  final DocxBorderSide? borderInsideH;
  final DocxBorderSide? borderInsideV;

  const DocxTableStyle({
    this.border = DocxBorder.single,
    this.borderColor = 'auto',
    this.borderWidth = 4,
    this.headerFill,
    this.evenRowFill,
    this.oddRowFill,
    this.cellPadding = 115,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
    this.borderInsideH,
    this.borderInsideV,
  });

  /// Simple grid style with borders.
  static const grid = DocxTableStyle();

  /// No borders, clean look.
  static const plain = DocxTableStyle(border: DocxBorder.none);

  /// Header highlighted with gray background.
  static const headerHighlight = DocxTableStyle(headerFill: 'E0E0E0');

  /// Zebra striping for readability.
  static const zebra = DocxTableStyle(
    headerFill: 'E0E0E0',
    evenRowFill: 'F5F5F5',
  );

  /// Professional blue header.
  static const professional = DocxTableStyle(
    headerFill: '4472C4',
    borderColor: '4472C4',
  );
}

/// A table element in the document.
class DocxTable extends DocxBlock {
  /// Table rows.
  final List<DocxTableRow> rows;

  /// Table styling.
  final DocxTableStyle style;

  /// Table width value.
  final int? width;

  /// Table width type.
  final DocxWidthType widthType;

  /// Whether first row is a header.
  final bool hasHeader;

  const DocxTable({
    required this.rows,
    this.style = const DocxTableStyle(),
    this.width,
    this.widthType = DocxWidthType.auto,
    this.hasHeader = true,
    super.id,
  });

  /// Creates a table from a 2D list of strings.
  factory DocxTable.fromData(
    List<List<String>> data, {
    bool hasHeader = true,
    DocxTableStyle style = const DocxTableStyle(),
  }) {
    final rows = <DocxTableRow>[];
    for (int i = 0; i < data.length; i++) {
      final isHeader = hasHeader && i == 0;
      final isEven = i % 2 == 0;

      String? rowFill;
      if (isHeader && style.headerFill != null) {
        rowFill = style.headerFill;
      } else if (!isHeader) {
        rowFill = isEven ? style.evenRowFill : style.oddRowFill;
      }

      final cells = data[i]
          .map(
            (text) => DocxTableCell.text(
              text,
              isBold: isHeader,
              shadingFill: rowFill,
            ),
          )
          .toList();
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows, style: style, hasHeader: hasHeader);
  }

  DocxTable copyWith({
    List<DocxTableRow>? rows,
    DocxTableStyle? style,
    int? width,
    DocxWidthType? widthType,
    bool? hasHeader,
  }) {
    return DocxTable(
      rows: rows ?? this.rows,
      style: style ?? this.style,
      width: width ?? this.width,
      widthType: widthType ?? this.widthType,
      hasHeader: hasHeader ?? this.hasHeader,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTable(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:tbl',
      nest: () {
        // Table properties
        builder.element(
          'w:tblPr',
          nest: () {
            builder.element(
              'w:tblStyle',
              nest: () {
                builder.attribute('w:val', 'TableGrid');
              },
            );
            builder.element(
              'w:tblW',
              nest: () {
                builder.attribute('w:w', (width ?? 0).toString());
                builder.attribute('w:type', widthType.name);
              },
            );
            // Borders
            builder.element(
              'w:tblBorders',
              nest: () {
                // If specific side is provided, use it. Otherwise fall back to global border settings if not none.

                // Helper to resolve border
                void buildSide(String tag, DocxBorderSide? side) {
                  if (side != null) {
                    builder.element(tag, nest: () {
                      builder.attribute('w:val', side.style.xmlValue);
                      builder.attribute('w:sz', side.size.toString());
                      builder.attribute('w:space', side.space.toString());
                      builder.attribute('w:color', side.color.hex);
                    });
                  } else if (style.border != DocxBorder.none) {
                    // Fallback to global style
                    _buildBorder(builder, tag);
                  }
                }

                buildSide('w:top', style.borderTop);
                buildSide('w:bottom', style.borderBottom);
                buildSide('w:left', style.borderLeft);
                buildSide('w:right', style.borderRight);
                buildSide('w:insideH', style.borderInsideH);
                buildSide('w:insideV', style.borderInsideV);
              },
            );
            // Cell margins/padding
            builder.element(
              'w:tblCellMar',
              nest: () {
                builder.element(
                  'w:top',
                  nest: () {
                    builder.attribute('w:w', style.cellPadding.toString());
                    builder.attribute('w:type', 'dxa');
                  },
                );
                builder.element(
                  'w:left',
                  nest: () {
                    builder.attribute('w:w', style.cellPadding.toString());
                    builder.attribute('w:type', 'dxa');
                  },
                );
                builder.element(
                  'w:bottom',
                  nest: () {
                    builder.attribute('w:w', style.cellPadding.toString());
                    builder.attribute('w:type', 'dxa');
                  },
                );
                builder.element(
                  'w:right',
                  nest: () {
                    builder.attribute('w:w', style.cellPadding.toString());
                    builder.attribute('w:type', 'dxa');
                  },
                );
              },
            );
          },
        );
        builder.element('w:tblGrid');

        // Rows
        for (int i = 0; i < rows.length; i++) {
          rows[i].buildXmlWithStyle(
            builder,
            style,
            isHeader: hasHeader && i == 0,
            isEven: i % 2 == 0,
          );
        }
      },
    );
  }

  void _buildBorder(XmlBuilder builder, String tag) {
    builder.element(
      tag,
      nest: () {
        builder.attribute('w:val', style.border.xmlValue);
        builder.attribute('w:sz', style.borderWidth.toString());
        builder.attribute('w:space', '0');
        builder.attribute('w:color', style.borderColor);
      },
    );
  }
}

/// A row within a [DocxTable].
class DocxTableRow extends DocxNode {
  /// Cells in this row.
  final List<DocxTableCell> cells;

  /// Row height in twips (null = auto).
  final int? height;

  const DocxTableRow({required this.cells, this.height, super.id});

  DocxTableRow copyWith({
    List<DocxTableCell>? cells,
    int? height,
  }) {
    return DocxTableRow(
      cells: cells ?? this.cells,
      height: height ?? this.height,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTableRow(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    buildXmlWithStyle(
      builder,
      const DocxTableStyle(),
      isHeader: false,
      isEven: false,
    );
  }

  void buildXmlWithStyle(
    XmlBuilder builder,
    DocxTableStyle style, {
    required bool isHeader,
    required bool isEven,
  }) {
    builder.element(
      'w:tr',
      nest: () {
        if (height != null) {
          builder.element(
            'w:trPr',
            nest: () {
              builder.element(
                'w:trHeight',
                nest: () {
                  builder.attribute('w:val', height.toString());
                },
              );
            },
          );
        }
        for (var cell in cells) {
          cell.buildXml(builder);
        }
      },
    );
  }
}

/// A cell within a [DocxTableRow].
class DocxTableCell extends DocxNode {
  /// Block content in this cell.
  final List<DocxBlock> children;

  /// Column span (merge cells horizontally).
  final int colSpan;

  /// Row span (merge cells vertically).
  final int rowSpan;

  /// Vertical alignment within the cell.
  final DocxVerticalAlign verticalAlign;

  /// Background shading color hex.
  final String? shadingFill;

  /// Cell width in twips.
  final int? width;

  // Borders
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;

  // Margins
  final int? marginLeft;
  final int? marginRight;

  const DocxTableCell({
    this.children = const [],
    this.colSpan = 1,
    this.rowSpan = 1,
    this.verticalAlign = DocxVerticalAlign.center,
    this.shadingFill,
    this.width,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
    this.marginLeft,
    this.marginRight,
    super.id,
  });

  /// Creates a cell with simple text content.
  factory DocxTableCell.text(
    String text, {
    bool isBold = false,
    DocxAlign align = DocxAlign.left,
    DocxVerticalAlign verticalAlign = DocxVerticalAlign.center,
    String? shadingFill,
  }) {
    return DocxTableCell(
      verticalAlign: verticalAlign,
      shadingFill: shadingFill,
      children: [
        DocxParagraph(
          align: align,
          children: [isBold ? DocxText.bold(text) : DocxText(text)],
        ),
      ],
    );
  }

  /// Creates a cell with rich content.
  factory DocxTableCell.rich(List<DocxInline> content, {String? shadingFill}) {
    return DocxTableCell(
      shadingFill: shadingFill,
      children: [DocxParagraph(children: content)],
    );
  }

  DocxTableCell copyWith({
    List<DocxBlock>? children,
    int? colSpan,
    int? rowSpan,
    DocxVerticalAlign? verticalAlign,
    String? shadingFill,
    int? width,
  }) {
    return DocxTableCell(
      children: children ?? this.children,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      width: width ?? this.width,
      borderTop: borderTop ?? borderTop,
      borderBottom: borderBottom ?? borderBottom,
      borderLeft: borderLeft ?? borderLeft,
      borderRight: borderRight ?? borderRight,
      marginLeft: marginLeft ?? marginLeft,
      marginRight: marginRight ?? marginRight,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTableCell(this);
  }

  void _buildBorder(XmlBuilder builder, String tag, DocxBorderSide side) {
    builder.element(tag, nest: () {
      builder.attribute('w:val', side.style.xmlValue);
      builder.attribute('w:sz', side.size.toString());
      builder.attribute('w:space', side.space.toString());
      builder.attribute('w:color', side.color.hex);
    });
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:tc',
      nest: () {
        // Cell properties
        builder.element(
          'w:tcPr',
          nest: () {
            if (width != null) {
              builder.element(
                'w:tcW',
                nest: () {
                  builder.attribute('w:w', width.toString());
                  builder.attribute('w:type', 'dxa');
                },
              );
            }
            if (colSpan > 1) {
              builder.element(
                'w:gridSpan',
                nest: () {
                  builder.attribute('w:val', colSpan.toString());
                },
              );
            }
            if (rowSpan > 1) {
              builder.element(
                'w:vMerge',
                nest: () {
                  builder.attribute('w:val', 'restart');
                },
              );
            }
            builder.element(
              'w:vAlign',
              nest: () {
                builder.attribute('w:val', verticalAlign.name);
              },
            );
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
            // Borders
            if (borderTop != null ||
                borderBottom != null ||
                borderLeft != null ||
                borderRight != null) {
              builder.element('w:tcBorders', nest: () {
                if (borderTop != null)
                  _buildBorder(builder, 'w:top', borderTop!);
                if (borderBottom != null)
                  _buildBorder(builder, 'w:bottom', borderBottom!);
                if (borderLeft != null)
                  _buildBorder(builder, 'w:left', borderLeft!);
                if (borderRight != null)
                  _buildBorder(builder, 'w:right', borderRight!);
              });
            }
          },
        );

        // Content
        if (children.isEmpty) {
          builder.element('w:p');
        } else {
          for (var child in children) {
            child.buildXml(builder);
          }
        }
      },
    );
  }
}
