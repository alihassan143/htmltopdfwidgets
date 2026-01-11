import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

class MockReaderContext extends ReaderContext {
  MockReaderContext() : super(Archive());

  @override
  DocxStyle resolveStyle(String? styleId) {
    if (styleId == 'TestTableStyle') {
      return DocxStyle(
        id: 'TestTableStyle',
        shadingFill: '#ABCDEF',
        themeFill: 'accent1',
        borderTop: const DocxBorderSide(color: DocxColor.red, size: 12),
      );
    }
    if (styleId == 'TestParaStyle') {
      return DocxStyle(
        id: 'TestParaStyle',
        fontSize: 24, // 12pt
        fonts: const DocxFont(ascii: 'Arial'),
      );
    }
    return super.resolveStyle(styleId);
  }
}

void main() {
  group('Rendering Fidelity', () {
    test('TableParser inherits styles', () {
      final context = MockReaderContext();
      final inlineParser = InlineParser(context);
      final parser = TableParser(context, inlineParser);

      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tblPr>
            <w:tblStyle w:val="TestTableStyle"/>
          </w:tblPr>
          <w:tr>
            <w:tc>
              <w:tcPr>
                 <!-- No override, should inherit -->
              </w:tcPr>
              <w:p/>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final table = parser.parse(xml.rootElement);
      final cell = table.rows.first.cells.first;

      // Check inheritance
      expect(cell.shadingFill, '#ABCDEF', reason: 'Should inherit shading');
      expect(cell.themeFill, 'accent1', reason: 'Should inherit theme fill');
      expect(cell.borderTop?.color.hex, 'FF0000',
          reason: 'Should inherit border color');
    });

    test('InlineParser inherits fonts from paragraph style', () {
      final context = MockReaderContext();
      final parser = InlineParser(context);

      final paraStyle = context.resolveStyle('TestParaStyle');

      final xml = XmlDocument.parse('''
        <w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:t>Hello</w:t>
        </w:r>
      ''');

      final run =
          parser.parseRun(xml.rootElement, parentStyle: paraStyle) as DocxText;

      expect(run.fontSize, 24, reason: 'Should inherit font size');
      expect(run.fontFamily, 'Arial', reason: 'Should inherit font family');
    });

    testWidgets('ParagraphBuilder renders centered floating image',
        (tester) async {
      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
      );

      final image = DocxInlineImage(
        bytes: _createValidHeaderGif(),
        positionMode: DocxDrawingPosition.floating,
        hAlign: DrawingHAlign.center,
        extension: 'png',
      );

      final paragraph = DocxParagraph(
        children: [image, DocxText('Ref text')],
      );

      final widget = builder.build(paragraph);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Search for the centered column created for centered floating element
      // ParagraphBuilder creates: Column([Widget(Text), Center(Column([Image]))])
      // No, my implementation was: Column([contentWidget, space, image, space]) with CrossAxisAlignment.center

      final centerFinder = find.byType(Center);
      expect(centerFinder, findsOneWidget,
          reason: 'Should find a Center widget for floating image');

      expect(
        find.descendant(of: centerFinder, matching: find.byType(Image)),
        findsOneWidget,
        reason: 'Image should be inside Center',
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ParagraphBuilder renders side floating images in Row',
        (tester) async {
      // Arrange
      final image = DocxInlineImage(
        bytes: _createValidHeaderGif(),
        extension: 'gif',
        width: 100,
        height: 100,
        positionMode: DocxDrawingPosition.floating,
        hAlign: DrawingHAlign.left, // Left align
      );

      final paragraph = DocxParagraph(
        children: [
          DocxText('Side text'),
          image,
        ],
      );

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
        docxTheme: DocxTheme.empty(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build(paragraph),
          ),
        ),
      );

      // Assert
      // Should find a Row containing the image and the text
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Side text'), findsOneWidget);

      // Verify structure: Image should be first child of Row (for left align)
      final rowFinder = find.byType(Row);
      final rowWidget = tester.widget<Row>(rowFinder);
      expect(rowWidget.children.length, greaterThanOrEqualTo(2));
      expect(rowWidget.children[0], isA<Column>()); // Image wrapped in Column
      expect(
          find.descendant(
              of: find.byWidget(rowWidget.children[0]),
              matching: find.byType(Image)),
          findsOneWidget);
    });
  });
}

Uint8List _createValidHeaderGif() {
  return Uint8List.fromList([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF89a
    0x01, 0x00, 0x01, 0x00, // 1x1 dimensions
    0x80, 0x00, 0x00, // Global Color Table Flag
    0xff, 0xff, 0xff, // White
    0x00, 0x00, 0x00, // Black
    0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, // Graphic Control Extension
    0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, // Image Descriptor
    0x02, 0x02, 0x44, 0x01, 0x00, 0x3b // Image Data + Terminator
  ]);
}
