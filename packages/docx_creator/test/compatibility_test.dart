import 'dart:io';
import 'dart:typed_data';

import 'package:docx_creator/src/reader/pdf_reader/pdf_parser.dart';
import 'package:docx_creator/src/reader/pdf_reader/pdf_types.dart';
import 'package:test/test.dart';

void main() {
  group('PdfParser', () {
    late PdfParser parser;

    setUp(() {
      parser = PdfParser(Uint8List(0));
    });

    test('RunLengthDecode decompressor', () {
      final input = Uint8List.fromList([
        2, 65, 66, 67, // copy 3 bytes: ABC
        255, 68, // repeat D (257-255 = 2 times)
        128 // EOD
      ]);
      final expected = Uint8List.fromList([65, 66, 67, 68, 68]);
      final output =
          parser.applyFilterWithParams('RunLengthDecode', input, null);

      expect(output, equals(expected));
      expect(parser.warnings, isEmpty);
    });

    test('FlateDecode with PNG Predictor (Up)', () {
      final rawData = Uint8List.fromList([
        0, 10, 20, // Row 1: Filter None
        2, 0, 0 // Row 2: Filter Up (10+0, 20+0)
      ]);

      final compressed = Uint8List.fromList(zlib.encode(rawData));

      final params = {
        'Predictor': 12, // PNG Up
        'Columns': 2,
        'Colors': 1,
        'BitsPerComponent': 8
      };

      final output =
          parser.applyFilterWithParams('FlateDecode', compressed, params);

      final expected = Uint8List.fromList([10, 20, 10, 20]);

      expect(output, equals(expected));
      expect(parser.warnings, isEmpty);
    });
  });

  group('PdfFontInfo', () {
    test('MacRomanEncoding decoding', () {
      final font = PdfFontInfo(
        name: '/F1',
        baseFont: 'Helvetica',
        isBold: false,
        isItalic: false,
        encoding: 'MacRomanEncoding',
      );

      // 0x80 in MacRoman -> 0xC4 (Adieresis)
      expect(font.decodeChar(0x80), equals(0x00C4));
      // ASCII
      expect(font.decodeChar(0x41), equals(0x41));
    });

    test('StandardEncoding decoding', () {
      final font = PdfFontInfo(
        name: '/F1',
        baseFont: 'Helvetica',
        isBold: false,
        isItalic: false,
        encoding: 'StandardEncoding',
      );

      // 0xE9 -> 0xD8 (Oslash)
      expect(font.decodeChar(0xE9), equals(0x00D8));
    });

    test('Differences array priority', () {
      final differences = {
        65: 0x0042, // Map 'A' to 'B'
      };

      final font = PdfFontInfo(
        name: '/F1',
        baseFont: 'Helvetica',
        isBold: false,
        isItalic: false,
        differences: differences,
      );

      expect(font.decodeChar(65), equals(0x0042));
    });
  });
}
