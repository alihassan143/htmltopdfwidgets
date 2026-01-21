import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('List Enhancements', () {
    test('Continuity - List resumes numbering after interruption', () {
      final xml = XmlDocument.parse('''
        <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <!-- List 1, numId 1, items A, B -->
          <w:p>
            <w:pPr>
              <w:numPr>
                <w:numId w:val="1"/>
                <w:ilvl w:val="0"/>
              </w:numPr>
            </w:pPr>
            <w:r><w:t>A</w:t></w:r>
          </w:p>
          <w:p>
            <w:pPr>
              <w:numPr>
                <w:numId w:val="1"/>
                <w:ilvl w:val="0"/>
              </w:numPr>
            </w:pPr>
            <w:r><w:t>B</w:t></w:r>
          </w:p>

          <!-- Interruption -->
          <w:p>
            <w:r><w:t>Interruption</w:t></w:r>
          </w:p>

          <!-- List 1 Resumes, item C -->
          <w:p>
            <w:pPr>
              <w:numPr>
                <w:numId w:val="1"/>
                <w:ilvl w:val="0"/>
              </w:numPr>
            </w:pPr>
            <w:r><w:t>C</w:t></w:r>
          </w:p>
        </w:body>
      ''');

      final context = ReaderContext(Archive());
      final parser = BlockParser(context);
      final blocks = parser.parseBody(xml.rootElement);

      expect(blocks.length, 3); // List, Para, List

      final list1 = blocks[0] as DocxList;
      expect(list1.items.length, 2);
      expect(list1.startIndex, 1);

      final para = blocks[1];
      expect(para is DocxParagraph, true);

      final list2 = blocks[2] as DocxList;
      expect(list2.items.length, 1);
      expect(list2.startIndex, 3,
          reason: 'List 2 should start at 3 (after A, B)');
      expect(list2.numId, 1);
    });

    test('Hanging Indent Parsing', () {
      final xml = XmlDocument.parse('''
        <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p>
            <w:pPr>
              <w:ind w:left="720" w:hanging="360"/>
            </w:pPr>
            <w:r><w:t>Hanging</w:t></w:r>
          </w:p>
        </w:body>
      ''');

      final context = ReaderContext(Archive());
      final parser = BlockParser(context);
      final blocks = parser.parseBody(xml.rootElement);

      final p = blocks[0] as DocxParagraph;
      expect(p.indentLeft, 720);
      expect(p.indentFirstLine, -360,
          reason: 'hanging="360" should become indentFirstLine="-360"');
    });
  });
}
