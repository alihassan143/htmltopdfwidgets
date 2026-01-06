import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'css_style.dart';

/// Represents a segment of text with a specific style.
class LayoutSpan {
  final String text;
  final CSSStyle style;
  final PdfFont font;
  final PdfStringFormat? format;

  LayoutSpan({
    required this.text,
    required this.style,
    required this.font,
    this.format,
  });
}

/// Represents a positioned piece of text within a line.
class PositionedSpan {
  final String text;
  final CSSStyle style;
  final PdfFont font;
  final PdfStringFormat? format;
  final double x;
  final double y; // Relative to line top
  final double width;
  final double height;

  PositionedSpan({
    required this.text,
    required this.style,
    required this.font,
    this.format,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Represents a single line of text layout.
class LayoutLine {
  final List<PositionedSpan> spans;
  final double width;
  final double height;
  final double baseline;

  LayoutLine({
    required this.spans,
    required this.width,
    required this.height,
    required this.baseline,
  });
}

/// Represents the full layout of a block element.
class LayoutResult {
  final List<LayoutLine> lines;
  final double width;
  final double height;

  LayoutResult({
    required this.lines,
    required this.width,
    required this.height,
  });
}

/// Helper class to perform text layout calculations.
class TextLayout {
  /// Breaks text into lines based on maxWidth and styles.
  static LayoutResult performLayout({
    required List<LayoutSpan> spans,
    required double maxWidth,
    double lineHeightMultiplier = 1.0,
  }) {
    List<LayoutLine> lines = [];
    List<PositionedSpan> currentLineSpans = [];
    double currentLineWidth = 0.0;
    double maxLineHeight = 0.0;
    double maxAscent = 0.0;

    for (var span in spans) {
      // Logic:
      // 1. Measure word.
      // 2. If fits, add to line.
      // 3. If not fits, finish line, start new.

      // 3. If not fits, finish line, start new.

      // RegExp exp = RegExp(r"([^\s]+)|(\s+)");
      // Unused

      // Pre-process text to handle newlines
      // Split by spaces but preserve newlines?
      // Simpler: Replace \n with a special placeholder or handle it in the loop
      // If we blindly split by ' ', \n might lay inside.
      // Let's replace \n with " \n " so it becomes a separate token when splitting by space?
      // No, split(' ') on "A\nB" -> "A\nB".
      // Let's replace \n with " \n " first.
      final treatedText = span.text.replaceAll('\n', ' \n ');
      final words = treatedText.split(' ');

      double spaceWidth = _measureText(' ', span.font);
      if (spaceWidth <= 0.001) {
        spaceWidth = span.font.size * 0.25;
      }

      for (int i = 0; i < words.length; i++) {
        final word = words[i];

        if (word.isEmpty) {
          // Double space case
          if (i < words.length - 1) currentLineWidth += spaceWidth;
          continue;
        }

        if (word == '\n') {
          // Force line break
          lines.add(_createLine(currentLineSpans, maxAscent, maxLineHeight));
          currentLineSpans = [];
          currentLineWidth = 0.0;
          maxLineHeight = 0.0;
          maxAscent = 0.0;
          continue;
        }

        double wordWidth = _measureText(word, span.font);
        double wordHeight = span.font.height;

        // Wrap if needed (normal wrapping)
        if (currentLineWidth + wordWidth > maxWidth && currentLineWidth > 0) {
          lines.add(_createLine(currentLineSpans, maxAscent, maxLineHeight));
          currentLineSpans = [];
          currentLineWidth = 0;
          maxLineHeight = 0;
          maxAscent = 0;
        }

        if (span.font.size > maxAscent) maxAscent = span.font.size;

        PositionedSpan posSpan = PositionedSpan(
          text: word,
          style: span.style,
          font: span.font,
          format: span.format,
          x: currentLineWidth,
          y: 0,
          width: wordWidth,
          height: wordHeight,
        );

        currentLineSpans.add(posSpan);
        currentLineWidth += wordWidth;

        if (wordHeight > maxLineHeight) maxLineHeight = wordHeight;

        if (i < words.length - 1 && words[i + 1] != '\n') {
          // Add space only if next token is not a newline
          currentLineWidth += spaceWidth;
        }
      }
    }

    // Add pending line
    if (currentLineSpans.isNotEmpty) {
      lines.add(_createLine(currentLineSpans, maxAscent, maxLineHeight));
    }

    // Calculate total height
    double totalHeight =
        lines.fold(0, (sum, line) => sum + line.height * lineHeightMultiplier);

    return LayoutResult(lines: lines, width: maxWidth, height: totalHeight);
  }

  static double _measureText(String text, PdfFont font) {
    return font.measureString(text).width;
  }

  static LayoutLine _createLine(
      List<PositionedSpan> spans, double maxAscent, double maxHeight) {
    List<PositionedSpan> aligned = [];
    for (var s in spans) {
      // Bottom align:
      double y = maxHeight - s.height;

      aligned.add(PositionedSpan(
          text: s.text,
          style: s.style,
          font: s.font,
          x: s.x,
          y: y,
          width: s.width,
          height: s.height));
    }

    return LayoutLine(
      spans: aligned,
      width: spans.isEmpty ? 0 : (spans.last.x + spans.last.width),
      height: maxHeight,
      baseline: maxHeight * 0.8, // Dummy
    );
  }
}
