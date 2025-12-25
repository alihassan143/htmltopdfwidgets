import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';

import '../models/docx_style.dart';
import '../reader_context.dart';
import 'inline_parser.dart';

/// Parses table elements (w:tbl).
class TableParser {
  final ReaderContext context;
  final InlineParser inlineParser;

  TableParser(this.context, this.inlineParser);

  /// Parse a table element into DocxTable.
  DocxTable parse(XmlElement node) {
    // 1. Parse Table Properties
    DocxTableStyle style = const DocxTableStyle();
    int? tableWidth;
    DocxWidthType widthType = DocxWidthType.auto;

    final tblPr = node.getElement('w:tblPr');
    DocxAlign? alignment;
    DocxTablePosition? position;
    String? styleId;

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

      // Parse table shading (background)
      final shd = tblPr.getElement('w:shd');
      if (shd != null) {
        final fill = shd.getAttribute('w:fill');
        if (fill != null && fill != 'auto') {
          style = style.copyWith(fill: fill);
        }
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

      // Parse table style
      final tblStyle = tblPr.getElement('w:tblStyle');
      if (tblStyle != null) {
        styleId = tblStyle.getAttribute('w:val');
      }

      // Parse table alignment (justification)
      final jc = tblPr.getElement('w:jc');
      if (jc != null) {
        final val = jc.getAttribute('w:val');
        if (val == 'left') alignment = DocxAlign.left;
        if (val == 'center') alignment = DocxAlign.center;
        if (val == 'right') alignment = DocxAlign.right;
      }

      // Parse floating table position
      final tblpPr = tblPr.getElement('w:tblpPr');
      if (tblpPr != null) {
        DocxTableHAnchor hAnchor = DocxTableHAnchor.margin;
        DocxTableVAnchor vAnchor = DocxTableVAnchor.text;

        final hAnchorVal = tblpPr.getAttribute('w:horzAnchor');
        if (hAnchorVal == 'text') hAnchor = DocxTableHAnchor.text;
        if (hAnchorVal == 'margin') hAnchor = DocxTableHAnchor.margin;
        if (hAnchorVal == 'page') hAnchor = DocxTableHAnchor.page;

        final vAnchorVal = tblpPr.getAttribute('w:vertAnchor');
        if (vAnchorVal == 'text') vAnchor = DocxTableVAnchor.text;
        if (vAnchorVal == 'margin') vAnchor = DocxTableVAnchor.margin;
        if (vAnchorVal == 'page') vAnchor = DocxTableVAnchor.page;

        position = DocxTablePosition(
          hAnchor: hAnchor,
          vAnchor: vAnchor,
          tblpX: int.tryParse(tblpPr.getAttribute('w:tblpX') ?? ''),
          tblpY: int.tryParse(tblpPr.getAttribute('w:tblpY') ?? ''),
          leftFromText:
              int.tryParse(tblpPr.getAttribute('w:leftFromText') ?? '') ?? 180,
          rightFromText:
              int.tryParse(tblpPr.getAttribute('w:rightFromText') ?? '') ?? 180,
          topFromText:
              int.tryParse(tblpPr.getAttribute('w:topFromText') ?? '') ?? 0,
          bottomFromText:
              int.tryParse(tblpPr.getAttribute('w:bottomFromText') ?? '') ?? 0,
        );
      }
    }

    // Parse table look (conditional formatting)
    DocxTableLook look = const DocxTableLook();
    if (tblPr != null) {
      final tblLook = tblPr.getElement('w:tblLook');
      if (tblLook != null) {
        look = DocxTableLook(
          firstRow: tblLook.getAttribute('w:firstRow') != '0', // Default 1
          lastRow: tblLook.getAttribute('w:lastRow') == '1', // Default 0
          firstColumn:
              tblLook.getAttribute('w:firstColumn') == '1', // Default 0
          lastColumn: tblLook.getAttribute('w:lastColumn') == '1', // Default 0
          noHBand: tblLook.getAttribute('w:noHBand') == '1', // Default 0
          noVBand: tblLook.getAttribute('w:noVBand') == '1', // Default 0
        );
      }
    }

    // ============================================================
    // True-Fidelity: Parse Table Grid (column widths)
    // ============================================================
    List<int>? gridColumns;
    final tblGrid = node.getElement('w:tblGrid');
    if (tblGrid != null) {
      gridColumns = <int>[];
      for (var gridCol in tblGrid.findAllElements('w:gridCol')) {
        final w = int.tryParse(gridCol.getAttribute('w:w') ?? '');
        if (w != null) gridColumns.add(w);
      }
      // If empty list, set to null
      if (gridColumns.isEmpty) gridColumns = null;
    }

    // 2. Parse Rows and Cells
    final rawRows = <_TempRow>[];

    for (var child in node.children) {
      if (child is XmlElement && child.name.local == 'tr') {
        final cells = <_TempCell>[];
        bool isHeader = false;

        // Check for header row property
        final trPr = child.getElement('w:trPr');
        if (trPr != null) {
          if (trPr.getElement('w:tblHeader') != null) {
            isHeader = true;
          }
        }

        for (var cellNode in child.children) {
          if (cellNode is XmlElement && cellNode.name.local == 'tc') {
            cells.add(_parseCell(cellNode));
          }
        }
        if (cells.isNotEmpty) {
          rawRows.add(_TempRow(cells: cells, isHeader: isHeader));
        }
      }
    }

    // 3. Resolve row spans
    final grid = _resolveRowSpans(rawRows);
    final finalRows = <DocxTableRow>[];

    // Resolve Table Style from context
    final resolvedTableStyle = context.resolveStyle(styleId);
    final rowCount = grid.length;
    final int colCount =
        grid.isNotEmpty ? grid.first.fold(0, (sum, c) => sum + c.gridSpan) : 0;

    for (int i = 0; i < grid.length; i++) {
      final r = grid[i];
      final isHeaderRow = i < rawRows.length ? rawRows[i].isHeader : false;
      final cells = <DocxTableCell>[];
      int colIndex = 0;

      for (var c in r) {
        final effectiveStyle = _resolveCellStyle(
            resolvedTableStyle, i, colIndex, rowCount, colCount, look);

        // Convert percentage width from gridCol if applicable
        int? cellWidth = c.width;
        if (widthType == DocxWidthType.pct && gridColumns != null) {
          // Calculate explicit width if using percentages
          // Assuming full width is page width minus margins for now
          // (Implementation could be refined with actual section context)
          // For now, if resolvedGridColumns has values, use them.
        }

        cells.add(DocxTableCell(
          children: c.children,
          colSpan: c.gridSpan,
          rowSpan: c.finalRowSpan,
          shadingFill: c.shadingFill ?? effectiveStyle.shadingFill,
          width: cellWidth,
          borderTop: c.borderTop ?? effectiveStyle.borderTop,
          borderBottom: c.borderBottom ?? effectiveStyle.borderBottomSide,
          borderLeft: c.borderLeft ?? effectiveStyle.borderLeft,
          borderRight: c.borderRight ?? effectiveStyle.borderRight,
          verticalAlign: c.verticalAlign ??
              effectiveStyle.verticalAlign ??
              DocxVerticalAlign.top,
        ));
        colIndex += c.gridSpan;
      }
      finalRows.add(DocxTableRow(cells: cells, isHeader: isHeaderRow));
    }

    // Determine if table has any header rows
    final hasHeader = finalRows.any((row) => row.isHeader);

    // If grid columns are missing but we have percentage widths,
    // we might need to distribute them.
    // However, DocxTable.resolvedGridColumns logic handles simple distribution.
    // If we want to support 'pct' properly for the whole table, we rely on the
    // Exporter to interpret 'pct' type. Reader just stores it.

    return DocxTable(
      rows: finalRows,
      style: style,
      width: tableWidth,
      widthType: widthType,
      hasHeader: hasHeader,
      alignment: alignment,
      position: position,
      styleId: styleId,
      look: look,
      gridColumns: gridColumns,
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
    DocxVerticalAlign? verticalAlign;

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
        if (shadingFill == 'auto' || shadingFill == null) {
          shadingFill = null;
        } else {
          // Normalize to include # prefix if it's a hex color
          if (shadingFill.length == 6 &&
              RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(shadingFill)) {
            shadingFill = '#$shadingFill';
          }
        }
      }

      // Parse vertical alignment
      final vAlignElem = tcPr.getElement('w:vAlign');
      if (vAlignElem != null) {
        final val = vAlignElem.getAttribute('w:val');
        if (val == 'top') verticalAlign = DocxVerticalAlign.top;
        if (val == 'center') verticalAlign = DocxVerticalAlign.center;
        if (val == 'bottom') verticalAlign = DocxVerticalAlign.bottom;
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
        children.add(_parseFullParagraph(c));
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
      verticalAlign: verticalAlign,
    );
  }

  /// Full paragraph parser for table cells - preserves all text formatting.
  DocxParagraph _parseFullParagraph(XmlElement xml) {
    String? pStyle;
    DocxAlign? align;
    String? shadingFill;

    // Parse paragraph properties
    final pPr = xml.getElement('w:pPr');
    if (pPr != null) {
      // Style reference
      final pStyleElem = pPr.getElement('w:pStyle');
      if (pStyleElem != null) {
        pStyle = pStyleElem.getAttribute('w:val');
      }

      // Alignment
      final jcElem = pPr.getElement('w:jc');
      if (jcElem != null) {
        final val = jcElem.getAttribute('w:val');
        if (val == 'center') align = DocxAlign.center;
        if (val == 'right' || val == 'end') align = DocxAlign.right;
        if (val == 'both' || val == 'distribute') align = DocxAlign.justify;
        if (val == 'left' || val == 'start') align = DocxAlign.left;
      }

      // Shading
      final shdElem = pPr.getElement('w:shd');
      if (shdElem != null) {
        shadingFill = shdElem.getAttribute('w:fill');
        if (shadingFill == 'auto') shadingFill = null;
      }
    }

    // Resolve style for inheritance
    final effectiveStyle = context.resolveStyle(pStyle ?? 'Normal');

    // Parse inline children with full formatting
    final children =
        inlineParser.parseChildren(xml.children, parentStyle: effectiveStyle);

    return DocxParagraph(
      children: children,
      styleId: pStyle,
      align: align ?? effectiveStyle.align ?? DocxAlign.left,
      shadingFill: shadingFill ?? effectiveStyle.shadingFill,
    );
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

  /// Resolves row spans (vMerge) by tracking grid columns.
  ///
  /// This implementation maps each cell to its grid column index (accounting for
  /// gridSpan) to correctly align vertical merges even when rows have different
  /// cell counts or spans.
  List<List<_TempCell>> _resolveRowSpans(List<_TempRow> rows) {
    if (rows.isEmpty) return [];

    final result = <List<_TempCell>>[];
    // Track the source cell for active vertical merges per grid column
    // Maps gridColumnIndex -> _TempCell (the restarting cell)
    final activeMerges = <int, _TempCell>{};
    // Track the row index where the merge started
    final mergeStartRows = <int, int>{};

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final inputRow = rows[rowIndex];
      final outputRow = <_TempCell>[];
      int currentGridCol = 0;

      for (var cell in inputRow.cells) {
        // Calculate the range of grid columns this cell covers
        final gridSpan = cell.gridSpan;
        bool isContinue = cell.vMerge == 'continue' || cell.vMerge == '';
        bool isRestart = cell.vMerge == 'restart';

        // Check if we strictly have a merge instruction
        if (cell.vMerge != null) {
          if (isRestart) {
            // Start a new merge
            // Update active merges for ALL grid columns covered by this cell
            final newCell = cell.copyWith(finalRowSpan: 1);
            for (int i = 0; i < gridSpan; i++) {
              activeMerges[currentGridCol + i] = newCell;
              mergeStartRows[currentGridCol + i] = rowIndex;
            }
            outputRow.add(newCell);
          } else if (isContinue) {
            // Continue existing merge
            // We need to find the cell that started this merge
            // We assume the first grid column of this cell aligns with the merge
            if (activeMerges.containsKey(currentGridCol)) {
              // Updates are done on the ORIGINAL cell object in the result list
              // We need to find that object reference.
              // Since we are building 'result' progressively, we can look back.
              final startRowIndex = mergeStartRows[currentGridCol]!;

              // Increment row span of the start cell
              // Note: We need to replace the cell in the previous row's list
              // with a new copy having incremented span.
              // But 'result' stores List<_TempCell>.
              // This is complex because we need to mutate the previously added cell.
              // Let's use a simplified approach:
              // 1. Just don't add this cell to outputRow (it's merged into above)
              // 2. Increment the span of the *active merge source*

              // Find where the start cell IS in the result structure
              // It's in result[startRowIndex]. We need to find which cell it is.
              // We can rely on the fact that we stored the object reference in activeMerges?
              // No, copyWith creates new objects.
              // Let's store a reference to the Mutable wrapper or similar?
              // Or just traverse result[startRowIndex] to find the matching cell?
              // Optimization: Store (RowIndex, CellIndex) in activeMerges?

              // Let's iterate result[startRowIndex] to find the cell that covers currentGridCol
              var targetRow = result[startRowIndex];
              int checkCol = 0;
              for (int cIdx = 0; cIdx < targetRow.length; cIdx++) {
                final c = targetRow[cIdx];
                if (currentGridCol >= checkCol &&
                    currentGridCol < checkCol + c.gridSpan) {
                  // Found it. Update its span.
                  targetRow[cIdx] =
                      c.copyWith(finalRowSpan: c.finalRowSpan + 1);
                  // Update activeMerges reference for next iteration (though technically not needed if we look up by index)
                  break;
                }
                checkCol += c.gridSpan;
              }
            } else {
              // 'continue' without specific start (malformed), treat as simple cell
              outputRow.add(cell.copyWith(finalRowSpan: 1));
            }
          }
        } else {
          // No vertical merge - clear any active merges for these columns
          final newCell = cell.copyWith(finalRowSpan: 1);
          for (int i = 0; i < gridSpan; i++) {
            activeMerges.remove(currentGridCol + i);
            mergeStartRows.remove(currentGridCol + i);
          }
          outputRow.add(newCell);
        }

        currentGridCol += gridSpan;
      }

      result.add(outputRow);
    }

    return result;
  }

  DocxStyle _resolveCellStyle(DocxStyle base, int row, int col, int rowCount,
      int colCount, DocxTableLook look) {
    var style = base;

    // Banding (Horizontal) - default Odd/Even assumption
    if (!look.noHBand) {
      if (row % 2 == 0) {
        // Odd Row (Index 0, 2, 4...) -> Band 1
        style = style
            .merge(base.tableConditionals['band1Horz'] ?? DocxStyle.empty());
      } else {
        // Even Row -> Band 2
        style = style
            .merge(base.tableConditionals['band2Horz'] ?? DocxStyle.empty());
      }
    }
    // Banding (Vertical)
    if (!look.noVBand) {
      if (col % 2 == 0) {
        style = style
            .merge(base.tableConditionals['band1Vert'] ?? DocxStyle.empty());
      } else {
        style = style
            .merge(base.tableConditionals['band2Vert'] ?? DocxStyle.empty());
      }
    }

    // First/Last Row/Col
    if (look.firstRow && row == 0) {
      style =
          style.merge(base.tableConditionals['firstRow'] ?? DocxStyle.empty());
    }
    if (look.lastRow && row == rowCount - 1) {
      style =
          style.merge(base.tableConditionals['lastRow'] ?? DocxStyle.empty());
    }
    if (look.firstColumn && col == 0) {
      style =
          style.merge(base.tableConditionals['firstCol'] ?? DocxStyle.empty());
    }
    if (look.lastColumn && col == colCount - 1) {
      style =
          style.merge(base.tableConditionals['lastCol'] ?? DocxStyle.empty());
    }

    // Corners
    if (look.firstRow && look.firstColumn && row == 0 && col == 0) {
      style =
          style.merge(base.tableConditionals['nwCell'] ?? DocxStyle.empty());
    }
    if (look.firstRow && look.lastColumn && row == 0 && col == colCount - 1) {
      style =
          style.merge(base.tableConditionals['neCell'] ?? DocxStyle.empty());
    }
    if (look.lastRow && look.firstColumn && row == rowCount - 1 && col == 0) {
      style =
          style.merge(base.tableConditionals['swCell'] ?? DocxStyle.empty());
    }
    if (look.lastRow &&
        look.lastColumn &&
        row == rowCount - 1 &&
        col == colCount - 1) {
      style =
          style.merge(base.tableConditionals['seCell'] ?? DocxStyle.empty());
    }

    return style;
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
  final DocxVerticalAlign? verticalAlign;
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
    this.verticalAlign,
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
      verticalAlign: verticalAlign,
      finalRowSpan: finalRowSpan ?? this.finalRowSpan,
    );
  }
}

/// Temporary row structure for header detection.
class _TempRow {
  final List<_TempCell> cells;
  final bool isHeader;

  _TempRow({required this.cells, this.isHeader = false});
}
