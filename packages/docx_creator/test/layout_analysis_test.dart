import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('Layout Analysis Tests', () {
    test('Headings Recognition', () async {
      // 1. Create Docx with Headings
      final doc = DocxBuiltDocument(
        elements: [
          DocxParagraph(
            children: [DocxText('Title H1')],
            styleId: 'Heading1',
          ),
          DocxParagraph(
            children: [DocxText('Subtitle H2')],
            styleId: 'Heading2',
          ),
          DocxParagraph(
            children: [DocxText('Normal Text')],
            styleId: 'Normal',
          ),
        ],
        section: DocxSectionDef(),
      );

      // 2. Export to PDF
      // Note: PdfExporter uses styleId to scale fonts: H1->24, H2->18, Normal->12
      final exporter = PdfExporter();
      final bytes = exporter.exportToBytes(doc);

      // 3. Read back with PdfReader
      final reader = await PdfReader.loadFromBytes(bytes);
      final readDoc = reader.toDocx();

      // 4. Verify
      expect(readDoc.elements.length, 3);

      // Check H1
      final p1 = readDoc.elements[0] as DocxParagraph;
      final t1 = p1.children.map((c) => (c as DocxText).content).join();
      expect(t1, 'Title H1');
      // Check font size of first child
      expect((p1.children[0] as DocxText).fontSize, greaterThanOrEqualTo(24));
      // PdfReader doesn't set styleId currently, but visual properties are preserved

      // Check H2
      final p2 = readDoc.elements[1] as DocxParagraph;
      final t2 = p2.children.map((c) => (c as DocxText).content).join();
      expect(t2, 'Subtitle H2');
      expect((p2.children[0] as DocxText).fontSize, greaterThanOrEqualTo(18));

      // Check Normal
      final p3 = readDoc.elements[2] as DocxParagraph;
      final t3 = p3.children.map((c) => (c as DocxText).content).join();
      expect(t3, 'Normal Text');
      expect((p3.children[0] as DocxText).fontSize, lessThan(16));
    });

    test('Paragraph Merging and Spacing', () async {
      // Create multi-line paragraph
      final doc = DocxBuiltDocument(
        elements: [
          DocxParagraph(
            children: [DocxText('Line 1 of paragraph. Line 2 of paragraph.')],
          ),
          DocxParagraph(
            children: [DocxText('Separate Paragraph.')],
          ),
        ],
        section: DocxSectionDef(),
      );

      final exporter = PdfExporter();
      final bytes = exporter.exportToBytes(doc);

      final reader = await PdfReader.loadFromBytes(bytes);
      final readDoc = reader.toDocx();

      // Just check that we got content.
      // Merging depends on Exporter's line wrapping.
      // If content is short, it won't wrap.
      // But we can check that "Separate Paragraph" is indeed separate.
      expect(readDoc.elements.length, greaterThanOrEqualTo(2));

      // Verify text content
      final text = reader.text;
      expect(text, contains('Line 1'));
      expect(text, contains('Separate Paragraph'));
    });

    test('Space Insertion', () async {
      // Create a paragraph with words
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText('Hello World')])
      ], section: DocxSectionDef());

      final exporter = PdfExporter();
      final bytes = exporter.exportToBytes(doc);

      final reader = await PdfReader.loadFromBytes(bytes);
      // Check that "Hello World" has a space, not "HelloWorld"
      final p = reader.elements.first as DocxParagraph;
      final fullText = (p.children[0] as DocxText).content;
      print(fullText);
      expect(fullText, equals('Hello'));
      // PdfExporter flows words separately?
      // Let's check logic. PdfExporter flows words.
      // It draws text word by word (or line by line).
      // PdfReader sees text chunks.
      // If PdfExporter draws "Hello" then "World", PdfReader needs to insert space.
      // If PdfExporter draws "Hello World" as one string, space is there.
      // PdfExporter `_flowWords` splits by space.
      // But `_renderParagraph` draws `word.text`.
      // IT DOES NOT DRAW SPACES EXPLICITLY as characters!
      // It draws "Hello" at X, then "World" at X + width + spaceWidth.
      // So the PDF stream has `(Hello) Tj ... (World) Tj`.
      // THERE IS NO SPACE CHARACTER IN THE PDF STREAM!
      // So `PdfReader` MUST insert the space based on gap.
      // This is the crucial test for my Space Insertion logic.

      // The test expectation:
      // PdfReader should reconstruct "Hello World" (or "Hello" " " "World").
      // DocxParagraph children joined.

      final joined = p.children.map((c) => (c as DocxText).content).join();
      expect(joined, contains('Hello World'));
      expect(joined, isNot(contains('HelloWorld')));
    });
  });
}
