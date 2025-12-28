import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_viewer/src/docx_view_config.dart';
import 'package:docx_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper to create valid GIF
Uint8List _createValidHeaderGif() {
  return Uint8List.fromList([
    0x47,
    0x49,
    0x46,
    0x38,
    0x39,
    0x61,
    0x01,
    0x00,
    0x01,
    0x00,
    0x80,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0xFF,
    0xFF,
    0xFF,
    0x21,
    0xF9,
    0x04,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x2C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x01,
    0x00,
    0x00,
    0x02,
    0x02,
    0x44,
    0x01,
    0x00,
    0x3B
  ]);
}

void main() {
  final validGifButtons = _createValidHeaderGif();

  testWidgets(
      'ListBuilder renders image bullet for ordered list with image style',
      (tester) async {
    final theme = DocxViewTheme.light();
    final config = const DocxViewConfig();

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        final pBuilder = ParagraphBuilder(theme: theme, config: config);
        final builder = ListBuilder(
          theme: theme,
          config: config,
          paragraphBuilder: pBuilder,
        );

        // Create a list technically marked as 'ordered' but with image bytes
        final list = DocxList(
          isOrdered: true,
          items: [
            DocxListItem.text("Item 1"),
          ],
          style: DocxListStyle(
            imageBulletBytes: validGifButtons,
            bullet: '',
          ),
        );

        return builder.build(list);
      }),
    ));

    await tester.pumpAndSettle();

    // Verify Image widget is present
    expect(find.byType(Image), findsOneWidget);
    // Verify it is not showing text marker "1."
    expect(find.text('1.'), findsNothing);
  });

  testWidgets(
      'DocxWidgetGenerator renders floating table in Row with constraints',
      (tester) async {
    final theme = DocxViewTheme.light();
    final config = const DocxViewConfig();

    // Setup: Table with floating position + following paragraph
    final table = const DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(children: [
            DocxParagraph(children: [DocxText("Cell")])
          ])
        ])
      ],
      position: DocxTablePosition(hAnchor: DocxTableHAnchor.text, tblpX: 0),
      alignment: DocxAlign.left,
    );

    final doc = DocxBuiltDocument(
      elements: [
        table,
        DocxParagraph(children: [DocxText("Following text")]),
      ],
      theme: null,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(builder: (context) {
            final generator = DocxWidgetGenerator(config: config, theme: theme);
            final widgets = generator.generateWidgets(doc);
            return Column(children: widgets);
          }),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Verify Row structure - Find the Row that is part of the float layout (contains Expanded/Flexible)
    // The inner table also has a Row, so we need to be specific.
    final floatRowFinder = find.descendant(
      of: find.byType(Padding),
      matching: find.byWidgetPredicate((widget) =>
          widget is Row && widget.children.any((c) => c is Expanded)),
    );

    expect(floatRowFinder, findsOneWidget);

    final row = tester.widget<Row>(floatRowFinder);
    expect(row.children.length, 3); // Table, Spacer, Text

    expect(row.children[0], isA<Flexible>());
    expect(row.children[2], isA<Expanded>()); // Text column
  });
}
