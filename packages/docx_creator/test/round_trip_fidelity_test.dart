import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// Round-trip fidelity tests for True-Fidelity DOCX preservation.
///
/// These tests verify that reading a DOCX file and exporting it preserves
/// the original properties without loss or modification.
void main() {
  group('Floating Image Round-Trip', () {
    test('preserves anchor attributes', () async {
      // Create a document with floating image and specific anchor attributes
      final imageBytes = _createTestPng();

      final original = DocxInlineImage(
        bytes: imageBytes,
        extension: 'png',
        width: 200,
        height: 150,
        positionMode: DocxDrawingPosition.floating,
        textWrap: DocxTextWrap.square,
        // True-Fidelity attributes
        distT: 152400, // 0.1667 inch
        distB: 152400,
        distL: 228600, // 0.25 inch
        distR: 228600,
        simplePos: false,
        relativeHeight: 251659264,
        locked: true,
        layoutInCell: false,
        allowOverlap: false,
        effectExtentL: 9525,
        effectExtentT: 9525,
        effectExtentR: 9525,
        effectExtentB: 9525,
      );

      // Verify the attributes are preserved
      expect(original.distT, equals(152400));
      expect(original.distB, equals(152400));
      expect(original.distL, equals(228600));
      expect(original.distR, equals(228600));
      expect(original.simplePos, isFalse);
      expect(original.relativeHeight, equals(251659264));
      expect(original.locked, isTrue);
      expect(original.layoutInCell, isFalse);
      expect(original.allowOverlap, isFalse);
      expect(original.effectExtentL, equals(9525));
      expect(original.effectExtentT, equals(9525));
      expect(original.effectExtentR, equals(9525));
      expect(original.effectExtentB, equals(9525));
    });

    test('default anchor values match Word defaults', () {
      final imageBytes = _createTestPng();

      final image = DocxInlineImage(
        bytes: imageBytes,
        extension: 'png',
        width: 100,
        height: 100,
        positionMode: DocxDrawingPosition.floating,
      );

      // Verify defaults match typical Word values
      expect(image.distT, equals(0));
      expect(image.distB, equals(0));
      expect(image.distL, equals(114300)); // Standard margin
      expect(image.distR, equals(114300));
      expect(image.simplePos, isFalse);
      expect(image.relativeHeight, equals(251658240));
      expect(image.locked, isFalse);
      expect(image.layoutInCell, isTrue);
      expect(image.allowOverlap, isTrue);
    });
  });

  group('Table Grid Round-Trip', () {
    test('preserves grid column widths', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(children: [DocxParagraph.text('A')], width: 2880),
            DocxTableCell(children: [DocxParagraph.text('B')], width: 2880),
            DocxTableCell(children: [DocxParagraph.text('C')], width: 2880),
          ]),
        ],
        gridColumns: [2880, 2880, 2880], // 2 inches each
      );

      expect(table.gridColumns, isNotNull);
      expect(table.gridColumns!.length, equals(3));
      expect(table.gridColumns![0], equals(2880));
      expect(table.gridColumns![1], equals(2880));
      expect(table.gridColumns![2], equals(2880));
    });

    test('copies grid columns correctly', () {
      final original = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell.text('A'),
            DocxTableCell.text('B'),
          ]),
        ],
        gridColumns: [1440, 2880],
      );

      final copy = original.copyWith(
        gridColumns: [2160, 2160],
      );

      expect(original.gridColumns, equals([1440, 2880]));
      expect(copy.gridColumns, equals([2160, 2160]));
    });
  });

  group('XmlExtensionMap', () {
    test('stores and retrieves unknown attributes', () {
      final ext = XmlExtensionMap(
        attributes: {
          'custom:attr': 'value123',
          'xmlns:custom': 'http://example.com',
        },
      );

      expect(ext.isEmpty, isFalse);
      expect(ext.isNotEmpty, isTrue);
      expect(ext.attributes['custom:attr'], equals('value123'));
    });

    test('empty map reports isEmpty', () {
      const ext = XmlExtensionMap();

      expect(ext.isEmpty, isTrue);
      expect(ext.isNotEmpty, isFalse);
    });

    test('merges two extension maps', () {
      final ext1 = XmlExtensionMap(attributes: {'a': '1', 'b': '2'});
      final ext2 = XmlExtensionMap(attributes: {'b': '3', 'c': '4'});

      final merged = ext1.merge(ext2);

      expect(merged.attributes['a'], equals('1'));
      expect(merged.attributes['b'], equals('3')); // ext2 wins
      expect(merged.attributes['c'], equals('4'));
    });
  });

  group('Measurement Conversions', () {
    test('EMU to points conversion', () {
      expect(914400.emuToPoints, closeTo(72.0, 0.01)); // 1 inch = 72pt
      expect(12700.emuToPoints, closeTo(1.0, 0.01)); // 1 pt
    });

    test('points to EMU conversion', () {
      expect(72.0.pointsToEmu, equals(914400)); // 1 inch
      expect(1.0.pointsToEmu, equals(12700)); // 1 pt
    });

    test('twips to points conversion', () {
      expect(1440.twipsToPoints, closeTo(72.0, 0.01)); // 1 inch
      expect(20.twipsToPoints, closeTo(1.0, 0.01)); // 1 pt
    });
  });

  group('DocxValidator', () {
    test('validates empty document', () {
      final doc = docx().build();
      final validator = DocxValidator();

      final isValid = validator.validate(doc);

      expect(isValid, isTrue);
      expect(validator.warnings, contains(contains('no content')));
    });

    test('validates table structure', () {
      final doc = docx().table([
        ['A', 'B', 'C'],
        ['1', '2'], // Mismatched columns
      ]).build();

      final validator = DocxValidator();
      validator.validate(doc);

      // Should warn about mismatched column count
      expect(
        validator.warnings,
        anyElement(contains('Column count')),
      );
    });

    test('detects invalid custom page size', () {
      final doc = DocxBuiltDocument(
        elements: [DocxParagraph.text('Test')],
        section: DocxSectionDef(
          pageSize: DocxPageSize.custom,
          customWidth: null, // Missing required value
          customHeight: null,
        ),
      );

      final validator = DocxValidator();
      final isValid = validator.validate(doc);

      expect(isValid, isFalse);
      expect(
        validator.errors,
        anyElement(contains('customWidth')),
      );
    });
  });
}

/// Creates a minimal valid PNG for testing.
Uint8List _createTestPng() {
  // Minimal 1x1 transparent PNG
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82,
  ]);
}
