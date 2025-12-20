/// Stress Test - Package Robustness
library;

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('Stress Tests', () {
    test('large document (100 paragraphs)', () async {
      final builder = docx().h1('Large Document');
      for (int i = 0; i < 100; i++) {
        builder.p('Paragraph $i: Lorem ipsum dolor sit amet.');
      }
      final doc = builder.build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
      expect(doc.elements.length, 101);
    });

    test('large table (1000 cells)', () async {
      final data = List.generate(
        100,
        (row) => List.generate(10, (col) => 'R${row}C$col'),
      );

      final doc = docx().h1('Large Table').table(data).build();
      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('all text formatting combined', () async {
      final doc = docx()
          .paragraph(
            DocxParagraph(
              children: [
                DocxText('Normal '),
                DocxText.bold('Bold '),
                DocxText.italic('Italic '),
                DocxText.superscript('sup '),
                DocxText.subscript('sub '),
                DocxText('Red', color: DocxColor.red),
                DocxText(' '),
                DocxText('Custom', color: DocxColor('4285F4')),
              ],
            ),
          )
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('all table styles', () async {
      final data = [
        ['A', 'B'],
        ['1', '2'],
      ];

      final doc = docx()
          .table(data, style: DocxTableStyle.grid)
          .table(data, style: DocxTableStyle.plain)
          .table(data, style: DocxTableStyle.zebra)
          .table(data, style: DocxTableStyle.professional)
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('mixed content document', () async {
      final doc = docx()
          .section(
            header: DocxHeader.text('Mixed Content'),
            footer: DocxFooter.pageNumbers(),
          )
          .h1('Mixed Content Document')
          .p('Introduction.')
          .bullet(['Item 1', 'Item 2'])
          .table([
            ['A', 'B'],
            ['1', '2'],
          ])
          .quote('A blockquote')
          .code('console.log("code");')
          .hr()
          .pageBreak()
          .h1('Page 2')
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('Unicode content', () async {
      final doc = docx()
          .h1('Unicode Test 日本語 العربية')
          .p('Emojis: 🎉🚀💻')
          .bullet(['日本語', 'العربية', '中文']).build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('special characters', () async {
      final doc = docx()
          .h1('Special Characters')
          .p('Ampersand: &, Less than: <, Greater than: >')
          .p('Copyright: © ® ™')
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('empty elements handled', () async {
      final doc = docx().h1('Edge Cases').p('').bullet([]).table([]).build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
    });

    test('HTML export stress', () {
      final builder = docx().h1('HTML Export Test');
      for (int i = 0; i < 50; i++) {
        builder.p('Paragraph $i');
      }
      final doc = builder.build();

      final html = HtmlExporter().export(doc);
      expect(html.length, greaterThan(0));
    });

    test('Markdown parsing', () async {
      final md = '''
# Heading 1
This is **bold** and *italic*.
- Bullet 1
- Bullet 2
''';
      final elements = await DocxParser.fromMarkdown(md);
      expect(elements.length, greaterThan(0));
    });

    test('HTML parsing', () async {
      final html = '<h1>Title</h1><p><strong>bold</strong></p>';
      final elements = await DocxParser.fromHtml(html);
      expect(elements.length, greaterThan(0));
    });
  });
}
