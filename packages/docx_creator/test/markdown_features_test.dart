import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('Markdown Features', () {
    test('Rich Text Heading', () async {
      final md = '# Heading with **Bold**';
      final nodes = await MarkdownParser.parse(md);

      expect(nodes.length, 1);
      final h1 = nodes.first as DocxParagraph;
      expect(h1.styleId, 'Heading1');
      expect(h1.children.length, 2);
      expect((h1.children[0] as DocxText).content, 'Heading with ');
      expect((h1.children[1] as DocxText).content, 'Bold');
      expect((h1.children[1] as DocxText).fontWeight, DocxFontWeight.bold);
    });

    test('Blockquote with rich text', () async {
      final md = '> Quote with *Italic*';
      final nodes = await MarkdownParser.parse(md);

      expect(nodes.length, 1);
      final quote = nodes.first as DocxParagraph;
      expect(quote.styleId, 'Quote');
      expect(quote.indentLeft, 720);
      expect(quote.children.length, 2);
      expect((quote.children[1] as DocxText).content, 'Italic');
      expect((quote.children[1] as DocxText).fontStyle, DocxFontStyle.italic);
    });

    test('Task List', () async {
      final md = '- [x] Checked\n- [ ] Unchecked';
      final nodes = await MarkdownParser.parse(md);

      expect(nodes.length, 1);
      final list = nodes.first as DocxList;
      expect(list.items.length, 2);

      final item1 = list.items[0];
      final checkbox1 =
          item1.children.firstWhere((e) => e is DocxCheckbox) as DocxCheckbox;
      expect(checkbox1.isChecked, true);

      final item2 = list.items[1];
      final checkbox2 =
          item2.children.firstWhere((e) => e is DocxCheckbox) as DocxCheckbox;
      expect(checkbox2.isChecked, false);
    });

    test('Table parsing', () async {
      final md = '''
| Header 1 | Header 2 |
| --- | --- |
| Cell 1 | Cell 2 |
''';
      final nodes = await MarkdownParser.parse(md);

      expect(nodes.length, 1);
      final table = nodes.first as DocxTable;

      expect(table.rows.length, 2);

      final header = table.rows[0];
      // Header cells are text
      final headerCellP = header.cells[0].children[0] as DocxParagraph;
      final headerCellText = headerCellP.children[0] as DocxText;

      expect(headerCellText.content, 'Header 1');
      expect(headerCellText.fontWeight, DocxFontWeight.bold);
      expect(header.cells[0].shadingFill, 'E0E0E0');

      final row1 = table.rows[1];
      final row1CellP = row1.cells[0].children[0] as DocxParagraph;
      final row1CellText = row1CellP.children[0] as DocxText;

      expect(row1CellText.content, 'Cell 1');
      expect(row1CellText.fontWeight, DocxFontWeight.normal);
    });
  });
}
