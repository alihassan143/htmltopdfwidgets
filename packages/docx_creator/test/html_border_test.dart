import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlParser Borders', () {
    test('parses paragraph borders', () async {
      final html =
          '<p style="border-bottom: 1px solid red; border-top: 2px dashed blue">Hello</p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final p = nodes.first as DocxParagraph;

      expect(p.borderBottomSide, isNotNull,
          reason: 'Border bottom should be parsed');
      expect(p.borderBottomSide!.style, DocxBorder.single);
      expect(p.borderBottomSide!.color.hex, 'FF0000');

      expect(p.borderTop, isNotNull, reason: 'Border top should be parsed');
      expect(p.borderTop!.style, DocxBorder.dashed);
      expect(p.borderTop!.color.hex, '0000FF');
    });

    test('parses div borders', () async {
      final html = '<div style="border: 1px solid black">Content</div>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final p = nodes.first as DocxParagraph;

      expect(p.borderTop, isNotNull);
      expect(p.borderBottomSide, isNotNull);
      expect(p.borderLeft, isNotNull);
      expect(p.borderRight, isNotNull);

      expect(p.borderTop!.style, DocxBorder.single);
    });

    test('parses table borders from style', () async {
      final html =
          '<table style="border: 2px double green"><tr><td>Cell</td></tr></table>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final table = nodes.first as DocxTable;

      expect(table.style.borderTop, isNotNull);
      expect(table.style.borderTop!.style, DocxBorder.double);
      expect(table.style.borderTop!.color.hex, '008000');
    });

    test('parses cell borders from style', () async {
      final html =
          '<table><tr><td style="border-right: 1px dotted orange">Cell</td></tr></table>';
      final nodes = await DocxParser.fromHtml(html);

      final table = nodes.first as DocxTable;
      final cell = table.rows.first.cells.first;

      expect(cell.borderRight, isNotNull);
      expect(cell.borderRight!.style, DocxBorder.dotted);
      expect(cell.borderRight!.color.hex, 'FFA500');
    });
  });
}
