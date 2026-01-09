import 'pdf_types.dart';

/// Detects tables from text lines and graphic lines.
class PdfTableDetector {
  final List<String> warnings = [];

  /// Tolerance for position comparisons
  static const double tolerance = 2.0;

  /// Minimum cell width
  static const double minCellWidth = 20.0;

  /// Detects tables from text lines and graphic lines.
  List<PdfDetectedTable> detectTables(
    List<PdfTextLine> textLines,
    List<PdfGraphicLine> graphicLines,
  ) {
    final tables = <PdfDetectedTable>[];

    // Strategy 1: Grid-based detection using horizontal and vertical lines
    final gridTables = _detectGridTables(textLines, graphicLines);
    tables.addAll(gridTables);

    // If no tables found via grid, try position-based heuristics
    if (tables.isEmpty) {
      final heuristicTables = _detectHeuristicTables(textLines);
      tables.addAll(heuristicTables);
    }

    return tables;
  }

  /// Detects tables using grid analysis of graphic lines.
  List<PdfDetectedTable> _detectGridTables(
    List<PdfTextLine> textLines,
    List<PdfGraphicLine> graphicLines,
  ) {
    final tables = <PdfDetectedTable>[];

    if (graphicLines.isEmpty) return tables;

    // Separate horizontal and vertical lines
    final horizontals = graphicLines.where((l) => l.isHorizontal).toList();
    final verticals = graphicLines.where((l) => l.isVertical).toList();

    if (horizontals.length < 2 || verticals.length < 2) return tables;

    // Cluster horizontal lines by Y position
    final hClusters = _clusterByPosition(
      horizontals.map((l) => l.y1).toList(),
      tolerance * 2,
    );

    // Cluster vertical lines by X position
    final vClusters = _clusterByPosition(
      verticals.map((l) => l.x1).toList(),
      tolerance * 2,
    );

    if (hClusters.length < 2 || vClusters.length < 2) return tables;

    // Sort clusters
    hClusters.sort((a, b) => b.compareTo(a)); // Top to bottom (PDF Y is up)
    vClusters.sort();

    // Build table grid
    final tableRows = <List<PdfTableCell>>[];

    for (var row = 0; row < hClusters.length - 1; row++) {
      final topY = hClusters[row];
      final bottomY = hClusters[row + 1];
      final rowHeight = (topY - bottomY).abs();

      if (rowHeight < 5) continue; // Skip tiny rows

      final rowCells = <PdfTableCell>[];

      for (var col = 0; col < vClusters.length - 1; col++) {
        final leftX = vClusters[col];
        final rightX = vClusters[col + 1];
        final cellWidth = (rightX - leftX).abs();

        if (cellWidth < minCellWidth) continue;

        // Find text in this cell
        final cellText = textLines.where((t) {
          return t.x >= leftX - tolerance &&
              t.x <= rightX + tolerance &&
              t.y <= topY + tolerance &&
              t.y >= bottomY - tolerance;
        }).toList();

        // Check borders
        final hasTop = horizontals.any((l) =>
            (l.y1 - topY).abs() < tolerance &&
            l.minX <= leftX + tolerance &&
            l.maxX >= rightX - tolerance);

        final hasBottom = horizontals.any((l) =>
            (l.y1 - bottomY).abs() < tolerance &&
            l.minX <= leftX + tolerance &&
            l.maxX >= rightX - tolerance);

        final hasLeft = verticals.any((l) =>
            (l.x1 - leftX).abs() < tolerance &&
            l.minY <= bottomY + tolerance &&
            l.maxY >= topY - tolerance);

        final hasRight = verticals.any((l) =>
            (l.x1 - rightX).abs() < tolerance &&
            l.minY <= bottomY + tolerance &&
            l.maxY >= topY - tolerance);

        rowCells.add(PdfTableCell(
          x: leftX,
          y: bottomY,
          width: cellWidth,
          height: rowHeight,
          textLines: cellText,
          hasTopBorder: hasTop,
          hasBottomBorder: hasBottom,
          hasLeftBorder: hasLeft,
          hasRightBorder: hasRight,
        ));
      }

      if (rowCells.isNotEmpty) {
        tableRows.add(rowCells);
      }
    }

    if (tableRows.length >= 2 && tableRows.first.length >= 2) {
      final minX = vClusters.first;
      final maxX = vClusters.last;
      final minY = hClusters.last;
      final maxY = hClusters.first;

      tables.add(PdfDetectedTable(
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
        rows: tableRows,
      ));
    }

    return tables;
  }

  /// Detects tables using position-based heuristics (fallback).
  List<PdfDetectedTable> _detectHeuristicTables(List<PdfTextLine> textLines) {
    final tables = <PdfDetectedTable>[];

    if (textLines.length < 4) return tables;

    // Sort by Y (top to bottom) then X
    final sorted = List<PdfTextLine>.from(textLines);
    sorted.sort((a, b) {
      final yDiff = b.y.compareTo(a.y); // PDF Y is bottom-up
      if (yDiff != 0) return yDiff;
      return a.x.compareTo(b.x);
    });

    // Group lines by Y position (rows)
    final rows = <List<PdfTextLine>>[];
    var currentRow = <PdfTextLine>[];
    double? lastY;

    for (final line in sorted) {
      if (lastY != null && (lastY - line.y).abs() > line.size * 0.5) {
        if (currentRow.isNotEmpty) {
          rows.add(currentRow);
          currentRow = [];
        }
      }
      currentRow.add(line);
      lastY = line.y;
    }
    if (currentRow.isNotEmpty) rows.add(currentRow);

    // Find consecutive rows with same number of columns
    var tableStart = -1;
    var tableColCount = 0;

    for (var i = 0; i < rows.length; i++) {
      final rowCount = _countColumns(rows[i]);

      if (rowCount >= 2) {
        if (tableStart == -1) {
          tableStart = i;
          tableColCount = rowCount;
        } else if (rowCount != tableColCount) {
          // End current table
          if (i - tableStart >= 2) {
            final table = _buildHeuristicTable(rows.sublist(tableStart, i));
            if (table != null) tables.add(table);
          }
          tableStart = i;
          tableColCount = rowCount;
        }
      } else {
        // End current table
        if (tableStart != -1 && i - tableStart >= 2) {
          final table = _buildHeuristicTable(rows.sublist(tableStart, i));
          if (table != null) tables.add(table);
        }
        tableStart = -1;
      }
    }

    // Check for table at end
    if (tableStart != -1 && rows.length - tableStart >= 2) {
      final table = _buildHeuristicTable(rows.sublist(tableStart));
      if (table != null) tables.add(table);
    }

    return tables;
  }

  int _countColumns(List<PdfTextLine> row) {
    if (row.isEmpty) return 0;

    // Sort by X
    final sorted = List<PdfTextLine>.from(row);
    sorted.sort((a, b) => a.x.compareTo(b.x));

    // Count significant gaps
    var columns = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].x - (sorted[i - 1].x + sorted[i - 1].width);
      if (gap > sorted[i - 1].size * 2) {
        columns++;
      }
    }

    return columns;
  }

  PdfDetectedTable? _buildHeuristicTable(List<List<PdfTextLine>> rows) {
    if (rows.isEmpty) return null;

    // Find column boundaries
    final allX = <double>[];
    for (final row in rows) {
      for (final line in row) {
        allX.add(line.x);
      }
    }
    if (allX.isEmpty) return null;

    final colBoundaries = _clusterByPosition(allX, 20.0);
    colBoundaries.sort();

    if (colBoundaries.length < 2) return null;

    // Build table structure
    final tableRows = <List<PdfTableCell>>[];

    for (final row in rows) {
      final sortedRow = List<PdfTextLine>.from(row);
      sortedRow.sort((a, b) => a.x.compareTo(b.x));

      final cells = <PdfTableCell>[];
      var colIdx = 0;

      for (final line in sortedRow) {
        // Find which column this belongs to
        while (colIdx < colBoundaries.length - 1 &&
            line.x > (colBoundaries[colIdx] + colBoundaries[colIdx + 1]) / 2) {
          colIdx++;
        }

        // Add empty cells if we skipped columns
        while (cells.length < colIdx &&
            colIdx > 0 &&
            cells.length < colBoundaries.length - 1) {
          cells.add(PdfTableCell(
            x: colBoundaries[cells.length],
            y: line.y,
            width:
                colBoundaries[cells.length + 1] - colBoundaries[cells.length],
            height: line.size * 1.5,
            textLines: [],
          ));
        }

        if (cells.length <= colIdx) {
          cells.add(PdfTableCell(
            x: line.x,
            y: line.y,
            width: line.width,
            height: line.size * 1.5,
            textLines: [line],
          ));
        } else {
          cells[colIdx].textLines.add(line);
        }
      }

      // Fill remaining columns
      while (cells.length < colBoundaries.length - 1) {
        cells.add(PdfTableCell(
          x: colBoundaries[cells.length],
          y: row.isNotEmpty ? row.first.y : 0,
          width: colBoundaries[cells.length + 1] - colBoundaries[cells.length],
          height: row.isNotEmpty ? row.first.size * 1.5 : 20,
          textLines: [],
        ));
      }

      if (cells.isNotEmpty) {
        tableRows.add(cells);
      }
    }

    if (tableRows.length < 2) return null;

    final minX = colBoundaries.first;
    final maxX = colBoundaries.last;
    final minY = tableRows.last.first.y;
    final maxY = tableRows.first.first.y + tableRows.first.first.height;

    return PdfDetectedTable(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
      rows: tableRows,
    );
  }

  /// Clusters values by proximity.
  List<double> _clusterByPosition(List<double> values, double tolerance) {
    if (values.isEmpty) return [];

    final sorted = List<double>.from(values);
    sorted.sort();

    final clusters = <double>[];
    var clusterSum = sorted.first;
    var clusterCount = 1;

    for (var i = 1; i < sorted.length; i++) {
      if ((sorted[i] - sorted[i - 1]).abs() < tolerance) {
        clusterSum += sorted[i];
        clusterCount++;
      } else {
        clusters.add(clusterSum / clusterCount);
        clusterSum = sorted[i];
        clusterCount = 1;
      }
    }

    clusters.add(clusterSum / clusterCount);
    return clusters;
  }
}
