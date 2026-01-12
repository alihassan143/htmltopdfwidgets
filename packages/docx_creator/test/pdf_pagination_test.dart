import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/exporters/pdf/pdf_layout_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PdfLayoutEngine Pagination', () {
    test('Splits large paragraph across multiple pages', () {
      final engine = PdfLayoutEngine(
        pageWidth: 600,
        pageHeight: 800,
        marginLeft: 50,
        marginRight: 50,
        marginTop: 50,
        marginBottom: 50,
      );

      // Content area height is 700.
      // 12pt font size -> ~16.8pt line height.
      // 700 / 16.8 ~= 41 lines per page.

      // We want to create a paragraph that requires approx 60 lines.
      // Each line has approx (500 / (12*0.5)) = 83 chars.
      // So we need 60 * 83 ~= 5000 chars.

      final text =
          'A long line of text that should repeat enough to overflow. ' * 300;

      final paragraph = DocxParagraph.text(text);

      final pages = engine.paginate([paragraph]);

      expect(pages.length, greaterThan(1),
          reason: 'Should split into multiple pages');
      expect(pages[0].isNotEmpty, isTrue);
      expect(pages[1].isNotEmpty, isTrue);

      // First page should only contain a paragraph (the split part)
      expect(pages[0].length, 1);

      // Second page should contain the rest
      final p2 = pages[1].first as DocxParagraph;
      expect(p2.children, isNotEmpty);
    });

    test('Handles massive paragraph spanning 3 pages', () {
      final engine = PdfLayoutEngine(
        pageWidth: 600,
        pageHeight: 800,
      );

      // very long text
      final text = 'This is a long sentence repeat ' * 1000;
      final paragraph = DocxParagraph.text(text);

      final pages = engine.paginate([paragraph]);

      expect(pages.length, greaterThanOrEqualTo(3));
      for (var page in pages) {
        expect(page, isNotEmpty);
      }
    });

    test('Handles multiple paragraphs with split', () {
      final engine = PdfLayoutEngine(
        pageWidth: 600,
        pageHeight: 800,
      );

      final p1 = DocxParagraph.text('Small paragraph');
      final p2 = DocxParagraph.text('Large paragraph ' * 500); // spans pages
      final p3 = DocxParagraph.text('End paragraph');

      final pages = engine.paginate([p1, p2, p3]);

      expect(pages.length, greaterThan(1));
      // First page has p1 and start of p2
      expect(pages[0].length, 2);
      // Last page has p3
      expect(pages.last.last, equals(p3));
    });
  });
}
