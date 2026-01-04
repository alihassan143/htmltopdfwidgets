import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/table_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock ParagraphBuilder
class MockParagraphBuilder extends ParagraphBuilder {
  MockParagraphBuilder()
      : super(
          config: const DocxViewConfig(),
          theme: DocxViewTheme.light(),
        );

  @override
  Widget build(DocxParagraph paragraph, {int? blockIndex}) {
    return const Text('Paragraph');
  }
}

void main() {
  testWidgets('TableBuilder creates basic table', (WidgetTester tester) async {
    final builder = TableBuilder(
      theme: DocxViewTheme.light(),
      config: const DocxViewConfig(),
      paragraphBuilder: MockParagraphBuilder(),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 1'),
          DocxTableCell.text('Cell 2'),
        ]),
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 3'),
          DocxTableCell.text('Cell 4'),
        ]),
      ],
      gridColumns: [1000, 1000], // Twips
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    expect(find.byType(Column), findsWidgets);
    expect(find.text('Paragraph'), findsNWidgets(4));
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('TableBuilder handles gridSpan', (WidgetTester tester) async {
    final builder = TableBuilder(
      theme: DocxViewTheme.light(),
      config: const DocxViewConfig(),
      paragraphBuilder: MockParagraphBuilder(),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          // Span 2 columns
          DocxTableCell(
            children: [
              DocxParagraph(children: [DocxText('Spanned')])
            ],
            colSpan: 2,
          ),
        ]),
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 3'),
          DocxTableCell.text('Cell 4'),
        ]),
      ],
      gridColumns: [1000, 1000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    expect(find.text('Paragraph'), findsNWidgets(3));
  });

  testWidgets('TableBuilder handles vertical merge',
      (WidgetTester tester) async {
    final builder = TableBuilder(
      theme: DocxViewTheme.light(),
      config: const DocxViewConfig(),
      paragraphBuilder: MockParagraphBuilder(),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          // Row 1, Col 1: Start merge (rowSpan=2)
          DocxTableCell(
            children: [
              DocxParagraph(children: [DocxText('Merged')])
            ],
            rowSpan: 2,
          ),
          DocxTableCell.text('R1C2'),
        ]),
        DocxTableRow(cells: [
          // Row 2, Col 1: Omitted (skipped)
          DocxTableCell.text('R2C2'),
        ]),
      ],
      gridColumns: [1000, 1000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    // We expect 3 paragraphs
    expect(find.text('Paragraph'), findsNWidgets(3));
  });
}
