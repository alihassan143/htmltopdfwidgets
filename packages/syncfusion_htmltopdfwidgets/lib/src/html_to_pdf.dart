import 'dart:async';

import 'package:flutter/material.dart'
    show FontWeight, FontStyle, TextDecoration;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'htmltagstyles.dart';
import 'parser/css_style.dart';
import 'parser/html_parser.dart';
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
  Future<void> convert(
    String html,
    PdfDocument document, {
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

    final builder =
        PdfBuilder(root: root, document: document, tagStyle: tagStyle);

    await builder.build();
  }
}
