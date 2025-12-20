import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxParser Async', () {
    test('parses base64 image', () async {
      // 1x1 pixel red dot PNG
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final html =
          '<img src="data:image/png;base64,$base64Png" width="100" height="100" alt="Red Dot">';

      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      expect(nodes.first, isA<DocxImage>());

      final img = nodes.first as DocxImage;
      expect(img.extension, 'png');
      expect(img.width, 100.0);
      expect(img.height, 100.0);
      expect(img.altText, 'Red Dot');
      expect(img.bytes, isNotEmpty);
    });

    test('ignores invalid base64 and falls back to placeholder', () async {
      final html = '<img src="data:image/png;base64,INVALID" alt="Broken">';

      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      expect(nodes.first, isA<DocxParagraph>());
      // Should contain link to the invalid src
      final para = nodes.first as DocxParagraph;
      expect(para.children.length, 3); // [📷, link, ]
    });
  });

  group('DocxParser Table Refactor', () {
    test('maintains row order (sequential traversal)', () async {
      final html = '''
        <table>
          <tr><td>Row 1</td></tr>
          <tr><td>Row 2</td></tr>
          <tr><td>Row 3</td></tr>
        </table>
      ''';

      final nodes = await DocxParser.fromHtml(html);
      expect(nodes.length, 1);
      expect(nodes.first, isA<DocxTable>());

      final table = nodes.first as DocxTable;
      expect(table.rows.length, 3);
      expect(
          ((table.rows[0].cells[0].children[0] as DocxParagraph).children[0]
                  as DocxText)
              .content,
          'Row 1');
      expect(
          ((table.rows[1].cells[0].children[0] as DocxParagraph).children[0]
                  as DocxText)
              .content,
          'Row 2');
      expect(
          ((table.rows[2].cells[0].children[0] as DocxParagraph).children[0]
                  as DocxText)
              .content,
          'Row 3');
    });

    test('handles nested tables without batched tr extraction issue', () async {
      // If we used querySelectorAll('tr') on the outer table, we'd get the inner row too
      // and potentially flatten it or count it twice.
      // With sequential traversal, the inner table is just content inside a cell.
      final html = '''
        <table>
          <tr>
            <td>
              Outer Row 1
              <table>
                <tr><td>Inner Row 1</td></tr>
              </table>
            </td>
          </tr>
          <tr><td>Outer Row 2</td></tr>
        </table>
      ''';

      final nodes = await DocxParser.fromHtml(html);
      final table = nodes.first as DocxTable;

      // Should have 2 rows, not 3 (outer rows only)
      expect(table.rows.length, 2);

      final firstCell = table.rows[0].cells[0];
      // The inner table should be nested in the first cell's children
      expect(
          firstCell.children.length, 2); // Text "Outer Row 1" paragraph + Table
      expect(firstCell.children[1], isA<DocxTable>());

      final innerTable = firstCell.children[1] as DocxTable;
      expect(innerTable.rows.length, 1);
      expect(
          ((innerTable.rows[0].cells[0].children[0] as DocxParagraph)
                  .children[0] as DocxText)
              .content,
          'Inner Row 1');
    });

    test('isolates cell styles from paragraph styles', () async {
      final html = '''
        <table>
          <tr>
            <td style="background-color: #FF0000">
              <p style="color: #00FF00">Text</p>
            </td>
          </tr>
        </table>
      ''';

      final nodes = await DocxParser.fromHtml(html);
      final table = nodes.first as DocxTable;
      final cell = table.rows[0].cells[0];

      // Cell should have background color
      expect(cell.shadingFill, 'FF0000');

      // Paragraph inside should NOT have the shading, but should have its own style
      final para = cell.children[0] as DocxParagraph;
      expect(para.shadingFill, isNull);
      // Also ensuring we didn't inherit 'p' tag styles onto the cell unintentionally
      // (which was the issue - leak IN to cell or OUT of cell)

      // The implementation sets shadingFill explicitly from td style
    });
  });
}
