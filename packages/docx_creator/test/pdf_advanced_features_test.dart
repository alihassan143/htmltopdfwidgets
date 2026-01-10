import 'dart:typed_data';

import 'package:docx_creator/src/reader/pdf_reader/pdf_reader.dart';
import 'package:test/test.dart';

void main() {
  group('Advanced PDF Features', () {
    test('Page Labels (Roman, Decimal)', () async {
      // PDF with 5 pages.
      // PageLabels: 0 -> /R (I, II...), 2 -> /D (1, 2, 3...)
      // Pages: 0=I, 1=II, 2=1, 3=2, 4=3
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R /PageLabels 3 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [4 0 R 5 0 R 6 0 R 7 0 R 8 0 R] /Count 5 >>
endobj
3 0 obj
<< /Nums [ 0 << /S /R >> 2 << /S /D /St 1 >> ] >>
endobj
4 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >> endobj
5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >> endobj
6 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >> endobj
7 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >> endobj
8 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >> endobj
xref
0 9
0000000000 65535 f
0000000010 00000 n
0000000080 00000 n
0000000160 00000 n
0000000220 00000 n
0000000290 00000 n
0000000360 00000 n
0000000430 00000 n
0000000500 00000 n
trailer
<< /Size 9 /Root 1 0 R >>
startxref
600
%%EOF
''';

      final doc = await PdfReader.loadFromBytes(
          Uint8List.fromList(pdfContent.codeUnits));

      expect(doc.pageCount, equals(5));
      expect(doc.pageLabels, equals(['I', 'II', '1', '2', '3']));
    });

    test('Tagged PDF Detection', () async {
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R /StructTreeRoot 3 0 R >>
endobj
2 0 obj
<< /Type /Pages /Count 1 /Kids [4 0 R] >>
endobj
3 0 obj
<< /Type /StructTreeRoot /RoleMap << /H1 /Heading1 >> >>
endobj
4 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>
endobj
xref
0 5
0000000000 65535 f
0000000010 00000 n
0000000100 00000 n
0000000160 00000 n
0000000250 00000 n
trailer
<< /Size 5 /Root 1 0 R >>
startxref
350
%%EOF
''';
      final doc = await PdfReader.loadFromBytes(
          Uint8List.fromList(pdfContent.codeUnits));
      expect(doc.isTagged, isTrue);
      expect(doc.structureTree, isNotNull);
      expect(doc.structureTree!.roleMap, containsPair('/H1', '/Heading1'));
    });

    test('Layers (OCGs) Extraction', () async {
      final pdfContent = '''
%PDF-1.5
1 0 obj
<< /Type /Catalog /Pages 2 0 R /OCProperties 3 0 R >>
endobj
2 0 obj
<< /Type /Pages /Count 1 /Kids [5 0 R] >>
endobj
3 0 obj
<< /OCGs [4 0 R] /D << /Order [4 0 R] >> >>
endobj
4 0 obj
<< /Type /OCG /Name (Watermark Layer) >>
endobj
5 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>
endobj
xref
0 6
0000000000 65535 f
0000000010 00000 n
0000000100 00000 n
0000000160 00000 n
0000000220 00000 n
0000000290 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
400
%%EOF
''';
      final doc = await PdfReader.loadFromBytes(
          Uint8List.fromList(pdfContent.codeUnits));
      expect(doc.layers.length, equals(1));
      expect(doc.layers.first.name, equals('Watermark Layer'));
    });
  });
}
