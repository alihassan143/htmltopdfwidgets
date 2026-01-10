import 'dart:typed_data';

import 'package:docx_creator/src/reader/pdf_reader/pdf_reader.dart';
import 'package:test/test.dart';

void main() {
  group('PDF Gap Features', () {
    test('CropBox overrides MediaBox', () async {
      // PDF with MediaBox [0 0 500 500] and CropBox [0 0 200 200]
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< 
  /Type /Page 
  /Parent 2 0 R 
  /MediaBox [0 0 500 500] 
  /CropBox [0 0 200 300]
  /Resources << >>
>>
endobj
xref
0 4
0000000000 65535 f
0000000010 00000 n
0000000060 00000 n
0000000120 00000 n
trailer
<< /Size 4 /Root 1 0 R >>
startxref
250
%%EOF
''';

      final doc = await PdfReader.loadFromBytes(
          Uint8List.fromList(pdfContent.codeUnits));

      // Expected: CropBox width 200, height 300
      expect(doc.pageWidth, equals(200.0));
      expect(doc.pageHeight, equals(300.0));
    });

    test('EmbeddedFiles Extraction', () async {
      // Mock PDF with embedded file
      // Structure: Catalog -> Names -> EmbeddedFiles -> NameTree (Leaf with Names array) -> Filespec -> EF -> Stream
      final pdfContent = '''
%PDF-1.7
1 0 obj
<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>
endobj
4 0 obj
<< /EmbeddedFiles 5 0 R >>
endobj
5 0 obj
<< /Names [(MyFile.txt) 6 0 R] >>
endobj
6 0 obj
<< /Type /Filespec /F (MyFile.txt) /UF (MyFile.txt) /EF << /F 7 0 R >> >>
endobj
7 0 obj
<< /Length 12 >>
stream
Hello World!
endstream
endobj
xref
0 8
0000000000 65535 f
0000000010 00000 n
0000000070 00000 n
0000000130 00000 n
0000000200 00000 n
0000000240 00000 n
0000000290 00000 n
0000000380 00000 n
trailer
<< /Size 8 /Root 1 0 R >>
startxref
450
%%EOF
''';

      final doc = await PdfReader.loadFromBytes(
          Uint8List.fromList(pdfContent.codeUnits));

      expect(doc.attachments, isNotEmpty);
      expect(doc.attachments.length, equals(1));
      final attachment = doc.attachments.first;
      expect(attachment.filename, equals('MyFile.txt'));
      expect(String.fromCharCodes(attachment.data), equals('Hello World!'));
    });
  });
}
