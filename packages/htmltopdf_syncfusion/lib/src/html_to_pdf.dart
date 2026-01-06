import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart'
    show FontWeight, FontStyle, TextDecoration;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'htmltagstyles.dart';
import 'parser/css_style.dart';
import 'parser/html_parser.dart';
import 'parser/markdown_parser.dart';
import 'pdf_builder.dart';

export 'htmltagstyles.dart';

/// Converter class to transform HTML content into Syncfusion PDF elements.
class HtmlToPdf {
  /// Converts the given [html] string into PDF elements and adds them to [document].
  ///
  /// [html] The HTML string to convert.
  /// [document] The Syncfusion [PdfDocument] to add the content to.
  /// [tagStyle] Optional custom styles for HTML tags.
  /// [baseStyle] Optional base style for the document.
  Future<Uint8List> convert(
    String html, {
    PdfDocument? targetDocument,
    HtmlTagStyle tagStyle = const HtmlTagStyle(),
    CSSStyle? baseStyle,
  }) async {
    final parser = HtmlParser(
        htmlString: html,
        tagStyle: tagStyle,
        baseStyle: baseStyle ??
            const CSSStyle(
              fontSize: 12.0,
              fontFamily: 'Helvetica',
              fontWeight: FontWeight.normal,
              fontStyle: FontStyle.normal,
              textDecoration: TextDecoration.none,
            ));

    final root = parser.parse();

    final document = targetDocument ?? PdfDocument();
    final builder =
        PdfBuilder(root: root, document: document, tagStyle: tagStyle);

    await builder.build();

    final List<int> bytes = await document.save();

    // Dispose only if we created it
    if (targetDocument == null) {
      document.dispose();
    }

    return Uint8List.fromList(bytes);
  }

  /// Converts the given [markdown] string into PDF elements and adds them to [document].
  ///
  /// [markdown] The Markdown string to convert.
  /// [targetDocument] Optional Syncfusion [PdfDocument] to add the content to.
  /// [tagStyle] Optional custom styles for tags.
  /// [baseStyle] Optional base style for the document.
  Future<Uint8List> convertMarkdown(
    String markdown, {
    PdfDocument? targetDocument,
    HtmlTagStyle tagStyle = const HtmlTagStyle(),
    CSSStyle? baseStyle,
  }) async {
    final parser = MarkdownParser(
        baseStyle: baseStyle ??
            const CSSStyle(
              fontSize: 12.0,
              fontFamily: 'Helvetica',
              fontWeight: FontWeight.normal,
              fontStyle: FontStyle.normal,
              textDecoration: TextDecoration.none,
            ));

    final root = parser.parse(markdown);

    final document = targetDocument ?? PdfDocument();
    final builder =
        PdfBuilder(root: root, document: document, tagStyle: tagStyle);

    await builder.build();

    final List<int> bytes = await document.save();

    // Dispose only if we created it
    if (targetDocument == null) {
      document.dispose();
    }

    return Uint8List.fromList(bytes);
  }
}
