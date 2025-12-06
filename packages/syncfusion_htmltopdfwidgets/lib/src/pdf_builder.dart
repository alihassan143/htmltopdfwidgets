import 'dart:typed_data';

import 'package:flutter/material.dart'
    show
        Color,
        Colors,
        FontWeight,
        FontStyle,
        TextDecoration,
        Rect,
        Offset,
        Size,
        EdgeInsets;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'htmltagstyles.dart';
import 'parser/css_style.dart';
import 'parser/render_node.dart';

class PdfBuilder {
  final RenderNode root;
  final PdfDocument document;
  final HtmlTagStyle tagStyle;

  PdfLayoutResult? _lastResult;
  final double _pageWidth = 515; // A4 width minus margins approx
  bool _newLinePending = true; // Start with new line

  PdfBuilder({
    required this.root,
    required this.document,
    this.tagStyle = const HtmlTagStyle(),
  });

  Future<void> build() async {
    if (document.pages.count == 0) {
      document.pages.add();
    }

    await _drawNode(root);
  }

  Future<void> _drawNode(RenderNode node) async {
    if (node.display == Display.none) return;

    if (node.tagName == '#text') {
      await _drawText(node);
      return;
    }

    if (node.tagName == 'img') {
      await _drawImage(node);
      return;
    }

    if (node.tagName == 'table') {
      await _drawTable(node);
      return;
    }

    // Handle Block elements
    if (node.display == Display.block) {
      _ensureNewLine();
      // Render children
      for (var child in node.children) {
        await _drawNode(child);
      }
      _ensureNewLine(); // End block
      return;
    }

    // Handle Inline elements container
    for (var child in node.children) {
      await _drawNode(child);
    }
  }

  void _ensureNewLine() {
    _newLinePending = true;
    print('Ensure New Line Called');
  }

  Future<void> _drawText(RenderNode node) async {
    if (node.text == null || node.text!.isEmpty) return;

    print('Drawing Text: "${node.text}"');
    final font = await _resolveFont(node.style);
    final brush =
        PdfSolidBrush(_resolveColor(node.style.color ?? Colors.black));

    final element = PdfTextElement(
        text: node.text!,
        font: font,
        brush: brush,
        format: PdfStringFormat(
          lineAlignment: PdfVerticalAlignment.top,
          alignment: _resolveTextAlign(node.style.textAlign),
        ));

    Rect bounds;
    PdfPage? page = _lastResult?.page ?? document.pages[0];

    double x = 0;
    double y = 0;

    if (_lastResult != null) {
      print('Previous Result Bounds: ${_lastResult!.bounds}');
    } else {
      print('No Previous Result (Start)');
    }

    if (_newLinePending) {
      x = 0;
      y = _lastResult?.bounds.bottom ?? 0;
      _newLinePending = false;
      print('New Line Forced: Y=$y');
    } else if (_lastResult != null) {
      x = _lastResult!.bounds.right;
      y = _lastResult!.bounds.top;
      print('Inline Flow: X=$x, Y=$y');
    }

    bounds = Rect.fromLTWH(x, y, _pageWidth - x, 0);

    _lastResult = element.draw(page: page, bounds: bounds);
    print('Text Drawn. New Bounds: ${_lastResult?.bounds}');
  }

  Future<void> _drawImage(RenderNode node) async {
    print('Drawing Image');
    _ensureNewLine();

    final src = node.attributes['src'];
    if (src == null) return;

    Uint8List? imageBytes;

    if (src.startsWith('http')) {
      final response = await http.get(Uri.parse(src));
      if (response.statusCode == 200) {
        imageBytes = response.bodyBytes;
      }
    } else if (src.startsWith('assets/')) {
      try {
        final data = await rootBundle.load(src);
        imageBytes = data.buffer.asUint8List();
      } catch (e) {
        print('Error loading asset: $e');
      }
    }

    if (imageBytes != null) {
      final bitmap = PdfBitmap(imageBytes);
      double width = node.style.width ?? bitmap.width.toDouble();
      double height = node.style.height ?? bitmap.height.toDouble();

      PdfPage? page = _lastResult?.page ?? document.pages[0];
      double y = _lastResult?.bounds.bottom ?? 0;

      _lastResult =
          bitmap.draw(page: page, bounds: Rect.fromLTWH(0, y, width, height));
      _ensureNewLine();
    }
  }

  Future<void> _drawTable(RenderNode node) async {
    print('Drawing Table');
    _ensureNewLine();

    final grid = PdfGrid();

    List<RenderNode> trs = [];
    void findTrs(RenderNode n) {
      if (n.tagName == 'tr')
        trs.add(n);
      else
        n.children.forEach(findTrs);
    }

    findTrs(node);

    if (trs.isEmpty) return;

    int maxCols = 0;
    for (var tr in trs) {
      int cols = tr.children
          .where((c) => c.tagName == 'td' || c.tagName == 'th')
          .length;
      if (cols > maxCols) maxCols = cols;
    }

    grid.columns.add(count: maxCols);

    for (var tr in trs) {
      final row = grid.rows.add();
      int colIndex = 0;
      for (var child in tr.children) {
        if (child.tagName == 'td' || child.tagName == 'th') {
          if (colIndex >= maxCols) break;

          row.cells[colIndex].value = child.text ?? _extractText(child);

          if (child.style.backgroundColor != null) {
            row.cells[colIndex].style.backgroundBrush =
                PdfSolidBrush(_resolveColor(child.style.backgroundColor!));
          }

          colIndex++;
        }
      }
    }

    PdfPage? page = _lastResult?.page ?? document.pages[0];
    double y = _lastResult?.bounds.bottom ?? 0;
    print('Table Y Position: $y');

    _lastResult = grid.draw(page: page, bounds: Rect.fromLTWH(0, y, 0, 0));
    print('Table Drawn. New Bounds: ${_lastResult?.bounds}');
    _ensureNewLine();
  }

  String _extractText(RenderNode node) {
    if (node.text != null) return node.text!;
    return node.children.map((c) => _extractText(c)).join();
  }

  Future<PdfFont> _resolveFont(CSSStyle style) async {
    PdfFontFamily family = PdfFontFamily.helvetica;

    List<PdfFontStyle> styles = [];

    if (style.fontWeight == FontWeight.bold) {
      styles.add(PdfFontStyle.bold);
    }

    if (style.fontStyle == FontStyle.italic) {
      styles.add(PdfFontStyle.italic);
    }

    if (style.textDecoration == TextDecoration.underline) {
      styles.add(PdfFontStyle.underline);
    } else if (style.textDecoration == TextDecoration.lineThrough) {
      styles.add(PdfFontStyle.strikethrough);
    }

    if (styles.isEmpty) {
      return PdfStandardFont(family, style.fontSize ?? 12,
          style: PdfFontStyle.regular);
    }

    return PdfStandardFont(family, style.fontSize ?? 12, multiStyle: styles);
  }

  PdfColor _resolveColor(Color color) {
    return PdfColor(
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
      (color.a * 255.0).round() & 0xff,
    );
  }

  PdfTextAlignment _resolveTextAlign(TextAlign? align) {
    switch (align) {
      case TextAlign.center:
        return PdfTextAlignment.center;
      case TextAlign.right:
        return PdfTextAlignment.right;
      case TextAlign.justify:
        return PdfTextAlignment.justify;
      default:
        return PdfTextAlignment.left;
    }
  }
}
