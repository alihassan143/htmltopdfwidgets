import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
// Internal imports
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/table_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TableBuilder Theme Rendering', () {
    late TableBuilder tableBuilder;
    late DocxTheme docxTheme;
    late ParagraphBuilder paragraphBuilder;

    setUp(() {
      final config = const DocxViewConfig();
      final theme = DocxViewTheme.light();

      paragraphBuilder = ParagraphBuilder(
        theme: theme,
        config: config,
      );

      // Define a theme with accent1 = Red (FF0000)
      docxTheme = const DocxTheme(
        colors: DocxThemeColors(
          accent1: 'FF0000', // Red
          accent2: '00FF00', // Green
        ),
      );

      tableBuilder = TableBuilder(
        theme: theme,
        config: config,
        paragraphBuilder: paragraphBuilder,
        docxTheme: docxTheme,
      );
    });

    testWidgets('resolves themeFill "accent1" correctly', (tester) async {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(
              children: [],
              themeFill: 'accent1',
              // No tint/shade
            ),
          ]),
        ],
      );

      final widget = tableBuilder.build(table);
      await tester.pumpWidget(MaterialApp(home: widget));

      // Find the Container with the decoration
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, const Color(0xFFFF0000));
    });

    testWidgets('resolves themeFill with Tint (lighter)', (tester) async {
      // Hex '80' = 128 = ~50%
      // 50% tint -> Lighter than red
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(
              children: [],
              themeFill: 'accent1',
              themeFillTint: '80',
            ),
          ]),
        ],
      );

      final widget = tableBuilder.build(table);
      await tester.pumpWidget(MaterialApp(home: widget));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;

      // Should be lighter than red (FF0000)
      // Should be lighter than red (FF0000)
      final color = decoration.color!;
      expect((color.r * 255).round(), greaterThan(200));
      expect((color.g * 255).round(), greaterThan(0)); // Whiteness added
      expect((color.b * 255).round(), greaterThan(0)); // Whiteness added
    });

    testWidgets('resolves themeFill with Shade (darker)', (tester) async {
      // Hex '80' = 128 = ~50%
      // 50% shade -> Darker than red
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(
              children: [],
              themeFill: 'accent1',
              themeFillShade: '80',
            ),
          ]),
        ],
      );

      final widget = tableBuilder.build(table);
      await tester.pumpWidget(MaterialApp(home: widget));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;

      // Should be darker than red
      final color = decoration.color!;
      expect((color.r * 255).round(), lessThan(255)); // Darker
      expect((color.r * 255).round(), greaterThan(0));
      expect((color.g * 255).round(), 0);
      expect((color.b * 255).round(), 0);
    });
  });
}
