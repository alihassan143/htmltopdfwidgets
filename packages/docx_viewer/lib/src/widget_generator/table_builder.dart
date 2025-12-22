import 'dart:convert';

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxTable] elements.
///
/// Uses HTML rendering approach (like microsoft_viewer) for complex tables
/// with proper support for colspan, rowspan, borders, and cell styling.
class TableBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;

  TableBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
  });

  /// Build a widget from a [DocxTable] using HTML rendering.
  Widget build(DocxTable table) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Convert table to HTML for rendering
    final htmlString = _tableToHtml(table);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: HtmlWidget(
        htmlString,
        textStyle: TextStyle(
          fontSize: theme.defaultTextStyle.fontSize ?? 14,
          color: theme.defaultTextStyle.color ?? Colors.black87,
        ),
      ),
    );
  }

  /// Convert DocxTable to HTML string for HtmlWidget rendering.
  String _tableToHtml(DocxTable table) {
    final buffer = StringBuffer();

    // Get table style
    final tableStyle = table.style;
    final borderColor = _getColorString(tableStyle.borderColor);
    final borderWidth = (tableStyle.borderWidth / 8.0).clamp(0.5, 4.0);

    // Calculate table width
    // Calculate table width
    String tableWidth = 'auto'; // Default to auto, not 100%
    if (table.width != null && table.width! > 0) {
      if (table.widthType == DocxWidthType.pct) {
        tableWidth = '${table.width! / 50}%'; // DOCX percentage is in fiftieths
      } else if (table.widthType == DocxWidthType.dxa) {
        // Twips to pixels: 1440 twips = 1 inch. 96 px = 1 inch. 1 px = 15 twips.
        tableWidth = '${table.width! / 15}px';
      }
    }

    // Handle floating table position (margins/offsets)
    // HTML renderer doesn't support absolute positioning well in this context,
    // so we translate what we can to buffer-level styles or separate wrapper.

    // Global table fill
    String tableBackground = '';
    if (tableStyle.fill != null) {
      tableBackground = 'background-color: #${_cleanHex(tableStyle.fill!)};';
    }

    // Handle alignment and floating
    String containerStyle = '';
    String tableFloat = '';

    if (table.position != null) {
      // Floating table logic
      if (table.alignment == DocxAlign.left) {
        tableFloat = 'float: left; margin-right: 1em;';
      } else if (table.alignment == DocxAlign.right) {
        tableFloat = 'float: right; margin-left: 1em;';
      }
    } else {
      // Standard table alignment
      if (table.alignment == DocxAlign.center) {
        containerStyle = 'text-align: center;';
        // Also set margin auto for block centering
        tableFloat = 'margin-left: auto; margin-right: auto;';
      } else if (table.alignment == DocxAlign.right) {
        containerStyle = 'text-align: right;';
        tableFloat = 'margin-left: auto;';
      }
    }

    buffer.writeln('<html><body>');

    // Wrap table in a div for alignment/floating
    // If floating, the div floats. If centering, the div aligns text.
    if (tableFloat.isNotEmpty || containerStyle.isNotEmpty) {
      buffer.writeln('<div style="$containerStyle $tableFloat">');
    }

    buffer.writeln(
        '<table style="border-collapse: collapse; width: $tableWidth; $tableBackground">');

    // Use table look flags
    final look = table.look;

    for (int rowIndex = 0; rowIndex < table.rows.length; rowIndex++) {
      final row = table.rows[rowIndex];
      final isFirstRow = rowIndex == 0;
      final isLastRow = rowIndex == table.rows.length - 1;
      final isEven = rowIndex % 2 == 0;

      buffer.writeln('<tr>');

      for (int colIndex = 0; colIndex < row.cells.length; colIndex++) {
        final cell = row.cells[colIndex];

        // Get cell dimensions
        final colSpan = cell.colSpan > 0 ? cell.colSpan : 1;
        final rowSpan = cell.rowSpan > 0 ? cell.rowSpan : 1;

        final isFirstCol = colIndex == 0;
        final isLastCol = colIndex == row.cells.length - 1;

        // Build cell style
        final cellStyle = _buildCellStyle(
          cell,
          tableStyle,
          isHeader: (isFirstRow && look.firstRow) ||
              (isLastRow && look.lastRow), // Simplified logic
          isFirstRow: isFirstRow && look.firstRow,
          isLastRow: isLastRow && look.lastRow,
          isFirstCol: isFirstCol && look.firstColumn,
          isLastCol: isLastCol && look.lastColumn,
          isEven: isEven,
          look: look,
          defaultBorderColor: borderColor,
          defaultBorderWidth: borderWidth,
        );

        // Get cell content
        final cellContent = _getCellContent(cell);

        buffer.write('<td style="$cellStyle"');
        if (colSpan > 1) buffer.write(' colspan="$colSpan"');
        if (rowSpan > 1) buffer.write(' rowspan="$rowSpan"');
        buffer.write('>');
        buffer.write(cellContent);
        buffer.writeln('</td>');
      }

      buffer.writeln('</tr>');
    }

    buffer.writeln('</table>');

    if (tableFloat.isNotEmpty) {
      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');

    return buffer.toString();
  }

  /// Build CSS style string for a table cell.
  String _buildCellStyle(
    DocxTableCell cell,
    DocxTableStyle tableStyle, {
    required bool isHeader,
    required bool isFirstRow,
    required bool isLastRow,
    required bool isFirstCol,
    required bool isLastCol,
    required bool isEven,
    required DocxTableLook look,
    required String defaultBorderColor,
    required double defaultBorderWidth,
  }) {
    final styles = <String>[];

    // Cell padding
    final padding = tableStyle.cellPadding / 15.0; // Convert twips to pixels
    styles.add('padding: ${padding.clamp(2, 20)}px');

    // Vertical alignment
    switch (cell.verticalAlign) {
      case DocxVerticalAlign.top:
        styles.add('vertical-align: top');
        break;
      case DocxVerticalAlign.center:
        styles.add('vertical-align: middle');
        break;
      case DocxVerticalAlign.bottom:
        styles.add('vertical-align: bottom');
        break;
    }

    // Background color priority:
    // 1. Cell specific fill
    // 2. Conditional formatting (Header, Total Row, Banding)

    if (cell.shadingFill != null && cell.shadingFill != 'auto') {
      styles.add('background-color: #${_cleanHex(cell.shadingFill!)}');
    } else {
      // Conditional styling
      String? conditionalFill;

      if (isFirstRow && tableStyle.headerFill != null) {
        conditionalFill = tableStyle.headerFill;
      } else if (isLastRow && tableStyle.headerFill != null) {
        // Often total rows share header style, but AST doesn't have specific totalRowFill.
        // Implementation dependent.
      } else if (!look.noHBand) {
        // Banding enabled
        if (isEven && tableStyle.evenRowFill != null) {
          conditionalFill = tableStyle.evenRowFill;
        } else if (!isEven && tableStyle.oddRowFill != null) {
          conditionalFill = tableStyle.oddRowFill;
        }
      }

      if (conditionalFill != null) {
        styles.add('background-color: #${_cleanHex(conditionalFill)}');
      } else if (isHeader) {
        styles.add(
            'background-color: #${_colorToHex(theme.tableHeaderBackground)}');
      }
    }

    // Cell borders logic for border-collapse
    // In collapsed mode, borders are shared.
    // If we define all 4 borders for every cell, simple HTML renderers might double them up or draw them adjacent.
    // To mimic standard behavior, we ensure precise border definitions.
    // However, with HtmlWidget's border-collapse: collapse, defining all borders is usually safe *if* they are identical.
    // The visual artifact might be due to default border width or color mismatches.

    if (cell.borderTop != null) {
      styles.add('border-top: ${_borderSideToCSS(cell.borderTop!)}');
    }

    if (cell.borderBottom != null) {
      styles.add('border-bottom: ${_borderSideToCSS(cell.borderBottom!)}');
    }

    if (cell.borderLeft != null) {
      styles.add('border-left: ${_borderSideToCSS(cell.borderLeft!)}');
    }

    if (cell.borderRight != null) {
      styles.add('border-right: ${_borderSideToCSS(cell.borderRight!)}');
    }

    // Cell width if specified
    if (cell.width != null && cell.width! > 0) {
      styles.add('width: ${cell.width! / 20}px'); // Twips to pixels
    }

    return styles.join('; ');
  }

  /// Convert DocxBorderSide to CSS border string.
  String _borderSideToCSS(DocxBorderSide side) {
    if (side.style == DocxBorder.none) {
      return 'none';
    }

    final width = (side.size / 8.0).clamp(0.5, 4.0);
    final color = _cleanHex(side.color.hex);

    String styleStr = 'solid';
    switch (side.style) {
      case DocxBorder.dotted:
        styleStr = 'dotted';
        break;
      case DocxBorder.dashed:
        styleStr = 'dashed';
        break;
      case DocxBorder.double:
        styleStr = 'double';
        break;
      default:
        styleStr = 'solid';
    }

    return '${width}px $styleStr #$color';
  }

  /// Get cell content as HTML string.
  String _getCellContent(DocxTableCell cell) {
    final buffer = StringBuffer();

    for (final child in cell.children) {
      if (child is DocxParagraph) {
        buffer.write(_paragraphToHtml(child));
      }
    }

    return buffer.isEmpty ? '&nbsp;' : buffer.toString();
  }

  /// Convert paragraph to HTML string.
  String _paragraphToHtml(DocxParagraph paragraph) {
    final buffer = StringBuffer();

    // Get paragraph alignment
    String align = 'left';
    switch (paragraph.align) {
      case DocxAlign.center:
        align = 'center';
        break;
      case DocxAlign.right:
        align = 'right';
        break;
      case DocxAlign.justify:
        align = 'justify';
        break;
      default:
        align = 'left';
    }

    buffer.write('<p style="margin: 2px 0; text-align: $align;">');

    for (final inline in paragraph.children) {
      if (inline is DocxText) {
        buffer.write(_textToHtml(inline));
      } else if (inline is DocxLineBreak) {
        buffer.write('<br/>');
      } else if (inline is DocxTab) {
        buffer.write('&nbsp;&nbsp;&nbsp;&nbsp;');
      } else if (inline is DocxCheckbox) {
        buffer.write(inline.isChecked ? '☒' : '☐');
      } else if (inline is DocxInlineImage) {
        // Handle inline images with base64 encoding
        final base64 = _bytesToBase64(inline.bytes);
        final width = inline.width;
        final height = inline.height;
        buffer.write(
            '<img src="data:image/png;base64,$base64" width="$width" height="$height" style="display: inline-block; vertical-align: middle;"/>');
      }
    }

    buffer.write('</p>');
    return buffer.toString();
  }

  /// Convert DocxText to HTML span with styles.
  String _textToHtml(DocxText text) {
    final styles = <String>[];
    String content = _escapeHtml(text.content);

    // Text color
    if (text.color != null && text.color!.hex != 'auto') {
      styles.add('color: #${_cleanHex(text.color!.hex)}');
    }

    // Font size
    if (text.fontSize != null) {
      styles.add('font-size: ${text.fontSize}px');
    }

    // Font family
    if (text.fontFamily != null) {
      styles.add('font-family: "${text.fontFamily}"');
    }

    // Font weight
    if (text.fontWeight == DocxFontWeight.bold) {
      styles.add('font-weight: bold');
    }

    // Font style
    if (text.fontStyle == DocxFontStyle.italic) {
      styles.add('font-style: italic');
    }

    // Text decoration
    if (text.decoration == DocxTextDecoration.underline) {
      styles.add('text-decoration: underline');
    } else if (text.decoration == DocxTextDecoration.strikethrough) {
      styles.add('text-decoration: line-through');
    }

    // Double strike
    if (text.isDoubleStrike) {
      styles.add('text-decoration: line-through double');
    }

    // Background color (highlight)
    if (text.highlight != DocxHighlight.none) {
      final highlightColor = _highlightToHex(text.highlight);
      if (highlightColor != null) {
        styles.add('background-color: $highlightColor');
      }
    }

    // Shading fill
    if (text.shadingFill != null && text.shadingFill != 'auto') {
      styles.add('background-color: #${_cleanHex(text.shadingFill!)}');
    }

    // All caps
    if (text.isAllCaps) {
      content = content.toUpperCase();
    }

    // Small caps (simulate with uppercase and smaller font)
    if (text.isSmallCaps) {
      content = content.toUpperCase();
      styles.add('font-variant: small-caps');
    }

    // Superscript/Subscript
    if (text.isSuperscript) {
      return '<sup style="${styles.join('; ')}">$content</sup>';
    }
    if (text.isSubscript) {
      return '<sub style="${styles.join('; ')}">$content</sub>';
    }

    if (styles.isEmpty) {
      return content;
    }

    return '<span style="${styles.join('; ')}">$content</span>';
  }

  /// Convert highlight color enum to hex color.
  String? _highlightToHex(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.yellow:
        return '#FFFF00';
      case DocxHighlight.green:
        return '#00FF00';
      case DocxHighlight.cyan:
        return '#00FFFF';
      case DocxHighlight.magenta:
        return '#FF00FF';
      case DocxHighlight.blue:
        return '#0000FF';
      case DocxHighlight.red:
        return '#FF0000';
      case DocxHighlight.darkBlue:
        return '#00008B';
      case DocxHighlight.darkCyan:
        return '#008B8B';
      case DocxHighlight.darkGreen:
        return '#006400';
      case DocxHighlight.darkMagenta:
        return '#8B008B';
      case DocxHighlight.darkRed:
        return '#8B0000';
      case DocxHighlight.darkYellow:
        return '#808000';
      case DocxHighlight.darkGray:
        return '#A9A9A9';
      case DocxHighlight.lightGray:
        return '#D3D3D3';
      case DocxHighlight.black:
        return '#000000';
      case DocxHighlight.none:
        return null;
    }
  }

  /// Escape HTML special characters.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Clean hex color string.
  String _cleanHex(String hex) {
    String clean = hex.replaceAll('#', '').replaceAll('0x', '');
    if (clean == 'auto' || clean.isEmpty) {
      return '000000';
    }
    if (clean.length == 8) {
      // Remove alpha channel for CSS
      clean = clean.substring(2);
    }
    return clean;
  }

  /// Get color string from table style border color.
  String _getColorString(String color) {
    if (color == 'auto' || color.isEmpty) {
      return _colorToHex(theme.tableBorderColor);
    }
    return _cleanHex(color);
  }

  /// Convert Flutter Color to hex string.
  String _colorToHex(Color color) {
    final r =
        ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final g =
        ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final b =
        ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    return '$r$g$b';
  }

  /// Convert bytes to base64 string for inline images.
  String _bytesToBase64(List<int> bytes) {
    return base64Encode(bytes);
  }
}
