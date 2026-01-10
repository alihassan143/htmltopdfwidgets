import 'dart:typed_data';

import 'package:docx_creator/src/reader/pdf_reader/pdf_page_info.dart';
import 'package:docx_creator/src/reader/pdf_reader/pdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('PdfPageInfoExtractor', () {
    test('extracts basic page info', () {
      final pdfContent = '%PDF-1.4\n'
          '1 0 obj\n'
          '<< /Type /Catalog /Pages 2 0 R >>\n'
          'endobj\n'
          '2 0 obj\n'
          '<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n'
          'endobj\n'
          '3 0 obj\n'
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Rotate 90 >>\n'
          'endobj\n'
          'xref\n'
          '0 4\n'
          '0000000000 65535 f \n'
          '0000000010 00000 n \n'
          '0000000060 00000 n \n'
          '0000000120 00000 n \n'
          'trailer\n'
          '<< /Size 4 /Root 1 0 R >>\n'
          'startxref\n'
          '220\n'
          '%%EOF';

      // We need to bypass the file reading part of PdfParser.
      // PdfParser has a constructor that takes bytes.
      // We can encode the string to bytes.
      final bytes = Uint8List.fromList(pdfContent.codeUnits);
      final parser = PdfParser(bytes);

      parser.parse(); // Should parse the structure

      final extractor = PdfPageInfoExtractor(parser);
      final infos = extractor.extractAll();

      expect(infos.length, 1);
      final info = infos.first;
      expect(info.pageNumber, 1);
      expect(info.rotation, 90);
      expect(info.mediaBox.width, closeTo(595.28, 0.01));
      expect(info.mediaBox.height, closeTo(841.89, 0.01));

      // Check width/height taking rotation (actually width/height property uses mediaBox directly * userUnit)
      // PdfPageInfo implementation: width = mediaBox.width * userUnit.
      // It doesn't auto-swap for rotation in the property currently, unless specified.
      // Based on my implementation: width = mediaBox.width * userUnit.
      expect(info.width, closeTo(595.28, 0.01));
    });

    test('parses PdfBox', () {
      final box = PdfBox.fromPdfArray([0, 0, 100, 200]);
      expect(box.x, 0);
      expect(box.y, 0);
      expect(box.width, 100);
      expect(box.height, 200);
    });
  });
}
