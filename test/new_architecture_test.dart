import 'dart:io';

import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:htmltopdfwidgets/src/browser/css_style.dart';
import 'package:htmltopdfwidgets/src/browser/html_parser.dart';
import 'package:htmltopdfwidgets/src/browser/pdf_builder.dart';
import 'package:htmltopdfwidgets/src/browser/render_node.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart'; // For EdgeInsets
import 'package:test/test.dart';

void main() {
  group('CSSStyle Tests', () {
    test('Parse simple CSS string', () {
      final style = CSSStyle.parse('color: red; font-size: 16px;');
      expect(style.color, PdfColors.red);
      expect(style.fontSize, 16.0);
    });

    test('Parse complex CSS string with shorthand', () {
      final style = CSSStyle.parse('margin: 10px 20px; padding: 5px;');
      expect(style.margin!.top, 10.0);
      expect(style.margin!.left, 20.0);
      expect(style.padding!.top, 5.0);
      expect(style.padding!.left, 5.0);
    });

    test('Merge styles', () {
      final style1 = const CSSStyle(color: PdfColors.red, fontSize: 12.0);
      final style2 = const CSSStyle(color: PdfColors.blue);
      final merged = style1.merge(style2);
      expect(merged.color, PdfColors.blue);
      expect(merged.fontSize, 12.0);
    });

    test('Inherit styles', () {
      final parent = const CSSStyle(color: PdfColors.red, fontSize: 12.0, margin: EdgeInsets.all(10));
      final child = const CSSStyle().inheritFrom(parent);
      
      // Inherited properties
      expect(child.color, PdfColors.red);
      expect(child.fontSize, 12.0);
      
      // Non-inherited properties should be null/reset
      expect(child.margin, null);
    });
  });

  group('HtmlParser Tests', () {
    test('Parse simple HTML structure', () {
      final parser = HtmlParser(htmlString: '<div><p>Hello</p></div>');
      final root = parser.parse();
      
      expect(root.tagName, 'body'); // Parser wraps in body if missing
      expect(root.children.length, 1);
      expect(root.children[0].tagName, 'div');
      expect(root.children[0].children[0].tagName, 'p');
      expect(root.children[0].children[0].children[0].text, 'Hello');
    });

    test('Compute styles correctly', () {
      final parser = HtmlParser(htmlString: '<div style="color: red;"><p>Text</p></div>');
      final root = parser.parse();
      final div = root.children[0];
      final p = div.children[0];
      
      expect(div.style.color, PdfColors.red);
      expect(p.style.color, PdfColors.red); // Inherited
    });

    test('Parse attributes', () {
      final parser = HtmlParser(htmlString: '<a href="https://example.com">Link</a>');
      final root = parser.parse();
      final a = root.children[0];
      
      expect(a.attributes['href'], 'https://example.com');
    });
  });

  group('PdfBuilder Integration Tests', () {
    late pw.Document pdf;

    setUp(() {
      pdf = pw.Document();
    });

    test('Build PDF with basic elements', () async {
      const html = '''
        <h1>Heading</h1>
        <p>Paragraph with <b>bold</b> and <i>italic</i> text.</p>
      ''';
      final widgets = await HTMLToPdf().convert(html, useNewEngine: true);

      expect(widgets.isNotEmpty, true);
      pdf.addPage(pw.MultiPage(build: (c) => widgets));
    });

    test('Build PDF with lists', () async {
      const html = '''
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
        <ol>
          <li>Ordered 1</li>
          <li>Ordered 2</li>
        </ol>
      ''';
      final widgets = await HTMLToPdf().convert(html, useNewEngine: true);

      expect(widgets.isNotEmpty, true);
      pdf.addPage(pw.MultiPage(build: (c) => widgets));
    });

    test('Build PDF with table', () async {
      const html = '''
        <table style="border: 1px solid black;">
          <tr>
            <th>Header 1</th>
            <th>Header 2</th>
          </tr>
          <tr>
            <td>Cell 1</td>
            <td>Cell 2</td>
          </tr>
        </table>
      ''';
      final widgets = await HTMLToPdf().convert(html, useNewEngine: true);

      expect(widgets.isNotEmpty, true);
      pdf.addPage(pw.MultiPage(build: (c) => widgets));
    });

    test('Build PDF with image and link', () async {
      const html = '''
        <img src="https://example.com/image.png" style="width: 100px; height: 100px;" />
        <a href="https://example.com">Click me</a>
      ''';
      final widgets = await HTMLToPdf().convert(html, useNewEngine: true);

      expect(widgets.isNotEmpty, true);
      pdf.addPage(pw.MultiPage(build: (c) => widgets));
    });

    tearDownAll(() async {
      final file = File('new_architecture_test_output.pdf');
      await file.writeAsBytes(await pdf.save());
      print('Test PDF saved to ${file.path}');
    });
  });
}
