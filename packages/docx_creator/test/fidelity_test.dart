import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/docx_reader/models/docx_font.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Font Fidelity', () {
    test('DocxText builds XML with granular DocxFont', () {
      final font = DocxFont(
        ascii: 'Arial',
        hAnsi: 'Helvetica',
        cs: 'Times New Roman',
        eastAsia: 'SimSun',
        hint: 'eastAsia',
      );
      final text = DocxText('Test', fonts: font);
      final builder = XmlBuilder();
      text.buildXml(builder);

      final xml = builder.buildDocument().toXmlString();
      // Expect w:rFonts with all attributes
      expect(xml, contains('w:rFonts'));
      expect(xml, contains('w:ascii="Arial"'));
      expect(xml, contains('w:hAnsi="Helvetica"'));
      expect(xml, contains('w:cs="Times New Roman"'));
      expect(xml, contains('w:eastAsia="SimSun"'));
      expect(xml, contains('w:hint="eastAsia"'));
    });

    test('DocxText builds XML with theme attributes', () {
      final font = DocxFont(
        asciiTheme: 'majorHAnsi',
        hAnsiTheme: 'majorHAnsi',
        eastAsiaTheme: 'majorEastAsia',
        csTheme: 'majorBidi',
      );
      final text = DocxText('Theme Test', fonts: font);
      final builder = XmlBuilder();
      text.buildXml(builder);

      final xml = builder.buildDocument().toXmlString();
      expect(xml, contains('w:asciiTheme="majorHAnsi"'));
      expect(xml, contains('w:hAnsiTheme="majorHAnsi"'));
      expect(xml, contains('w:eastAsiaTheme="majorEastAsia"'));
      expect(xml, contains('w:csTheme="majorBidi"'));
    });

    test('DocxText builds XML with legacy fontFamily (backward compatibility)',
        () {
      final text = DocxText('Test', fontFamily: 'Comic Sans');
      final builder = XmlBuilder();
      text.buildXml(builder);

      final xml = builder.buildDocument().toXmlString();
      expect(xml, contains('w:rFonts'));
      expect(xml, contains('w:ascii="Comic Sans"'));
    });
  });

  group('Table Fidelity', () {
    test('DocxTable calculates w:tblLook hex correctly (default)', () {
      final look = DocxTableLook();
      expect(look.hex, equals('04A0'));
    });

    test('DocxTable calculates w:tblLook hex correctly (custom)', () {
      final look = DocxTableLook(
        firstRow: true, // 0020
        lastRow: true, // 0040
        firstColumn: false,
        lastColumn: true, // 0100
        noHBand: true, // 0200
        noVBand: false,
      );
      // Sum: 0020 + 0040 + 0100 + 0200 = 0360
      expect(look.hex, equals('0360'));
    });
  });
}
