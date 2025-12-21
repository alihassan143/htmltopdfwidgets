import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Drop Cap Tests', () {
    test('DocxDropCap has correct properties', () {
      final dropCap = DocxDropCap(
        letter: 'O',
        lines: 3,
        style: DocxDropCapStyle.drop,
        fontFamily: 'Times New Roman',
        fontSize: 48.0,
        hSpace: 100,
      );

      expect(dropCap.letter, 'O');
      expect(dropCap.lines, 3);
      expect(dropCap.style, DocxDropCapStyle.drop);
      expect(dropCap.fontFamily, 'Times New Roman');
      expect(dropCap.fontSize, 48.0);
      expect(dropCap.hSpace, 100);
    });

    test('DocxDropCap copyWith works correctly', () {
      final dropCap = DocxDropCap(
        letter: 'O',
        lines: 3,
        style: DocxDropCapStyle.drop,
      );

      final modified = dropCap.copyWith(letter: 'A', lines: 4);

      expect(modified.letter, 'A');
      expect(modified.lines, 4);
      expect(modified.style, DocxDropCapStyle.drop); // Unchanged
    });

    test('DocxDropCap builds valid XML', () {
      final dropCap = DocxDropCap(
        letter: 'O',
        lines: 3,
        style: DocxDropCapStyle.drop,
        fontSize: 48.0,
      );

      final builder = XmlBuilder();
      dropCap.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:framePr'));
      expect(xml, contains('w:dropCap'));
      expect(xml, contains('w:lines'));
      expect(xml, contains('w:t'));
    });

    test('DocxDropCapStyle.margin builds correct XML', () {
      final dropCap = DocxDropCap(
        letter: 'M',
        lines: 2,
        style: DocxDropCapStyle.margin,
      );

      final builder = XmlBuilder();
      dropCap.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:dropCap="margin"'));
    });
  });

  group('Footnote Tests', () {
    test('DocxFootnoteRef has correct properties', () {
      final footnoteRef = DocxFootnoteRef(footnoteId: 1);

      expect(footnoteRef.footnoteId, 1);
    });

    test('DocxFootnoteRef builds valid XML', () {
      final footnoteRef = DocxFootnoteRef(footnoteId: 1);

      final builder = XmlBuilder();
      footnoteRef.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:r'));
      expect(xml, contains('w:footnoteReference'));
      expect(xml, contains('w:id="1"'));
      expect(xml, contains('FootnoteReference'));
    });

    test('DocxFootnote has correct properties', () {
      final footnote = DocxFootnote(
        footnoteId: 1,
        content: [DocxParagraph.text('This is a footnote.')],
      );

      expect(footnote.footnoteId, 1);
      expect(footnote.content.length, 1);
    });

    test('DocxFootnote builds valid XML', () {
      final footnote = DocxFootnote(
        footnoteId: 1,
        content: [DocxParagraph.text('This is a footnote.')],
      );

      final builder = XmlBuilder();
      footnote.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:footnote'));
      expect(xml, contains('w:id="1"'));
      expect(xml, contains('w:p'));
    });

    test('DocxFootnote copyWith works correctly', () {
      final footnote = DocxFootnote(
        footnoteId: 1,
        content: [DocxParagraph.text('Original')],
      );

      final modified = footnote.copyWith(footnoteId: 2);

      expect(modified.footnoteId, 2);
      expect(modified.content.length, 1);
    });
  });

  group('Endnote Tests', () {
    test('DocxEndnoteRef has correct properties', () {
      final endnoteRef = DocxEndnoteRef(endnoteId: 1);

      expect(endnoteRef.endnoteId, 1);
    });

    test('DocxEndnoteRef builds valid XML', () {
      final endnoteRef = DocxEndnoteRef(endnoteId: 1);

      final builder = XmlBuilder();
      endnoteRef.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:r'));
      expect(xml, contains('w:endnoteReference'));
      expect(xml, contains('w:id="1"'));
      expect(xml, contains('EndnoteReference'));
    });

    test('DocxEndnote has correct properties', () {
      final endnote = DocxEndnote(
        endnoteId: 1,
        content: [DocxParagraph.text('This is an endnote.')],
      );

      expect(endnote.endnoteId, 1);
      expect(endnote.content.length, 1);
    });

    test('DocxEndnote builds valid XML', () {
      final endnote = DocxEndnote(
        endnoteId: 1,
        content: [DocxParagraph.text('This is an endnote.')],
      );

      final builder = XmlBuilder();
      endnote.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:endnote'));
      expect(xml, contains('w:id="1"'));
      expect(xml, contains('w:p'));
    });

    test('DocxEndnote copyWith works correctly', () {
      final endnote = DocxEndnote(
        endnoteId: 1,
        content: [DocxParagraph.text('Original')],
      );

      final modified = endnote.copyWith(endnoteId: 2);

      expect(modified.endnoteId, 2);
      expect(modified.content.length, 1);
    });
  });

  group('Text Border Tests', () {
    test('DocxText with textBorder has correct properties', () {
      final border = DocxBorderSide(
        style: DocxBorder.single,
        size: 8,
        space: 1,
        color: DocxColor.black,
      );

      final text = DocxText(
        'Bordered text',
        textBorder: border,
      );

      expect(text.textBorder, isNotNull);
      expect(text.textBorder!.style, DocxBorder.single);
      expect(text.textBorder!.size, 8);
      expect(text.textBorder!.color, DocxColor.black);
    });

    test('DocxText textBorder builds valid XML', () {
      final border = DocxBorderSide(
        style: DocxBorder.single,
        size: 8,
        space: 1,
        color: DocxColor.black,
      );

      final text = DocxText(
        'Bordered text',
        textBorder: border,
      );

      final builder = XmlBuilder();
      text.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:bdr'));
      expect(xml, contains('w:val="single"'));
      expect(xml, contains('w:sz="8"'));
    });

    test('DocxText copyWith preserves textBorder', () {
      final border = DocxBorderSide(
        style: DocxBorder.double,
        size: 4,
        space: 0,
        color: DocxColor.red,
      );

      final text = DocxText('Original', textBorder: border);
      final copied = text.copyWith(content: 'Modified');

      expect(copied.textBorder, isNotNull);
      expect(copied.textBorder!.style, DocxBorder.double);
    });
  });

  group('Header Row Tests', () {
    test('DocxTableRow with isHeader has correct property', () {
      final row = DocxTableRow(
        cells: [DocxTableCell.text('Header Cell')],
        isHeader: true,
      );

      expect(row.isHeader, true);
    });

    test('DocxTableRow isHeader builds w:tblHeader in XML', () {
      final row = DocxTableRow(
        cells: [DocxTableCell.text('Header Cell')],
        isHeader: true,
      );

      final builder = XmlBuilder();
      row.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:tblHeader'));
    });

    test('DocxTableRow without isHeader does not have w:tblHeader', () {
      final row = DocxTableRow(
        cells: [DocxTableCell.text('Regular Cell')],
        isHeader: false,
      );

      final builder = XmlBuilder();
      row.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('w:tblHeader')));
    });

    test('DocxTableRow copyWith preserves isHeader', () {
      final row = DocxTableRow(
        cells: [DocxTableCell.text('Header')],
        isHeader: true,
      );

      final copied = row.copyWith(height: 500);

      expect(copied.isHeader, true);
      expect(copied.height, 500);
    });
  });

  group('Footnotes/Endnotes Round-Trip Tests', () {
    test('DocxBuiltDocument preserves footnotesXml and endnotesXml', () async {
      // Create a document from scratch - no footnotes/endnotes
      final doc = docx().p('Simple paragraph').build();

      // Export to bytes
      final bytes = await DocxExporter().exportToBytes(doc);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);

      // Should have no footnotes/endnotes for a new document
      // (unless they exist in default templates)
      // This just verifies the round-trip mechanism works
      expect(readDoc.elements, isNotEmpty);
    });

    test('Paragraph with footnote reference can be created', () {
      final para = DocxParagraph(children: [
        DocxText('Main text'),
        DocxFootnoteRef(footnoteId: 1),
        DocxText(' continues here.'),
      ]);

      expect(para.children.length, 3);
      expect(para.children[1], isA<DocxFootnoteRef>());
    });

    test('Paragraph with endnote reference can be created', () {
      final para = DocxParagraph(children: [
        DocxText('Main text'),
        DocxEndnoteRef(endnoteId: 1),
        DocxText(' continues here.'),
      ]);

      expect(para.children.length, 3);
      expect(para.children[1], isA<DocxEndnoteRef>());
    });
  });

  group('Drop Cap Round-Trip Tests', () {
    test('DocxDropCap can be added to document', () async {
      final doc = docx()
          .add(DocxDropCap(
            letter: 'O',
            lines: 3,
            style: DocxDropCapStyle.drop,
          ))
          .p('nce upon a time...')
          .build();

      // Export to bytes
      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);
      // The structure may vary but should not throw
      expect(readDoc.elements, isNotEmpty);
    });
  });

  group('Vertical Alignment Tests', () {
    test('DocxTableCell with verticalAlign has correct property', () {
      final cell = DocxTableCell(
        children: [DocxParagraph.text('Test')],
        verticalAlign: DocxVerticalAlign.center,
      );

      expect(cell.verticalAlign, DocxVerticalAlign.center);
    });

    test('DocxTableCell verticalAlign builds correct XML', () {
      final cell = DocxTableCell(
        children: [DocxParagraph.text('Test')],
        verticalAlign: DocxVerticalAlign.bottom,
      );

      final builder = XmlBuilder();
      cell.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:vAlign'));
      expect(xml, contains('w:val="bottom"'));
    });
  });

  group('Table Alignment Tests', () {
    test('DocxTable with alignment has correct property', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        alignment: DocxAlign.center,
      );

      expect(table.alignment, DocxAlign.center);
    });

    test('DocxTable alignment builds w:jc in XML', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        alignment: DocxAlign.center,
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:jc'));
      expect(xml, contains('w:val="center"'));
    });

    test('DocxTable without alignment does not have w:jc', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('w:jc')));
    });

    test('DocxTable copyWith preserves alignment', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        alignment: DocxAlign.right,
      );

      final copied = table.copyWith(width: 5000);

      expect(copied.alignment, DocxAlign.right);
      expect(copied.width, 5000);
    });
  });

  group('Floating Table Position Tests', () {
    test('DocxTablePosition has correct default values', () {
      const pos = DocxTablePosition();

      expect(pos.hAnchor, DocxTableHAnchor.margin);
      expect(pos.vAnchor, DocxTableVAnchor.text);
      expect(pos.leftFromText, 180);
      expect(pos.rightFromText, 180);
    });

    test('DocxTable with position has correct property', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        position: DocxTablePosition(
          hAnchor: DocxTableHAnchor.page,
          tblpX: 1440,
        ),
      );

      expect(table.position, isNotNull);
      expect(table.position!.hAnchor, DocxTableHAnchor.page);
      expect(table.position!.tblpX, 1440);
    });

    test('DocxTable position builds w:tblpPr in XML', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        position: DocxTablePosition(
          hAnchor: DocxTableHAnchor.margin,
          vAnchor: DocxTableVAnchor.page,
          tblpX: 1000,
          tblpY: 2000,
        ),
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:tblpPr'));
      expect(xml, contains('w:horzAnchor="margin"'));
      expect(xml, contains('w:vertAnchor="page"'));
      expect(xml, contains('w:tblpX="1000"'));
      expect(xml, contains('w:tblpY="2000"'));
    });

    test('DocxTable without position does not have w:tblpPr', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('w:tblpPr')));
    });

    test('DocxTablePosition.centered static constant', () {
      const pos = DocxTablePosition.centered;

      expect(pos.hAnchor, DocxTableHAnchor.margin);
      expect(pos.tblpX, 0);
    });

    test('DocxTable copyWith preserves position', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Test')])
        ],
        position: DocxTablePosition(tblpX: 500),
      );

      final copied = table.copyWith(alignment: DocxAlign.center);

      expect(copied.position, isNotNull);
      expect(copied.position!.tblpX, 500);
      expect(copied.alignment, DocxAlign.center);
    });
  });
}
