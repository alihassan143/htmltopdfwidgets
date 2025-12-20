import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

// Import the example translator
import '../example/document_translator.dart';

void main() {
  group('Translation Architecture Test', () {
    test('translates document content while preserving structure', () async {
      // 1. Create Source Document
      final doc = docx()
          .h1('Hello World')
          .add(DocxParagraph(children: [
            DocxText('This is a test paragraph with '),
            DocxText.bold('bold'),
            DocxText(' text.'),
          ]))
          .bullet(['Item 1', 'Item 2']).table([
        ['Header 1', 'Header 2'],
        ['Cell 1', 'Cell 2']
      ]).build();

      // 2. Initialize Translator with Mock Service
      final translator = DocumentTranslator(MockTranslationService());

      // 3. Perform Translation
      final translatedDoc = await translator.translateDocument(doc, 'ES');

      // 4. Verify Content Translation

      // H1
      final h1 = translatedDoc.elements[0] as DocxParagraph;
      expect((h1.children[0] as DocxText).content, '[ES] Hello World');

      // Paragraph
      final p = translatedDoc.elements[1] as DocxParagraph;
      // "This is a test paragraph with " (Normal)
      expect((p.children[0] as DocxText).content,
          '[ES] This is a test paragraph with ');
      // "bold" (Bold)
      expect((p.children[1] as DocxText).content, '[ES] bold');
      expect((p.children[1] as DocxText).isBold, true); // Structure preserved?
      // " text." (Normal)
      expect((p.children[2] as DocxText).content, '[ES]  text.');

      // List
      final list = translatedDoc.elements[2] as DocxList;
      expect((list.items[0].children[0] as DocxText).content, '[ES] Item 1');

      // Table
      final table = translatedDoc.elements[3] as DocxTable;
      final cell00 = table.rows[0].cells[0];
      final cellText =
          (cell00.children[0] as DocxParagraph).children[0] as DocxText;
      expect(cellText.content, '[ES] Header 1');

      // 5. Verify Structure Preservation (Exports successfully)
      final bytes = await DocxExporter().exportToBytes(translatedDoc);
      expect(bytes.isNotEmpty, true);
    });
  });
}
