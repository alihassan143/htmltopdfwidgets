import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/parsers/inline_parser.dart';
import 'package:docx_creator/src/reader/parsers/table_parser.dart';
import 'package:docx_creator/src/reader/reader_context.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('TableParser Merge Tests', () {
    test('Vertical merge aligns correctly with mixed gridSpans', () {
      // Structure:
      // Row 1: [A] [B] [C (restart)]
      // Row 2: [D (span 2)] [E (continue)]
      // Expected: C merges with E. Resulting Row 2 has only D. Row 1 C has rowSpan 2.

      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tblGrid>
            <w:gridCol w:w="1000"/>
            <w:gridCol w:w="1000"/>
            <w:gridCol w:w="1000"/>
          </w:tblGrid>
          <w:tr>
            <w:tc>
              <w:tcPr><w:gridSpan w:val="1"/></w:tcPr>
              <w:p><w:r><w:t>A</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:tcPr><w:gridSpan w:val="1"/></w:tcPr>
              <w:p><w:r><w:t>B</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:gridSpan w:val="1"/>
                <w:vMerge w:val="restart"/>
              </w:tcPr>
              <w:p><w:r><w:t>C</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:tc>
              <w:tcPr><w:gridSpan w:val="2"/></w:tcPr>
              <w:p><w:r><w:t>D</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:gridSpan w:val="1"/>
                <w:vMerge w:val="continue"/>
              </w:tcPr>
              <w:p><w:r><w:t>E</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final context = ReaderContext(Archive());
      final parser = TableParser(context, InlineParser(context));
      final table = parser.parse(xml.rootElement);

      // Verify Row 1
      expect(table.rows[0].cells.length, 3);
      final cellC = table.rows[0].cells[2];
      expect(
          ((cellC.children.first as DocxParagraph).children.first as DocxText)
              .content,
          'C');
      expect(cellC.rowSpan, 2, reason: 'Cell C should span 2 rows');

      // Verify Row 2
      expect(table.rows[1].cells.length, 1,
          reason: 'Row 2 should only have Cell D (E is merged)');
      final cellD = table.rows[1].cells[0];
      expect(
          ((cellD.children.first as DocxParagraph).children.first as DocxText)
              .content,
          'D');
      expect(cellD.colSpan, 2, reason: 'Cell D should span 2 columns');
    });

    test('Standard rectangular merge works', () {
      // 2x2 grid, first column merged
      // R1C1 (restart), R1C2
      // R2C1 (continue), R2C2
      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tr>
            <w:tc>
              <w:tcPr><w:vMerge w:val="restart"/></w:tcPr>
              <w:p><w:r><w:t>1</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:p><w:r><w:t>2</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:tc>
              <w:tcPr><w:vMerge/></w:tcPr> <!-- Default continue -->
              <w:p><w:r><w:t>3</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:p><w:r><w:t>4</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final context = ReaderContext(Archive());
      final parser = TableParser(context, InlineParser(context));
      final table = parser.parse(xml.rootElement);

      expect(table.rows[0].cells[0].rowSpan, 2);
      expect(table.rows[1].cells.length, 1); // Only cell '4' remains
    });
  });
}
