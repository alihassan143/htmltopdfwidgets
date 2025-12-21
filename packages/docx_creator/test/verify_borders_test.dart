import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxReader Border Verification', () {
    test('Round-trip Paragraph Borders', () async {
      // Create a paragraph with specific borders
      final p = DocxParagraph(
        children: [DocxText('Paragraph with borders')],
        borderTop: DocxBorderSide(
            style: DocxBorder.double, size: 12, color: DocxColor.red),
        borderBottomSide: DocxBorderSide(
            style: DocxBorder.dashed, size: 8, color: DocxColor.blue),
        borderLeft: DocxBorderSide(
            style: DocxBorder.single, size: 4, color: DocxColor.green),
        // borderRight left as default/null
      );

      final doc = DocxBuiltDocument(
        section: DocxSectionDef(),
        elements: [p],
      );

      // Export
      final bytes = await DocxExporter().exportToBytes(doc);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);
      final readP = readDoc.elements.first as DocxParagraph;

      // Assertions
      expect(readP.borderTop, isNotNull);
      expect(
          readP.borderTop!.style.xmlValue,
          DocxBorder.double
              .xmlValue); // Enum checking by Value or Identity? Enum identity should work if mapped correctly
      // DocxReader maps 'double' -> DocxBorder.double.
      expect(readP.borderTop!.style, DocxBorder.double);
      expect(readP.borderTop!.color.hex, 'FF0000');

      expect(readP.borderBottomSide, isNotNull);
      expect(readP.borderBottomSide!.style, DocxBorder.dashed);
      expect(readP.borderBottomSide!.color.hex, '0000FF');

      expect(readP.borderLeft, isNotNull);
      expect(readP.borderLeft!.style, DocxBorder.single);
    });

    test('Round-trip Table Borders', () async {
      // Create a table with specific borders
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell.text(
              'Cell 1',
              // Cell borders? DocxTableCell constructor has them now
              // But DocxTableCell factory .text doesn't expose them.
              // We use default constructor
            ),
            DocxTableCell(
              children: [DocxParagraph.text('Cell 2')],
              borderTop: DocxBorderSide(
                  style: DocxBorder.dashed, color: DocxColor.red),
              borderRight: DocxBorderSide(
                  style: DocxBorder.dotted, color: DocxColor.blue),
            )
          ])
        ],
        style: DocxTableStyle(
          borderTop: DocxBorderSide(style: DocxBorder.thick, size: 24),
          borderInsideV: DocxBorderSide(style: DocxBorder.dashed),
        ),
      );

      final doc = DocxBuiltDocument(elements: [table]);

      // Export
      final bytes = await DocxExporter().exportToBytes(doc);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);
      final readTable = readDoc.elements.first as DocxTable;

      // Assert Table Borders
      expect(readTable.style.borderTop, isNotNull);
      expect(readTable.style.borderTop!.style, DocxBorder.thick);

      expect(readTable.style.borderInsideV, isNotNull);
      expect(readTable.style.borderInsideV!.style, DocxBorder.dashed);

      // Assert Cell Borders
      final cell2 = readTable.rows[0].cells[1];
      expect(cell2.borderTop, isNotNull);
      expect(cell2.borderTop!.style, DocxBorder.dashed);
      expect(cell2.borderTop!.color.hex, 'FF0000');

      expect(cell2.borderRight, isNotNull);
      expect(cell2.borderRight!.style, DocxBorder.dotted);
    });
  });
}
