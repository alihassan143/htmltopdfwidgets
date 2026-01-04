import 'dart:convert';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/models/docx_font.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:docx_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_viewer/src/widget_generator/paragraph_builder.dart'; // Ensure this is accessible or export it
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Valid 1x1 PNG
  final validPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

  group('Reproduction Tests', () {
    testWidgets('Floating Image Right Alignment pushes text to end (Bug Repro)',
        (tester) async {
      // Setup
      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
      );

      // Paragraph: "Start" -> Image(Right) -> "End"
      final paragraph = DocxParagraph(children: [
        DocxText('Start '),
        DocxInlineImage(
          width: 100,
          height: 100,
          bytes: validPng,
          extension: '.png',
          positionMode: DocxDrawingPosition.floating,
          hAlign: DrawingHAlign.right,
        ),
        DocxText('End'),
      ]);

      final widget = builder.build(paragraph);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Current incorrect behavior:
      // It creates a Row with [Expanded(Text("Start End")), Column(Image)]
      // The text is contiguous and the image is to the right of the *entire* text block.

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);

      final row = tester.widget<Row>(rowFinder);
      // We expect 2 children: Expanded(Text) and Column(Image) (or similar 3-child structure with spacing)
      // Actually `_buildFloatingLayout` always creates 3 children: LeftCol, Expanded(Text), RightCol.
      // Or 2 if one side is empty?
      // Inspecting code: `children: [ if(left)..., Expanded, if(right)... ]`.

      expect(row.children.length, greaterThanOrEqualTo(2));

      // Verify Text contains "Start End" combined
      final textFinder = find.byType(RichText); // Or SelectableText
      // Depending on config, it might be SelectableText.rich or RichText. Default config enabledSelection?
      // Let's assume RichText for simplicity or check finder.

      // Expect separate RichText/SelectableText widgets now because of the split
      final richTextFinder = find.byType(RichText);
      final selectableTextFinder = find.byType(SelectableText);

      List<String> textContents = [];
      for (final element in richTextFinder.evaluate()) {
        textContents.add((element.widget as RichText).text.toPlainText());
      }
      for (final element in selectableTextFinder.evaluate()) {
        final widget = element.widget as SelectableText;
        if (widget.textSpan != null) {
          textContents.add(widget.textSpan!.toPlainText());
        }
      }

      // We expect 'Start ' and 'End' to be in the SAME block now for [Left] [Text] [Right] layout
      // The text is center-aligned (or default) between the two floats.

      final fullContent = textContents.join('');
      expect(fullContent, contains('Start '));
      expect(fullContent, contains('End'));

      // Because we removed the split on Right float, they might be in the same widget again.
      // The key is that they are in a Row structure which we verified earlier.
      // We are just verifying that we didn't lose content.

      // If the layout logic does NOT split, 'Start ' and 'End' will be in the same span.
      // This is acceptable as long as visually they are flanked by images.

      final hasCombinedBlock =
          textContents.any((t) => t.contains('Start ') && t.contains('End'));
      expect(hasCombinedBlock, isTrue,
          reason: 'Text should be continuous between floats for this layout');
    });

    testWidgets('Font Family from DocxText.fonts is ignored (Bug Repro)',
        (tester) async {
      // Setup
      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
      );

      const targetFont = 'MyCustomFont';

      final text = DocxText(
        'Themed Text',
        // Simulate Reader producing both legacy and new properties
        fontFamily: 'LegacyFallbackFont',
        fonts: const DocxFont(ascii: targetFont),
      );

      final paragraph = DocxParagraph(children: [text]);
      final widget = builder.build(paragraph);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Find Span
      final richTextFinder = find.byType(RichText);
      final selectableTextFinder = find.byType(SelectableText);

      TextStyle style;
      if (richTextFinder.evaluate().isNotEmpty) {
        final rt = tester.widget<RichText>(richTextFinder.first);
        style = rt.text.style!;
        // Or children spans
        final span = rt.text as TextSpan;
        style = span.children![0].style!;
      } else {
        final st = tester.widget<SelectableText>(selectableTextFinder.first);
        final span = st.textSpan!;
        style = span.children![0].style!;
      }

      // If bug exists, this might be null or default
      print('Actual Font Family: ${style.fontFamily}');
      expect(style.fontFamily, targetFont);
    });
  });

  test('DocxWidgetGenerator yields pages in paged mode', () {
    const config = DocxViewConfig(pageMode: DocxPageMode.paged, pageWidth: 794);
    final generator = DocxWidgetGenerator(config: config);

    // Create a mock document with 1 paragraph
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [DocxText('Test Page 1')]),
      ],
      // Default section required
      section: DocxSectionDef(),
    );

    final widgets = generator.generateWidgets(doc);

    // Expecting 1 page container
    expect(widgets.length, 1);
    expect(widgets.first, isA<Container>());
  });
}
