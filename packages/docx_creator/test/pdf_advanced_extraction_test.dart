import 'dart:typed_data';

import 'package:docx_creator/src/reader/pdf_reader/pdf_parser.dart';
import 'package:docx_creator/src/reader/pdf_reader/pdf_text_extractor.dart';
import 'package:test/test.dart';

// Mock parser that only provides tokenization
class MockPdfParser extends PdfParser {
  MockPdfParser() : super(Uint8List(0));

  @override
  List<String> tokenize(String content) {
    // Simple tokenizer for testing
    final tokens = <String>[];
    final regex = RegExp(
        r'\s+|(?:\([^)]*\))|/[^(){}<>/%[\]\s]+|[(){}<>/%[\]]|[^(){}<>/%[\]\s]+');
    final matches = regex.allMatches(content);
    for (final match in matches) {
      final t = match.group(0)!.trim();
      if (t.isNotEmpty) tokens.add(t);
    }
    return tokens;
  }
}

void main() {
  group('PdfTextExtractor Advanced Features', () {
    late PdfTextExtractor extractor;

    setUp(() {
      extractor = PdfTextExtractor(MockPdfParser());
    });

    test('Visitor pattern callback', () {
      final visited = <String>[];
      final content = 'BT /F1 12 Tf (Hello) Tj ET';

      extractor.extractText(content, visitor: (op, operands) {
        visited.add(op);
        if (op == 'Tf') {
          // operands are List<dynamic>
          expect(operands, equals(['/F1', 12.0]));
        }
      });

      expect(visited, containsAll(['BT', 'Tf', 'Tj', 'ET']));
    });

    test('Text Rotation extraction', () {
      // 90 degrees rotation using Tm: 0 1 -1 0 x y
      final content = 'BT 0 1 -1 0 100 200 Tm (Rotated) Tj ET';

      final lines = extractor.extractText(content);
      expect(lines, hasLength(1));
      final line = lines.first;

      // rotation checks
      expect(line.rotation, closeTo(90, 0.1));
      expect(line.text, 'Rotated');
      expect(line.x, 100);
      expect(line.y, 200);
    });

    test('Layout mode extraction (Spaces)', () {
      // simulate two words far apart
      // x=10, width=50 (approx), then wait... code calculates width
      // let's just make two separate Tj calls with Td in between
      // We need font info for width calculation usually...
      // but the width calc uses heuristic if font not found:
      // width = length * fontSize * 0.5 * scaling
      // fontSize default is 12.
      // 10 10 Td -> x=10, y=10.
      // (Hello) -> 5 chars. width = 5 * 10 * 0.5 = 25. Next x should be 35.
      // Then 100 0 Td -> x+=100. New x = 135.
      // Gap = 100. Char width = 5. Spaces = 20.

      final content =
          'BT /F1 10 Tf 10 10 Td (Hello) Tj 100 0 Td (World) Tj ET'; // 100 units gap

      final text =
          extractor.extractTextString(content, mode: PdfExtractionMode.layout);

      // Should have spaces between Hello and World
      expect(text, contains('Hello'));
      expect(text, contains('World'));
      expect(text, matches(r'Hello\s+World'));
    });

    test('Layout mode extraction (Newlines)', () {
      // Two lines
      // y=100. Next line y at 100-20=80.
      // fontSize 10. distY = 20 > 5. Newline expected.
      final content =
          'BT /F1 10 Tf 10 100 Td (Line1) Tj 0 -20 Td (Line2) Tj ET';

      final text =
          extractor.extractTextString(content, mode: PdfExtractionMode.layout);

      expect(text, contains('Line1'));
      expect(text, contains('\n'));
      expect(text, contains('Line2'));
    });

    test('Matrix calculation for rotated text', () {
      // 45 degrees: 0.707 0.707 -0.707 0.707
      final content = 'BT 0.707 0.707 -0.707 0.707 50 50 Tm (Angled) Tj ET';

      final lines = extractor.extractText(content);
      expect(lines.first.rotation, closeTo(45, 0.1));
    });
  });
}
