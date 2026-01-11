import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

// Mock ReaderContext if needed, or just use a minimal one
class MockReaderContext extends ReaderContext {
  MockReaderContext() : super(Archive());
}

void main() {
  group('Theme Fills and Fonts', () {
    test('BlockParser extracting theme fills', () {
      final context = MockReaderContext();
      final parser = BlockParser(context);

      final xml = XmlDocument.parse('''
        <w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:pPr>
            <w:shd w:val="clear" w:color="auto" w:fill="auto" w:themeFill="accent1" w:themeFillTint="66"/>
          </w:pPr>
          <w:r>
            <w:t>Hello</w:t>
          </w:r>
        </w:p>
      ''');

      final paragraph = parser.parseParagraph(xml.rootElement);

      expect(paragraph.themeFill, 'accent1');
      expect(paragraph.themeFillTint, '66');
    });

    testWidgets('ParagraphBuilder resolving theme fonts', (tester) async {
      // 1. Create a DocxTheme with a majorAscii font
      final theme = DocxTheme(
        colors: const DocxThemeColors(),
        fonts: const DocxThemeFonts(majorLatin: 'MyThemeFont'),
      );

      // 2. Create a ParagraphBuilder
      // Note: ParagraphBuilder constructor isn't public? Or is it part of generator?
      // It is often internal. Let's check imports.
      // We can test ParagraphBuilder logic if it's accessible.
      // If not, we might need to test DocxWidgetGenerator or similar.
      // Assuming ParagraphBuilder is accessible from src/widget_generator/...

      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
        docxTheme: theme,
      );

      // 3. Create a DocxParagraph with a run using theme font
      final text = DocxText(
        'Themed Text',
        fonts: const DocxFont(asciiTheme: 'majorAscii'),
      );
      final paragraph = DocxParagraph(children: [text]);

      // 4. Build widget
      final widget = builder.build(paragraph);

      // 5. Verify widget structure (SelectableText.rich or RichText)
      // Since it returns a Widget, we pump it?
      // ParagraphBuilder.build returns a Widget (Padding containing SelectableText/RichText)

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Find TextSpan
      final finder = find.byType(SelectableText);
      expect(finder, findsOneWidget);

      final selectable = tester.widget<SelectableText>(finder);
      final span = selectable.textSpan!;
      // First child span
      final childSpan = span.children![0] as TextSpan;

      expect(childSpan.style?.fontFamily, 'MyThemeFont');
    });
  });
}
