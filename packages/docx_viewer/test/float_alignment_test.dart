import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:docx_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParagraphBuilder Float Alignment', () {
    testWidgets(
        'Combines Text + Right Floating Image (After Text) in single Row',
        (tester) async {
      // User Scenario: Text first, then Right-aligned floating image.
      // Expected: Single Row, with text on left and image on right.

      final image = DocxInlineImage(
        bytes: _createGradientImage(),
        extension: 'png',
        width: 50,
        height: 50,
        positionMode: DocxDrawingPosition.floating,
        hAlign: DrawingHAlign.right,
      );

      final paragraph = DocxParagraph(
        children: [
          DocxText('Main content text that should be beside the image.'),
          image,
        ],
      );

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
        docxTheme: DocxTheme.empty(),
      );

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: builder.build(paragraph))));

      // 1. Should be exactly ONE Row (no splitting into multiple rows)
      // If it splits, we'd likely get a Column with 2 items (Text, then Image Row) or 2 Rows.
      // ParagraphBuilder wraps content in a Column of blocks if multiple blocks exist.
      // We want to ensure we have ONE Row that contains both elements.

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget,
          reason: 'Text and Right Float should merge into one Row');

      final row = tester.widget<Row>(rowFinder);

      // 2. Verify Row structure:
      // [LeftFloats?, Expanded(Text), Spacer?, RightFloats(Column)]
      // The implementation of _buildFloatingLayout usually puts right elements last.

      expect(row.children.length, greaterThanOrEqualTo(2));

      // Use helper to find text and image inside the row
      final textInRow =
          find.descendant(of: rowFinder, matching: find.byType(RichText));
      final imageInRow =
          find.descendant(of: rowFinder, matching: find.byType(Image));

      expect(textInRow, findsOneWidget, reason: 'Text should be in the row');
      expect(imageInRow, findsOneWidget, reason: 'Image should be in the row');
    });

    testWidgets(
        'Combines Text + Left Floating Image (After Text) in single Row',
        (tester) async {
      final image = DocxInlineImage(
        bytes: _createGradientImage(),
        extension: 'png',
        width: 50,
        height: 50,
        positionMode: DocxDrawingPosition.floating,
        hAlign: DrawingHAlign.left,
      );

      final paragraph = DocxParagraph(
        children: [
          DocxText('Text content.'),
          image,
        ],
      );

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
        docxTheme: DocxTheme.empty(),
      );

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: builder.build(paragraph))));

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget,
          reason: 'Text and Left Float should merge into one Row');

      final row = tester.widget<Row>(rowFinder);
      // Structure: LeftFloats(Column), Spacer?, Expanded(Text)
      // We can iterate children to verify order if we want, but finding both inside is good enough for now.

      final textInRow =
          find.descendant(of: rowFinder, matching: find.byType(RichText));
      final imageInRow =
          find.descendant(of: rowFinder, matching: find.byType(Image));

      expect(textInRow, findsOneWidget);
      expect(imageInRow, findsOneWidget);
    });
  });
}

Uint8List _createGradientImage() {
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
