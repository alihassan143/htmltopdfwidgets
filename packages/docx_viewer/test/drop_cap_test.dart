import 'package:docx_creator/docx_creator.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:docx_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_viewer/src/widgets/drop_cap_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DropCap Rendering', () {
    testWidgets('buildDropCap renders the drop cap letter', (tester) async {
      final dropCap = DocxDropCap(
        letter: 'D',
        lines: 3,
        restOfParagraph: [
          DocxText('rop caps are used to emphasize the leading paragraph.'),
        ],
      );

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(enableSelection: false),
        theme: DocxViewTheme.light(),
        docxTheme: DocxTheme.empty(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: builder.buildDropCap(dropCap),
            ),
          ),
        ),
      );

      // Debug: print the widget tree
      debugDumpApp();

      // Find the DropCapText widget
      final dropCapTextFinder = find.byType(DropCapText);
      expect(dropCapTextFinder, findsOneWidget,
          reason: 'Should find DropCapText widget');

      // Find DropCap widget (the custom widget with the letter)
      final dropCapWidgetFinder = find.byType(DropCap);
      expect(dropCapWidgetFinder, findsOneWidget,
          reason: 'Should find DropCap widget with the letter');

      // Find the Text widget containing "D"
      final letterFinder = find.text('D');
      expect(letterFinder, findsOneWidget,
          reason: 'Should find the letter D somewhere in the widget tree');

      // Find the text "rop caps" - search for RichText containing this text
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final hasRestOfParagraph =
          richTexts.any((rt) => rt.text.toPlainText().contains('rop caps'));
      expect(hasRestOfParagraph, isTrue,
          reason: 'Should find rest of paragraph text in RichText widgets');
    });
  });
}
