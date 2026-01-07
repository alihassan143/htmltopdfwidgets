import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/utils/block_index_counter.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import 'image_builder.dart';
import 'list_builder.dart';
import 'paragraph_builder.dart';
import 'shape_builder.dart';

/// Builds Flutter widgets from [DocxTable] elements using native layout.
class TableBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final ListBuilder listBuilder;
  final ImageBuilder imageBuilder;
  final ShapeBuilder shapeBuilder;
  final DocxTheme? docxTheme;

  // Constants
  static const double _twipsToPx = 1 / 15.0;

  TableBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    required this.listBuilder,
    required this.imageBuilder,
    required this.shapeBuilder,
    this.docxTheme,
  });

  /// Build a widget from a [DocxTable].
  Widget build(DocxTable table, {BlockIndexCounter? counter}) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }
// ... (rest of build method unchanged until we hit _buildCell logic, but imports and class def are change)
// Wait, I cannot use '...' in replacement content safely if I am replacing the top of the file.
// I need to provide the full content for the replaced section.

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
        counter: counter,
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
    BlockIndexCounter? counter,
  }) {
    final cells = <Widget>[];
    final style = table.style;
    final look = table.look;
    final totalColumns = colWidths.length;

    // Resolve named table style
    DocxStyle? namedStyle;
    if (table.styleId != null && docxTheme != null) {
      namedStyle = docxTheme!.styles[table.styleId];
    }

    // Merge named style base definition into effective table style if needed
    DocxTableStyle effectiveTableStyle = style;
    if (namedStyle != null) {
      effectiveTableStyle = style.copyWith(
        borderTop: style.borderTop ?? namedStyle.borderTop,
        borderBottom: style.borderBottom ??
            namedStyle
                .borderBottomSide, // Note: DocxStyle uses borderBottomSide for pPr/tblPr
        borderLeft: style.borderLeft ?? namedStyle.borderLeft,
        borderRight: style.borderRight ?? namedStyle.borderRight,
        borderInsideH: style.borderInsideH ??
            namedStyle.borderBetween, // Mapping between to InsideH
        borderInsideV: style
            .borderInsideV, // DocxStyle might not have InsideV explicitly mapped same way, need verification
      );

      // DocxStyle uses `borderBottom` sometimes too, check model.
      // DocxStyle AST has: borderTop, borderBottomSide, borderLeft, borderRight, borderBetween, borderBottom
      // We map DocxStyle.borderBetween -> borderInsideH usually for paragraphs, but for tables it helps to overlap.
      // Actually, Table Styles in styles.xml usually use tblPr > tblBorders which map to top/left/bottom/right/insideH/insideV.
      // The DocxStyle model has properties: borderTop, borderBottomSide, borderLeft, borderRight, borderBetween, borderBottom.
      // It seems DocxStyle might need better mapping for tables if it was primarily built for Paragraphs.
      // However, looking at DocxStyle definition, it has `borderTop`, `borderBottomSide`, etc.
      // Let's assume standard mapping for now and refine if needed.
      if (namedStyle.borderBetween != null &&
          effectiveTableStyle.borderInsideH == null) {
        effectiveTableStyle = effectiveTableStyle.copyWith(
            borderInsideH: namedStyle.borderBetween);
      }
    }

    // Determine row-level conditions
    final isHeaderRow = rowIndex == 0 && table.hasHeader && look.firstRow;
    final isLastRow = rowIndex == totalRows - 1 && look.lastRow;
    final isEvenRow = rowIndex % 2 != 0; // 0-indexed, so row 1 is even "band"

    // Resolve conditional styles for this row
    DocxStyle? rowCondStyle;
    if (isHeaderRow) {
      rowCondStyle = namedStyle?.tableConditionals['firstRow'];
    } else if (isLastRow) {
      rowCondStyle = namedStyle?.tableConditionals['lastRow'];
    } else if (!look.noHBand) {
      // Band styling
      if (isEvenRow) {
        rowCondStyle = namedStyle?.tableConditionals['band2Horz']; // Even row
      } else {
        rowCondStyle = namedStyle?.tableConditionals['band1Horz']; // Odd row
      }
    }

    // Determine row-level background based on styling (Prioritize Conditional > Direct Table Style)
    Color? rowBackground;

    if (rowCondStyle?.shadingFill != null || rowCondStyle?.themeFill != null) {
      rowBackground = _resolveColor(
          rowCondStyle!.shadingFill,
          rowCondStyle.themeFill,
          rowCondStyle.themeFillTint,
          rowCondStyle.themeFillShade);
    }

    // Fallback to direct style properties (legacy support) if no conditional override
    if (rowBackground == null) {
      if (isHeaderRow && style.headerFill != null) {
        rowBackground = _resolveColor(style.headerFill, null, null, null);
      }
      if (!isHeaderRow && !look.noHBand) {
        if (isEvenRow && style.evenRowFill != null) {
          rowBackground = _resolveColor(style.evenRowFill, null, null, null);
        } else if (!isEvenRow && style.oddRowFill != null) {
          rowBackground = _resolveColor(style.oddRowFill, null, null, null);
        }
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
          tableStyle: effectiveTableStyle, // Pass effective style
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

          // Determine column conditional style
          DocxStyle? colCondStyle;
          if (isFirstColumn) {
            colCondStyle = namedStyle?.tableConditionals['firstColumn'];
          } else if (cellIsLastColumn) {
            colCondStyle = namedStyle?.tableConditionals['lastColumn'];
          }

          cells.add(_buildCell(
            cell,
            width,
            drawTop: true,
            drawBottom: !hasVMerge,
            isEmpty: false,
            tableStyle: effectiveTableStyle, // Pass effective style
            tableLook: look,
            rowBackground: rowBackground,
            rowCondStyle: rowCondStyle,
            colCondStyle: colCondStyle,
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

    Widget rowWidget = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );

    if (row.height != null) {
      rowWidget = ConstrainedBox(
        constraints: BoxConstraints(minHeight: row.height! * _twipsToPx),
        child: rowWidget,
      );
    }

    return rowWidget;
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
    DocxStyle? rowCondStyle,
    DocxStyle? colCondStyle,
    BlockIndexCounter? counter,
  }) {
    // Helper to get side with proper merging of cell and table-level borders
    BorderSide getSide(
      DocxBorderSide? cellSide,
      DocxBorderSide? tableSide, {
      DocxBorderSide? rowSide,
      DocxBorderSide? colSide,
      bool forceSkip = false,
      bool prioritizeCol = false,
    }) {
      if (forceSkip) return BorderSide.none;

      // Determine effective side based on precedence:
      // Cell > Primary Conditional > Secondary Conditional > Table
      DocxBorderSide? effectiveSide = cellSide;

      if (effectiveSide == null) {
        if (prioritizeCol) {
          effectiveSide = colSide ?? rowSide;
        } else {
          effectiveSide = rowSide ?? colSide;
        }
      }

      effectiveSide ??= tableSide;

      // If no border defined at any level, return none
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

      // Final fallback: If color is still null (e.g. 'auto'), use Black for visible borders
      borderColor ??= Colors.black;

      // Determine effective width
      double borderWidth;
      if (effectiveSide.size > 0) {
        borderWidth = (effectiveSide.size / 8.0).clamp(0.5, 5.0);
      } else {
        borderWidth = (tableStyle.borderWidth / 8.0).clamp(0.5, 5.0);
      }

      return BorderSide(
        color: borderColor,
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
      top: getSide(
        cell?.borderTop,
        topTableBorder,
        rowSide: rowCondStyle?.borderTop,
        colSide: colCondStyle?.borderTop,
      ),
      bottom: getSide(
        cell?.borderBottom,
        bottomTableBorder,
        rowSide: rowCondStyle?.borderBottomSide,
        colSide: colCondStyle?.borderBottomSide,
      ),
      left: getSide(
        cell?.borderLeft,
        leftTableBorder,
        rowSide: rowCondStyle?.borderLeft,
        colSide: colCondStyle?.borderLeft,
        prioritizeCol: true,
      ),
      right: getSide(
        cell?.borderRight,
        rightTableBorder,
        rowSide: rowCondStyle?.borderRight,
        colSide: colCondStyle?.borderRight,
        prioritizeCol: true,
      ),
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
          children.add(paragraphBuilder.build(child, counter: counter));
        } else if (child is DocxTable) {
          children.add(build(child, counter: counter)); // Recursive
        } else if (child is DocxList) {
          children.add(listBuilder.build(child, counter: counter));
        } else if (child is DocxImage) {
          // Extraction skips images, so we shouldn't increment counter for them
          // BUT wait, extractTextForSearch (in DocxWidgetGenerator) only extracts from Paragraph and List inside Table.
          // It does NOT extract from Image or ShapeBlock.
          // So we should NOT pass counter to these builders if they don't consume it.
          // ImageBuilder and ShapeBuilder don't take counter in their build methods currently.
          children.add(imageBuilder.buildBlockImage(child));
        } else if (child is DocxShapeBlock) {
          children.add(shapeBuilder.buildBlockShape(child));
        } else if (child is DocxDropCap) {
          children.add(paragraphBuilder.buildDropCap(child));
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

      // Apply conditional text styling (from named style or default header logic)
      TextStyle? cellTextStyle;

      // 1. Try Conditional Style (Row Priority then Column Priority)
      // Merge column properties on top of row properties? Or vice versa?
      // Usually First Column > Header Row in some cases, but Header Row > Banding.

      if (rowCondStyle != null) {
        if (rowCondStyle.fontWeight == DocxFontWeight.bold) {
          cellTextStyle = (cellTextStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold);
        }
        if (rowCondStyle.color != null) {
          final color = _resolveColor(
              rowCondStyle.color!.hex,
              rowCondStyle.color!.themeColor,
              rowCondStyle.color!.themeTint,
              rowCondStyle.color!.themeShade);
          if (color != null) {
            cellTextStyle =
                (cellTextStyle ?? const TextStyle()).copyWith(color: color);
          }
        }
      }

      if (colCondStyle != null) {
        if (colCondStyle.fontWeight == DocxFontWeight.bold) {
          cellTextStyle = (cellTextStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold);
        }
        if (colCondStyle.color != null) {
          final color = _resolveColor(
              colCondStyle.color!.hex,
              colCondStyle.color!.themeColor,
              colCondStyle.color!.themeTint,
              colCondStyle.color!.themeShade);
          if (color != null) {
            cellTextStyle =
                (cellTextStyle ?? const TextStyle()).copyWith(color: color);
          }
        }
      }

      // 2. Fallback to Hardcoded Header/FirstCol logic ONLY if no conditional style was found/applied
      // AND we are in a header/first-col scenario
      if (cellTextStyle == null && (isHeaderRow || isFirstColumn)) {
        // Determine text color for contrast (white text on dark backgrounds)
        Color? textColor;
        if (color != null) {
          final luminance = color.computeLuminance();
          if (luminance < 0.5) {
            textColor = Colors.white;
          }
        }

        cellTextStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        );
      }

      if (cellTextStyle != null) {
        contentWidget = DefaultTextStyle.merge(
          style: cellTextStyle,
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
    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        // In OOXML, tint is amount of color to keep, rest is white
        // Actually, alphaBlend logic:
        // tint/shade values in OOXML are complex 0-255 scaling.
        // Assuming typical implementation:
        final factor = tintVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        final factor = shadeVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - factor), baseColor);
      }
    }

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
