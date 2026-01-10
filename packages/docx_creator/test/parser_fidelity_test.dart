import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/inline_parser.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/table_parser.dart';
import 'package:docx_creator/src/reader/docx_reader/reader_context/reader_context.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Nested Table and Spacing Fidelity', () {
    test('TableParser parses w:sdt (content control) inside cells', () {
      // XML mimicking a cell with a content control containing a paragraph
      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tr>
            <w:tc>
              <w:sdt>
                <w:sdtContent>
                  <w:p>
                    <w:r><w:t>Three</w:t></w:r>
                  </w:p>
                </w:sdtContent>
              </w:sdt>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final context = ReaderContext(Archive());
      final parser = TableParser(context, InlineParser(context));
      final table = parser.parse(xml.rootElement);

      final cell = table.rows.first.cells.first;
      // Should contain 1 paragraph, but currently might be empty if sdt is skipped
      expect(cell.children.length, 1, reason: 'SDT content should be parsed');
      expect(
          ((cell.children.first as DocxParagraph).children.first as DocxText)
              .content,
          'Three');
    });

    test('TableParser parses multiple paragraphs in a single cell', () {
      // This mimics the demo.docx structure with "One" and "Three" in same cell
      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tr>
            <w:tc>
              <w:tcPr>
                <w:vMerge w:val="restart"/>
              </w:tcPr>
              <w:p><w:r><w:t>One</w:t></w:r></w:p>
              <w:p><w:r><w:t>Three</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:p><w:r><w:t>Two</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final context = ReaderContext(Archive());
      final parser = TableParser(context, InlineParser(context));
      final table = parser.parse(xml.rootElement);

      final cell = table.rows.first.cells.first;
      // Should contain 2 paragraphs - both "One" AND "Three"
      expect(cell.children.length, 2, reason: 'Cell should have 2 paragraphs');
      expect(
          ((cell.children[0] as DocxParagraph).children.first as DocxText)
              .content,
          'One');
      expect(
          ((cell.children[1] as DocxParagraph).children.first as DocxText)
              .content,
          'Three');
    });

    test('InlineParser preserves spaces in w:t with xml:space="preserve"', () {
      final xml = XmlDocument.parse('''
        <w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:t xml:space="preserve"> Footnotes </w:t>
        </w:r>
      ''');

      final context = ReaderContext(Archive());
      final parser = InlineParser(context);
      final run = parser.parseRun(xml.rootElement);

      expect((run as DocxText).content, ' Footnotes ');
    });
  });
}
