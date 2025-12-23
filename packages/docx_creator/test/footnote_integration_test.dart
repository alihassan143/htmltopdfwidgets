import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('Footnote/Endnote Integration Tests', () {
    test('Can create and export document with footnotes and endnotes',
        () async {
      final doc = docx()
          .p('Paragraph with footnote.')
          .addFootnote(DocxFootnote(
            footnoteId: 1,
            content: [DocxParagraph.text('This is the footnote content.')],
          ))
          .p('Paragraph with endnote.')
          .addEndnote(DocxEndnote(
            endnoteId: 1,
            content: [DocxParagraph.text('This is the endnote content.')],
          ))
          .build();

      expect(doc.footnotes, hasLength(1));
      expect(doc.endnotes, hasLength(1));

      // Export to bytes
      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);

      // Verify footnotes populated
      expect(readDoc.footnotes, isNotNull);
      expect(readDoc.footnotes!.length, 1);
      final footnote = readDoc.footnotes!.first;
      expect(footnote.footnoteId, 1);
      expect(footnote.content.length, 1);

      final p1 = footnote.content.first as DocxParagraph;
      expect(p1.children.length, 1);
      expect((p1.children.first as DocxText).content,
          'This is the footnote content.');

      // Verify endnotes populated
      expect(readDoc.endnotes, isNotNull);
      expect(readDoc.endnotes!.length, 1);
      final endnote = readDoc.endnotes!.first;
      expect(endnote.endnoteId, 1);
      expect(endnote.content.length, 1);

      final p2 = endnote.content.first as DocxParagraph;
      expect(p2.children.length, 1);
      expect((p2.children.first as DocxText).content,
          'This is the endnote content.');
    });

    test('Prioritizes object list over raw XML during export', () async {
      final doc = DocxBuiltDocument(
        elements: [],
        footnotes: [
          DocxFootnote(
              footnoteId: 1, content: [DocxParagraph.text('Object Content')])
        ],
        footnotesXml:
            '<w:footnotes><w:footnote w:id="2"><w:p><w:r><w:t>XML Content</w:t></w:r></w:p></w:footnote></w:footnotes>',
      );

      final bytes = await DocxExporter().exportToBytes(doc);
      final readDoc = await DocxReader.loadFromBytes(bytes);

      // Should have ID 1 (from object), not ID 2 (from XML)
      expect(readDoc.footnotes!.first.footnoteId, 1);

      final p3 = readDoc.footnotes!.first.content.first as DocxParagraph;
      expect(p3.children.length, 1);
      expect((p3.children.first as DocxText).content, 'Object Content');
    });
  });
}
