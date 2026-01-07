import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('PdfExporter', () {
    test('exports to bytes with correct PDF header', () async {
      final doc = docx().h1('Test Document').build();
      final bytes = PdfExporter().exportToBytes(doc);

      expect(bytes.length, greaterThan(0));
      // PDF-1.4 header
      final header = String.fromCharCodes(bytes.sublist(0, 8));
      expect(header, '%PDF-1.4');
    });

    test('exports basic paragraph content', () async {
      final doc = docx().p('Hello World').build();
      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      expect(pdfContent, contains('Hello World'));
      expect(pdfContent, contains('/Type /Page'));
    });

    test('exports formatted text', () async {
      final doc = docx()
          .paragraph(DocxParagraph(children: [
            DocxText.bold('BoldText'),
            DocxText.italic('ItalicText'),
          ]))
          .build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      expect(pdfContent, contains('BoldText'));
      expect(pdfContent, contains('ItalicText'));
      // Check for font references (heuristic)
      expect(pdfContent, contains('/F2')); // Bold
      expect(pdfContent, contains('/F3')); // Italic
    });

    test('exports tables', () async {
      final doc = docx().table([
        ['Cell A', 'Cell B'],
        ['Cell 1', 'Cell 2']
      ]).build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      expect(pdfContent, contains('Cell A'));
      expect(pdfContent, contains('Cell 2'));
      // Basic check for drawing operations
      expect(pdfContent, contains(' re')); // Rectangle
      expect(pdfContent, contains(' S')); // Stroke
    });

    test('exports lists', () async {
      final doc = docx()
          .bullet(['Item 1', 'Item 2']).numbered(['Step 1', 'Step 2']).build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      expect(pdfContent, contains('Item 1'));
      expect(pdfContent, contains('Step 2'));
    });

    test('respects section page settings (A4)', () async {
      // Use A4 size: 11906 twips width approx 595.3 points
      final doc =
          docx().section(pageSize: DocxPageSize.a4).p('Content').build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      // Check MediaBox in Page object. A4 is [0 0 595.3 841.9]
      // We look for 595.3 (approx)
      final mediaBoxRegex = RegExp(r'/MediaBox \[0 0 ([\d\.]+) ([\d\.]+)\]');
      final match = mediaBoxRegex.firstMatch(pdfContent);

      if (match == null) {
        print(
            'MediaBox not found. Content excerpt:\n${pdfContent.substring(0, 300)}...');
        fail('MediaBox not found in PDF output');
      }

      final width = double.parse(match.group(1)!);
      expect(width, closeTo(595.3, 0.1),
          reason: 'Page width should be A4 (595.3 pts)');
    });

    test('exports multiple pages', () async {
      // Create enough content to force pagination
      final builder = docx();
      for (int i = 0; i < 100; i++) {
        builder.p('Line $i');
      }
      final doc = builder.build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      // Should have more than one page object
      // Count occurrences of "/Type /Page"
      final pageCount = '/Type /Page'.allMatches(pdfContent).length;
      expect(pageCount, greaterThan(1));
    });

    test('exports images', () async {
      final doc = docx()
          .image(DocxImage(
            bytes:
                Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // Fake PNG header
            extension: 'png',
            width: 100,
            height: 100,
            id: 'img1',
          ))
          .build();

      final bytes = PdfExporter().exportToBytes(doc);
      final pdfContent = String.fromCharCodes(bytes);

      // Check for XObject resource
      expect(pdfContent, contains('/Type /XObject'));
      expect(pdfContent, contains('/Subtype /Image'));
      expect(pdfContent, contains('/ASCIIHexDecode'));
    });
  });
}
