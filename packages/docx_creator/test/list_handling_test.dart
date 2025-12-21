import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('List Handling', () {
    test('Single bullet list is registered in numbering.xml', () async {
      final doc = docx().bullet(['Item 1', 'Item 2', 'Item 3']).build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find numbering.xml
      final numberingFile = archive.files.firstWhere(
        (f) => f.name == 'word/numbering.xml',
      );
      final numberingXml = String.fromCharCodes(numberingFile.content);

      // Should have at least one w:num element for the list
      expect(numberingXml, contains('<w:num w:numId="1">'));
      expect(numberingXml, contains('<w:abstractNumId w:val="0"/>'));
    });

    test('Single numbered list is registered in numbering.xml', () async {
      final doc = docx().numbered(['Step 1', 'Step 2', 'Step 3']).build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final numberingFile = archive.files.firstWhere(
        (f) => f.name == 'word/numbering.xml',
      );
      final numberingXml = String.fromCharCodes(numberingFile.content);

      // Numbered list uses abstractNumId=1
      expect(numberingXml, contains('<w:num w:numId="1">'));
      expect(numberingXml, contains('<w:abstractNumId w:val="1"/>'));
    });

    test('Multiple lists get separate numIds', () async {
      final doc = docx()
          .bullet(['Bullet 1', 'Bullet 2'])
          .p('Some text in between')
          .numbered(['Number 1', 'Number 2'])
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final numberingFile = archive.files.firstWhere(
        (f) => f.name == 'word/numbering.xml',
      );
      final numberingXml = String.fromCharCodes(numberingFile.content);

      // Should have two separate w:num elements
      expect(numberingXml, contains('<w:num w:numId="1">'));
      expect(numberingXml, contains('<w:num w:numId="2">'));
    });

    test('Nested bullet list from HTML', () async {
      final html = '''
        <ul>
          <li>Level 0 - Item 1</li>
          <li>Level 0 - Item 2
            <ul>
              <li>Level 1 - Nested 1</li>
              <li>Level 1 - Nested 2</li>
            </ul>
          </li>
          <li>Level 0 - Item 3</li>
        </ul>
      ''';

      final nodes = await DocxParser.fromHtml(html);
      expect(nodes.length, 1);
      expect(nodes.first, isA<DocxList>());

      final list = nodes.first as DocxList;
      expect(list.items.length, greaterThanOrEqualTo(3));

      // Check levels
      expect(list.items[0].level, 0);
      // Nested items should have level 1
      final nestedItems = list.items.where((item) => item.level == 1);
      expect(nestedItems, isNotEmpty);
    });

    test('Nested numbered list from HTML', () async {
      final html = '''
        <ol>
          <li>First
            <ol>
              <li>First-A</li>
              <li>First-B</li>
            </ol>
          </li>
          <li>Second</li>
        </ol>
      ''';

      final nodes = await DocxParser.fromHtml(html);
      expect(nodes.first, isA<DocxList>());

      final list = nodes.first as DocxList;
      expect(list.isOrdered, true);

      // Should have nested items with level > 0
      final hasNestedItems = list.items.any((item) => item.level > 0);
      expect(hasNestedItems, true);
    });

    test('Document.xml contains correct numPr for list items', () async {
      final doc = docx().bullet(['Item 1', 'Item 2']).build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
      );
      final documentXml = String.fromCharCodes(documentFile.content);

      // List items should have numPr with ilvl and numId
      expect(documentXml, contains('<w:numPr>'));
      expect(documentXml, contains('<w:ilvl w:val="0"/>'));
      expect(documentXml, contains('<w:numId w:val="1"/>'));
    });

    test('Abstract numbering has 9 levels', () async {
      final doc = docx().bullet(['Item']).build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final numberingFile = archive.files.firstWhere(
        (f) => f.name == 'word/numbering.xml',
      );
      final numberingXml = String.fromCharCodes(numberingFile.content);

      // Should have levels 0-8 defined
      for (int i = 0; i < 9; i++) {
        expect(numberingXml, contains('w:ilvl="$i"'));
      }
    });

    test('Lists inside table cells are collected', () async {
      final doc = DocxDocumentBuilder()
          .addTable(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(children: [
                DocxList.bullet(['Cell list item 1', 'Cell list item 2']),
              ]),
            ]),
          ]))
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final numberingFile = archive.files.firstWhere(
        (f) => f.name == 'word/numbering.xml',
      );
      final numberingXml = String.fromCharCodes(numberingFile.content);

      // List in table cell should be registered
      expect(numberingXml, contains('<w:num w:numId="1">'));
    });
  });
}
