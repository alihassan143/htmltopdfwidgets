import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import 'custom_table_widget.dart';
import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxTable] elements.
///
/// This builder supports irregular tables with colspan and rowspan,
/// unlike Flutter's built-in [Table] widget which requires all rows
/// to have the same number of children.
class TableBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;

  TableBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
  });

  /// Build a widget from a [DocxTable].
  Widget build(DocxTable table) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate grid dimensions
    final gridInfo = _calculateGridDimensions(table);
    final columnCount = gridInfo.columnCount;
    final rowCount = table.rows.length;

    // Build cell data with proper positioning
    final cellDataList = <TableCellData>[];

    // Track occupied cells in a 2D grid (for handling rowspan)
    final occupiedGrid = List.generate(
      rowCount,
      (_) => List<bool>.filled(columnCount, false),
    );

    for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final row = table.rows[rowIndex];
      int colIndex = 0;

      for (final cell in row.cells) {
        // Skip to next unoccupied column
        while (colIndex < columnCount && occupiedGrid[rowIndex][colIndex]) {
          colIndex++;
        }

        if (colIndex >= columnCount) break;

        // Get cell spans (default to 1)
        final colSpan = cell.colSpan > 0 ? cell.colSpan : 1;
        final rowSpan = cell.rowSpan > 0 ? cell.rowSpan : 1;

        // Mark cells as occupied
        for (int r = rowIndex; r < rowIndex + rowSpan && r < rowCount; r++) {
          for (int c = colIndex;
              c < colIndex + colSpan && c < columnCount;
              c++) {
            occupiedGrid[r][c] = true;
          }
        }

        // Build cell content
        final cellWidget = _buildCellContent(cell, isHeader: rowIndex == 0);

        // Determine background color
        Color? backgroundColor;
        if (cell.shadingFill != null) {
          backgroundColor = _parseHexColor(cell.shadingFill!);
        } else if (rowIndex == 0) {
          backgroundColor = theme.tableHeaderBackground;
        }

        cellDataList.add(TableCellData(
          child: cellWidget,
          row: rowIndex,
          col: colIndex,
          rowSpan: rowSpan,
          colSpan: colSpan,
          backgroundColor: backgroundColor,
          verticalAlign: _mapVerticalAlignment(cell.verticalAlign),
        ));

        colIndex += colSpan;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: CustomTableLayout(
        cells: cellDataList,
        columnCount: columnCount,
        rowCount: rowCount,
        borderColor: theme.tableBorderColor,
        borderWidth: 1.0,
        cellPadding: const EdgeInsets.all(8),
        minRowHeight: 32.0,
      ),
    );
  }

  /// Calculate the total number of columns needed for the table grid.
  _GridInfo _calculateGridDimensions(DocxTable table) {
    int maxColumns = 0;

    for (final row in table.rows) {
      int rowColumns = 0;
      for (final cell in row.cells) {
        final colSpan = cell.colSpan > 0 ? cell.colSpan : 1;
        rowColumns += colSpan;
      }
      if (rowColumns > maxColumns) {
        maxColumns = rowColumns;
      }
    }

    return _GridInfo(columnCount: maxColumns);
  }

  /// Build the content widget for a table cell.
  Widget _buildCellContent(DocxTableCell cell, {bool isHeader = false}) {
    final children = <Widget>[];

    for (final child in cell.children) {
      if (child is DocxParagraph) {
        children.add(paragraphBuilder.build(child));
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (children.length == 1) {
      return children.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Map DOCX vertical alignment to Flutter's TableCellVerticalAlignment.
  TableCellVerticalAlignment _mapVerticalAlignment(DocxVerticalAlign? align) {
    switch (align) {
      case DocxVerticalAlign.top:
        return TableCellVerticalAlignment.top;
      case DocxVerticalAlign.center:
        return TableCellVerticalAlignment.middle;
      case DocxVerticalAlign.bottom:
        return TableCellVerticalAlignment.bottom;
      default:
        return TableCellVerticalAlignment.middle;
    }
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return Colors.white;
  }
}

/// Internal class to hold grid dimension information.
class _GridInfo {
  final int columnCount;

  _GridInfo({required this.columnCount});
}
