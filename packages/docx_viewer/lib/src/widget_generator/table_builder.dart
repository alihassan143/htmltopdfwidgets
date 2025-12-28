import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxTable] elements using native layout.
class TableBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final DocxTheme? docxTheme;

  // Constants
  static const double _twipsToPx = 1 / 15.0;

  TableBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    this.docxTheme,
  });

  /// Build a widget from a [DocxTable].
  Widget build(DocxTable table) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // 1. Resolve Grid Columns (Widths)
    final gridCols = table.resolvedGridColumns;
    List<double> colWidths = [];

    if (gridCols.isNotEmpty) {
      colWidths = gridCols.map((w) => w * _twipsToPx).toList();
    } else {
      // Fallback: If no grid, distribute evenly based on first row
      final firstRowCells = table.rows.first.cells.length;
      if (firstRowCells > 0) {
        // Assume page width 800 roughly, just for fallback
        final w = 800.0 / firstRowCells;
        colWidths = List.filled(firstRowCells, w);
      }
    }

    // Initialize skip counts for vertical merges
    final skipCounts = List<int>.filled(colWidths.length, 0);

    // 2. Build Rows with table-level context
    final rowWidgets = <Widget>[];
    for (int r = 0; r < table.rows.length; r++) {
      rowWidgets.add(_buildRow(
        table.rows[r],
        colWidths,
        skipCounts,
        table: table,
        rowIndex: r,
        totalRows: table.rows.length,
      ));
    }

    // 3. Build table content
    Widget tableContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowWidgets,
    );

    // Apply Table-level background if exists
    final tableFill = _resolveColor(table.style.fill, null, null, null);
    if (tableFill != null) {
      tableContent = DecoratedBox(
          decoration: BoxDecoration(
            color: tableFill,
          ),
          child: tableContent);
    }

    // Wrap in horizontal scroll for overflow protection
    Widget scrollableTable = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: tableContent,
      ),
    );

    // Handle Table Alignment
    if (table.alignment == DocxAlign.center) {
      return Center(child: scrollableTable);
    } else if (table.alignment == DocxAlign.right) {
      return Align(alignment: Alignment.centerRight, child: scrollableTable);
    }

    return scrollableTable;
  }

  Widget _buildRow(
    DocxTableRow row,
    List<double> colWidths,
    List<int> skipCounts, {
    required DocxTable table,
    required int rowIndex,
    required int totalRows,
  }) {
    final cells = <Widget>[];
    final style = table.style;
    final look = table.look;
    final totalColumns = colWidths.length;

    // Determine row-level conditions
    final isHeaderRow = rowIndex == 0 && table.hasHeader && look.firstRow;
    final isLastRow = rowIndex == totalRows - 1 && look.lastRow;

    // Determine row-level background based on styling
    Color? rowBackground;

    if (isHeaderRow && style.headerFill != null) {
      rowBackground = _resolveColor(style.headerFill, null, null, null);
    }

    // Row banding (alternating colors) if not header and banding is enabled
    if (rowBackground == null && !isHeaderRow && !look.noHBand) {
      final isEvenRow = rowIndex.isEven;
      if (isEvenRow && style.evenRowFill != null) {
        rowBackground = _resolveColor(style.evenRowFill, null, null, null);
      } else if (!isEvenRow && style.oddRowFill != null) {
        rowBackground = _resolveColor(style.oddRowFill, null, null, null);
      }
    }

    int gridIndex = 0;
    int cellIndex = 0; // Index in row.cells

    while (gridIndex < colWidths.length) {
      // Determine column conditions
      final isFirstColumn = gridIndex == 0 && look.firstColumn;
      final isLastColumn = gridIndex >= totalColumns - 1 && look.lastColumn;

      if (skipCounts[gridIndex] > 0) {
        // --- CONTINUED CELL (Merged Placeholder) ---
        skipCounts[gridIndex]--;
        final remainingSkips = skipCounts[gridIndex];

        double width = colWidths[gridIndex];
        bool isLastRowOfMerge = remainingSkips == 0;

        cells.add(_buildCell(
          null, // No content
          width,
          drawTop: false,
          drawBottom: isLastRowOfMerge,
          isEmpty: true,
          tableStyle: style,
          tableLook: look,
          rowBackground: rowBackground,
          isHeaderRow: isHeaderRow,
          isLastRow: isLastRow,
          isFirstColumn: isFirstColumn,
          isLastColumn: isLastColumn,
          isFirstRowActual: rowIndex == 0,
          isLastRowActual: rowIndex == totalRows - 1,
          isFirstColumnActual: gridIndex == 0,
          isLastColumnActual: gridIndex >= totalColumns - 1,
        ));

        gridIndex++;
      } else {
        // --- NEW CELL ---
        if (cellIndex < row.cells.length) {
          final cell = row.cells[cellIndex];

          final span = cell.colSpan > 0 ? cell.colSpan : 1;
          double width = 0;
          for (int k = 0; k < span; k++) {
            if (gridIndex + k < colWidths.length) {
              width += colWidths[gridIndex + k];
            } else {
              width += 100;
            }
          }

          final rowSpan = cell.rowSpan > 1 ? cell.rowSpan : 1;

          for (int k = 0; k < span; k++) {
            if (gridIndex + k < skipCounts.length) {
              skipCounts[gridIndex + k] = rowSpan - 1;
            }
          }

          bool hasVMerge = rowSpan > 1;

          // Check if this cell spans to last column
          final cellIsLastColumn =
              (gridIndex + span - 1) >= totalColumns - 1 && look.lastColumn;

          cells.add(_buildCell(
            cell,
            width,
            drawTop: true,
            drawBottom: !hasVMerge,
            isEmpty: false,
            tableStyle: style,
            tableLook: look,
            rowBackground: rowBackground,
            isHeaderRow: isHeaderRow,
            isLastRow: isLastRow,
            isFirstColumn: isFirstColumn,
            isLastColumn: cellIsLastColumn,
            isFirstRowActual: rowIndex == 0,
            isLastRowActual: rowIndex == totalRows - 1,
            isFirstColumnActual: gridIndex == 0,
            isLastColumnActual: (gridIndex + span - 1) >= totalColumns - 1,
          ));

          gridIndex += span;
          cellIndex++;
        } else {
          if (gridIndex < colWidths.length) {
            cells.add(SizedBox(width: colWidths[gridIndex]));
          }
          gridIndex++;
        }
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }

  Widget _buildCell(
    DocxTableCell? cell,
    double width, {
    required bool drawTop,
    required bool drawBottom,
    required bool isEmpty,
    required DocxTableStyle tableStyle,
    DocxTableLook? tableLook,
    Color? rowBackground,
    bool isHeaderRow = false,
    bool isLastRow = false,
    bool isFirstColumn = false,
    bool isLastColumn = false,
    bool isFirstRowActual = false,
    bool isLastRowActual = false,
    bool isFirstColumnActual = false,
    bool isLastColumnActual = false,
  }) {
    // Helper to get side with proper merging of cell and table-level borders
    BorderSide getSide(DocxBorderSide? cellSide, DocxBorderSide? tableSide,
        {bool forceSkip = false}) {
      if (forceSkip) return BorderSide.none;
      // Use cell border if available, otherwise fall back to table border
      final effectiveSide = cellSide ?? tableSide;

      // If no border defined at either level, return none
      if (effectiveSide == null) {
        return BorderSide.none;
      }

      // If border style is explicitly none, return none
      if (effectiveSide.style == DocxBorder.none) {
        return BorderSide.none;
      }

      // Determine effective color
      Color? borderColor;

      // Try theme color first (takes priority)
      if (effectiveSide.themeColor != null) {
        borderColor = _resolveColor(
            effectiveSide.color.hex,
            effectiveSide.themeColor,
            effectiveSide.themeTint,
            effectiveSide.themeShade);
      }

      // Fall back to direct hex color if no theme color
      if (borderColor == null && effectiveSide.color.hex != 'auto') {
        borderColor = _resolveColor(effectiveSide.color.hex, null, null, null);
      }

      // Fall back to table's default border color
      borderColor ??= _resolveColor(tableStyle.borderColor, null, null, null);

      // Determine effective width
      double borderWidth;
      if (effectiveSide.size > 0) {
        borderWidth = (effectiveSide.size / 8.0).clamp(0.5, 5.0);
      } else {
        borderWidth = (tableStyle.borderWidth / 8.0).clamp(0.5, 5.0);
      }

      return BorderSide(
        color: borderColor ?? Colors.transparent,
        width: borderWidth,
        style: effectiveSide.style == DocxBorder.dotted ||
                effectiveSide.style == DocxBorder.dashed
            ? BorderStyle.none
            : BorderStyle.solid,
      );
    }

    // Determine which table-level border to use based on position
    // - Outer edges: use borderTop/borderBottom/borderLeft/borderRight
    // - Inner edges: use borderInsideH (horizontal inner) / borderInsideV (vertical inner)

    // QUICK FIX: Create a default subtle border for tables without explicit border definitions
    // This handles the case where borders come from table styles (in styles.xml) which aren't
    // currently parsed. A proper fix would parse w:tblStylePr/w:tcBorders from style definitions.
    DocxBorderSide? defaultSubtleBorder;
    final hasAnyExplicitBorder = cell?.borderTop != null ||
        cell?.borderBottom != null ||
        cell?.borderLeft != null ||
        cell?.borderRight != null ||
        tableStyle.borderTop != null ||
        tableStyle.borderBottom != null ||
        tableStyle.borderLeft != null ||
        tableStyle.borderRight != null ||
        tableStyle.borderInsideH != null ||
        tableStyle.borderInsideV != null;

    if (!hasAnyExplicitBorder) {
      // Apply subtle gray default border when no borders are defined
      defaultSubtleBorder = DocxBorderSide(
        color: DocxColor('D0D0D0'),
        style: DocxBorder.single,
        size: 2, // 1pt border (8 eighths)
      );
    }

    // Get table-level borders with default fallback
    final topTableBorder =
        isFirstRowActual ? tableStyle.borderTop : tableStyle.borderInsideH;
    final bottomTableBorder =
        isLastRowActual ? tableStyle.borderBottom : tableStyle.borderInsideH;
    final leftTableBorder =
        isFirstColumnActual ? tableStyle.borderLeft : tableStyle.borderInsideV;
    final rightTableBorder =
        isLastColumnActual ? tableStyle.borderRight : tableStyle.borderInsideV;

    Border sideBorder = Border(
      top: getSide(cell?.borderTop, topTableBorder),
      bottom: getSide(cell?.borderBottom, bottomTableBorder),
      left: getSide(cell?.borderLeft, leftTableBorder),
      right: getSide(cell?.borderRight, rightTableBorder),
    );

    // Background: Cell shading takes priority, then row background
    Color? color;
    if (cell != null) {
      color = _resolveColor(cell.shadingFill, cell.themeFill,
          cell.themeFillTint, cell.themeFillShade);
    }
    // Fall back to row background if cell has no explicit shading
    color ??= rowBackground;

    // Content
    Widget? contentWidget;
    if (!isEmpty && cell != null) {
      final children = <Widget>[];
      for (final child in cell.children) {
        if (child is DocxParagraph) {
          children.add(paragraphBuilder.build(child));
        } else if (child is DocxTable) {
          children.add(build(child)); // Recursive
        }
      }

      MainAxisAlignment mainAxis = MainAxisAlignment.start;
      if (cell.verticalAlign == DocxVerticalAlign.center) {
        mainAxis = MainAxisAlignment.center;
      }
      if (cell.verticalAlign == DocxVerticalAlign.bottom) {
        mainAxis = MainAxisAlignment.end;
      }

      contentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxis,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );

      // Vertical align wrapper
      if (cell.verticalAlign != DocxVerticalAlign.top) {
        if (cell.verticalAlign == DocxVerticalAlign.center) {
          contentWidget = Center(child: contentWidget);
        } else if (cell.verticalAlign == DocxVerticalAlign.bottom) {
          contentWidget =
              Align(alignment: Alignment.bottomLeft, child: contentWidget);
        }
      }

      // Apply conditional text styling (bold for header row or first column)
      if (isHeaderRow || isFirstColumn) {
        // Determine text color for contrast (white text on dark backgrounds)
        Color? textColor;
        if (color != null) {
          final luminance = color.computeLuminance();
          if (luminance < 0.5) {
            textColor = Colors.white;
          }
        }

        contentWidget = DefaultTextStyle.merge(
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          child: contentWidget,
        );
      }
    }

    // Use cellPadding from style if available, otherwise default to 4.0
    final cellPaddingPx = tableStyle.cellPadding != null
        ? (tableStyle.cellPadding! * _twipsToPx).clamp(2.0, 20.0)
        : 4.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        border: sideBorder,
      ),
      padding: EdgeInsets.all(cellPaddingPx),
      child: contentWidget,
    );
  }

  /// Resolve color from hex or theme properties (tint/shade).
  Color? _resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    // 1. Try Theme Color
    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) {
        baseColor = _parseHex(themeHex);
      }
    }

    // 2. Fallback to direct Hex
    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = _parseHex(hex);
    }

    if (baseColor == null) return null;

    // 3. Apply Tint/Shade
    // Note: The OOXML tint/shade specification is complex and the simple
    // alphaBlend approach was incorrect (e.g., black became gray).
    // For now, skip tint/shade processing and use the base color directly.
    // A proper implementation would use HSL color space calculations.
    //
    // TODO: Implement proper OOXML tint/shade logic if needed:
    // - Tint: Lighten color towards white
    // - Shade: Darken color towards black
    // The current values in DOCX indicate the "amount" of the base color to preserve.

    return baseColor;
  }

  Color? _parseHex(String hex) {
    if (hex == 'auto' || hex.isEmpty) return null;
    var clean = hex.replaceAll('#', '').replaceAll('0x', '');
    if (clean.length == 8) {
      // ARGB?
      return Color(int.parse('0x$clean'));
    }
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return null;
  }
}
