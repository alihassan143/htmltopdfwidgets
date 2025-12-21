import 'package:xml/xml.dart';

import '../../../docx_creator.dart';
import '../reader_context.dart';

/// Parses table elements (w:tbl).
class TableParser {
  final ReaderContext context;

  TableParser(this.context);

  /// Parse a table element into DocxTable.
  DocxTable parse(XmlElement node) {
    // 1. Parse Table Properties
    DocxTableStyle style = const DocxTableStyle();
    int? tableWidth;
    DocxWidthType widthType = DocxWidthType.auto;

    final tblPr = node.getElement('w:tblPr');
    if (tblPr != null) {
      final tblBorders = tblPr.getElement('w:tblBorders');
      if (tblBorders != null) {
        style = DocxTableStyle(
          borderTop: _parseBorderSide(tblBorders.getElement('w:top')),
          borderBottom: _parseBorderSide(tblBorders.getElement('w:bottom')),
          borderLeft: _parseBorderSide(tblBorders.getElement('w:left')),
          borderRight: _parseBorderSide(tblBorders.getElement('w:right')),
          borderInsideH: _parseBorderSide(tblBorders.getElement('w:insideH')),
          borderInsideV: _parseBorderSide(tblBorders.getElement('w:insideV')),
        );
      }

      final tblW = tblPr.getElement('w:tblW');
      if (tblW != null) {
        final w = int.tryParse(tblW.getAttribute('w:w') ?? '');
        final type = tblW.getAttribute('w:type');
        if (w != null) tableWidth = w;
        if (type == 'dxa') widthType = DocxWidthType.dxa;
        if (type == 'pct') widthType = DocxWidthType.pct;
        if (type == 'auto') widthType = DocxWidthType.auto;
      }
    }

    // 2. Parse Rows and Cells
    final rawRows = <List<_TempCell>>[];

    for (var child in node.children) {
      if (child is XmlElement && child.name.local == 'tr') {
        final row = <_TempCell>[];
        for (var cellNode in child.children) {
          if (cellNode is XmlElement && cellNode.name.local == 'tc') {
            row.add(_parseCell(cellNode));
          }
        }
        if (row.isNotEmpty) rawRows.add(row);
      }
    }

    // 3. Resolve row spans
    final grid = _resolveRowSpans(rawRows);
    final finalRows = <DocxTableRow>[];

    for (var r in grid) {
      final cells = r
          .map((c) => DocxTableCell(
                children: c.children,
                colSpan: c.gridSpan,
                rowSpan: c.finalRowSpan,
                shadingFill: c.shadingFill,
                width: c.width,
                borderTop: c.borderTop,
                borderBottom: c.borderBottom,
                borderLeft: c.borderLeft,
                borderRight: c.borderRight,
              ))
          .toList();
      finalRows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(
      rows: finalRows,
      style: style,
      width: tableWidth,
      widthType: widthType,
    );
  }

  _TempCell _parseCell(XmlElement cellNode) {
    final tcPr = cellNode.getElement('w:tcPr');
    int gridSpan = 1;
    String? vMergeVal;
    String? shadingFill;
    int? cellWidth;
    DocxBorderSide? borderTop;
    DocxBorderSide? borderBottom;
    DocxBorderSide? borderLeft;
    DocxBorderSide? borderRight;

    if (tcPr != null) {
      final gs = tcPr.getElement('w:gridSpan');
      if (gs != null) {
        gridSpan = int.tryParse(gs.getAttribute('w:val') ?? '1') ?? 1;
      }

      final vm = tcPr.getElement('w:vMerge');
      if (vm != null) {
        vMergeVal = vm.getAttribute('w:val') ?? 'continue';
      }

      final shd = tcPr.getElement('w:shd');
      if (shd != null) {
        shadingFill = shd.getAttribute('w:fill');
        if (shadingFill == 'auto') shadingFill = null;
      }

      final tcW = tcPr.getElement('w:tcW');
      if (tcW != null) {
        cellWidth = int.tryParse(tcW.getAttribute('w:w') ?? '');
      }

      final tcBorders = tcPr.getElement('w:tcBorders');
      if (tcBorders != null) {
        borderTop = _parseBorderSide(tcBorders.getElement('w:top'));
        borderBottom = _parseBorderSide(tcBorders.getElement('w:bottom'));
        borderLeft = _parseBorderSide(tcBorders.getElement('w:left'));
        borderRight = _parseBorderSide(tcBorders.getElement('w:right'));
      }
    }

    // Parse cell children (paragraphs, nested tables)
    final children = <DocxBlock>[];
    for (var c in cellNode.children) {
      if (c is XmlElement && c.name.local == 'p') {
        children.add(_parseSimpleParagraph(c));
      } else if (c is XmlElement && c.name.local == 'tbl') {
        children.add(parse(c)); // Recursive for nested tables
      }
    }

    return _TempCell(
      children: children,
      gridSpan: gridSpan,
      vMerge: vMergeVal,
      shadingFill: shadingFill,
      width: cellWidth,
      borderTop: borderTop,
      borderBottom: borderBottom,
      borderLeft: borderLeft,
      borderRight: borderRight,
    );
  }

  /// Simplified paragraph parser for table cells.
  DocxParagraph _parseSimpleParagraph(XmlElement xml) {
    final children = <DocxInline>[];
    for (var child in xml.children) {
      if (child is XmlElement && child.name.local == 'r') {
        final textElem = child.getElement('w:t');
        if (textElem != null) {
          children.add(DocxText(textElem.innerText));
        }
      }
    }
    return DocxParagraph(children: children);
  }

  DocxBorderSide? _parseBorderSide(XmlElement? borderElem) {
    if (borderElem == null) return null;
    final val = borderElem.getAttribute('w:val');
    if (val == null || val == 'none' || val == 'nil') return null;

    int size = 4;
    final szAttr = borderElem.getAttribute('w:sz');
    if (szAttr != null) {
      final s = int.tryParse(szAttr);
      if (s != null) size = s;
    }

    var color = DocxColor.black;
    final colorAttr = borderElem.getAttribute('w:color');
    if (colorAttr != null && colorAttr != 'auto') {
      color = DocxColor(colorAttr);
    }

    var style = DocxBorder.single;
    for (var b in DocxBorder.values) {
      if (b.xmlValue == val) {
        style = b;
        break;
      }
    }

    return DocxBorderSide(style: style, size: size, color: color);
  }

  List<List<_TempCell>> _resolveRowSpans(List<List<_TempCell>> rawRows) {
    if (rawRows.isEmpty) return [];

    final numRows = rawRows.length;
    final result = <List<_TempCell>>[];

    for (int ri = 0; ri < numRows; ri++) {
      final row = rawRows[ri];
      final resolvedRow = <_TempCell>[];

      for (int ci = 0; ci < row.length; ci++) {
        final cell = row[ci];
        if (cell.vMerge == 'restart') {
          // Count how many rows this cell spans
          int span = 1;
          for (int nextRi = ri + 1; nextRi < numRows; nextRi++) {
            final nextRow = rawRows[nextRi];
            if (ci < nextRow.length) {
              final nextCell = nextRow[ci];
              if (nextCell.vMerge == 'continue' || nextCell.vMerge == '') {
                span++;
              } else {
                break;
              }
            } else {
              break;
            }
          }
          resolvedRow.add(cell.copyWith(finalRowSpan: span));
        } else if (cell.vMerge == 'continue' || cell.vMerge == '') {
          // Skip - merged into previous row
        } else {
          resolvedRow.add(cell.copyWith(finalRowSpan: 1));
        }
      }

      result.add(resolvedRow);
    }

    return result;
  }
}

/// Temporary cell structure for row span resolution.
class _TempCell {
  final List<DocxBlock> children;
  final int gridSpan;
  final String? vMerge;
  final String? shadingFill;
  final int? width;
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
  final int finalRowSpan;

  _TempCell({
    required this.children,
    this.gridSpan = 1,
    this.vMerge,
    this.shadingFill,
    this.width,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
    this.finalRowSpan = 1,
  });

  _TempCell copyWith({int? finalRowSpan}) {
    return _TempCell(
      children: children,
      gridSpan: gridSpan,
      vMerge: vMerge,
      shadingFill: shadingFill,
      width: width,
      borderTop: borderTop,
      borderBottom: borderBottom,
      borderLeft: borderLeft,
      borderRight: borderRight,
      finalRowSpan: finalRowSpan ?? this.finalRowSpan,
    );
  }
}
