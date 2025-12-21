import 'package:flutter/material.dart';

/// Data class representing a positioned table cell with span information.
class TableCellData {
  /// The widget content of the cell.
  final Widget child;

  /// Row index (0-based).
  final int row;

  /// Column index (0-based).
  final int col;

  /// Number of rows this cell spans (default: 1).
  final int rowSpan;

  /// Number of columns this cell spans (default: 1).
  final int colSpan;

  /// Background color for this cell.
  final Color? backgroundColor;

  /// Vertical alignment within the cell.
  final TableCellVerticalAlignment verticalAlign;

  const TableCellData({
    required this.child,
    required this.row,
    required this.col,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.backgroundColor,
    this.verticalAlign = TableCellVerticalAlignment.middle,
  });
}

/// Custom table widget that supports colspan and rowspan for irregular tables.
///
/// Unlike Flutter's built-in [Table] widget, this widget handles tables where
/// rows may have different numbers of visible cells due to spanning.
class CustomTableLayout extends StatelessWidget {
  /// List of cells with their position and span data.
  final List<TableCellData> cells;

  /// Total number of columns in the grid.
  final int columnCount;

  /// Total number of rows in the grid.
  final int rowCount;

  /// Border style for the table.
  final Color borderColor;

  /// Border width.
  final double borderWidth;

  /// Default cell padding.
  final EdgeInsets cellPadding;

  /// Minimum row height.
  final double minRowHeight;

  /// Column width mode.
  final TableColumnWidth defaultColumnWidth;

  const CustomTableLayout({
    super.key,
    required this.cells,
    required this.columnCount,
    required this.rowCount,
    this.borderColor = Colors.grey,
    this.borderWidth = 1.0,
    this.cellPadding = const EdgeInsets.all(8),
    this.minRowHeight = 32.0,
    this.defaultColumnWidth = const FlexColumnWidth(),
  });

  @override
  Widget build(BuildContext context) {
    if (columnCount == 0 || rowCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columnWidth = availableWidth / columnCount;

        return _MeasuredTable(
          cells: cells,
          columnCount: columnCount,
          rowCount: rowCount,
          columnWidth: columnWidth,
          minRowHeight: minRowHeight,
          cellPadding: cellPadding,
          borderWidth: borderWidth,
          borderColor: borderColor,
        );
      },
    );
  }
}

/// Widget that measures cell heights and positions them correctly.
class _MeasuredTable extends StatelessWidget {
  final List<TableCellData> cells;
  final int columnCount;
  final int rowCount;
  final double columnWidth;
  final double minRowHeight;
  final EdgeInsets cellPadding;
  final double borderWidth;
  final Color borderColor;

  const _MeasuredTable({
    required this.cells,
    required this.columnCount,
    required this.rowCount,
    required this.columnWidth,
    required this.minRowHeight,
    required this.cellPadding,
    required this.borderWidth,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    // Build rows as Column of Rows
    final rows = <Widget>[];

    // Create a map of cells by their starting row position
    final cellsByRow = <int, List<TableCellData>>{};
    for (final cell in cells) {
      cellsByRow.putIfAbsent(cell.row, () => []).add(cell);
    }

    // Track which cells span into each row
    final spanningCells = <int, List<TableCellData>>{};
    for (final cell in cells) {
      if (cell.rowSpan > 1) {
        for (int r = cell.row + 1;
            r < cell.row + cell.rowSpan && r < rowCount;
            r++) {
          spanningCells.putIfAbsent(r, () => []).add(cell);
        }
      }
    }

    for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final rowCells = cellsByRow[rowIndex] ?? [];

      // Sort cells by column for proper ordering
      rowCells.sort((a, b) => a.col.compareTo(b.col));

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                _buildRowCells(rowIndex, rowCells, spanningCells[rowIndex]),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  List<Widget> _buildRowCells(
    int rowIndex,
    List<TableCellData> rowCells,
    List<TableCellData>? spanningCells,
  ) {
    final widgets = <Widget>[];

    // Create a set of columns that are occupied by spanning cells from previous rows
    final occupiedCols = <int>{};
    if (spanningCells != null) {
      for (final cell in spanningCells) {
        for (int c = cell.col; c < cell.col + cell.colSpan; c++) {
          occupiedCols.add(c);
        }
      }
    }

    int currentCol = 0;
    int cellIndex = 0;

    while (currentCol < columnCount) {
      // Check if this column is occupied by a spanning cell
      if (occupiedCols.contains(currentCol)) {
        // Find the spanning cell that occupies this column
        final spanCell = spanningCells!.firstWhere(
          (c) => c.col <= currentCol && currentCol < c.col + c.colSpan,
        );

        // Add empty spacer for the spanning cell's columns
        // Only add spacer for the first column of the span on this row
        if (currentCol == spanCell.col) {
          widgets.add(
            SizedBox(
              width: columnWidth * spanCell.colSpan - borderWidth,
            ),
          );
          currentCol += spanCell.colSpan;
        } else {
          currentCol++;
        }
        continue;
      }

      // Check if we have a cell at this position
      if (cellIndex < rowCells.length &&
          rowCells[cellIndex].col == currentCol) {
        final cell = rowCells[cellIndex];
        final cellWidth = columnWidth * cell.colSpan - borderWidth;

        widgets.add(
          Container(
            width: cellWidth,
            constraints: BoxConstraints(minHeight: minRowHeight),
            decoration: BoxDecoration(
              color: cell.backgroundColor,
              border: Border(
                top: rowIndex == 0
                    ? BorderSide(color: borderColor, width: borderWidth)
                    : BorderSide.none,
                left: BorderSide(color: borderColor, width: borderWidth),
                right: currentCol + cell.colSpan >= columnCount
                    ? BorderSide(color: borderColor, width: borderWidth)
                    : BorderSide.none,
                bottom: BorderSide(color: borderColor, width: borderWidth),
              ),
            ),
            padding: cellPadding,
            child: cell.child,
          ),
        );

        currentCol += cell.colSpan;
        cellIndex++;
      } else {
        // Empty cell - add spacer
        widgets.add(
          Container(
            width: columnWidth - borderWidth,
            constraints: BoxConstraints(minHeight: minRowHeight),
            decoration: BoxDecoration(
              border: Border(
                top: rowIndex == 0
                    ? BorderSide(color: borderColor, width: borderWidth)
                    : BorderSide.none,
                left: BorderSide(color: borderColor, width: borderWidth),
                right: currentCol + 1 >= columnCount
                    ? BorderSide(color: borderColor, width: borderWidth)
                    : BorderSide.none,
                bottom: BorderSide(color: borderColor, width: borderWidth),
              ),
            ),
          ),
        );
        currentCol++;
      }
    }

    return widgets;
  }
}
