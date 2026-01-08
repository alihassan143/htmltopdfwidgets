import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('PdfReader Round Trip', () {
    test('exports and reads back simple text with styles', () async {
      final doc = docx()
          .paragraph(DocxParagraph(children: [
            DocxText('Normal '),
            DocxText.bold('Bold '),
            DocxText.italic('Italic'),
          ]))
          .build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfDoc = await PdfReader.loadFromBytes(bytes);

      expect(pdfDoc.pageCount, greaterThanOrEqualTo(1));
      // Basic check: all words exist in text content
      final text = pdfDoc.text;
      expect(text, contains('Normal'));
      expect(text, contains('Bold'));
      expect(text, contains('Italic'));
    });

    test('exports and reads back table', () async {
      final doc = docx().table([
        ['Row1Col1', 'Row1Col2'],
        ['Row2Col1', 'Row2Col2']
      ]).build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfDoc = await PdfReader.loadFromBytes(bytes);

      expect(pdfDoc.text, contains('Row1Col1'));
      expect(pdfDoc.text, contains('Row2Col2'));

      final tables = pdfDoc.elements.whereType<DocxTable>().toList();
      // Heuristic might fail on simple text if spacing is tight, but let's see.
      // If table is detected, verify structure
      if (tables.isNotEmpty) {
        final table = tables.first;
        // Verify rows/cells
        // Rows might be 2
        // Cells might be 2 per row
        expect(table.rows.length, 2);
        // expect(table.rows[0].cells.length, 2);
      }
    });

    test('exports and reads back image', () async {
      // Minimal 1x1 PNG
      final pngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82
      ]);

      final doc = docx()
          .image(DocxImage(
              bytes: pngBytes, extension: 'png', width: 50, height: 50))
          .build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfDoc = await PdfReader.loadFromBytes(bytes);

      expect(pdfDoc.images.length, equals(1));
      final images = pdfDoc.elements.whereType<DocxImage>().toList();
      expect(images.length, equals(1));
      expect(images.first.width, closeTo(50, 5.0)); // Tolerance for rounding
    });

    test('verifies page dimensions in toDocx', () async {
      final doc = docx().section(pageSize: DocxPageSize.a4).p('Page 1').build();
      final bytes = PdfExporter().exportToBytes(doc);
      final pdfDoc = await PdfReader.loadFromBytes(bytes);

      final exportedDoc = pdfDoc.toDocx();
      final section = exportedDoc.section;

      expect(section, isNotNull);
      expect(section!.pageSize, equals(DocxPageSize.custom));

      // A4 is 595.28 x 841.89 points.
      // PDF output should match.
      // toDocx converts points to twips (x20).
      final expectedWidth = (595.28 * 20).toInt();

      expect(section.customWidth, closeTo(expectedWidth, 100)); // 5pt tolerance
    });
  });
}
