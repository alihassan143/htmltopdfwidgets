import 'package:docx_creator/docx_creator.dart'; // Should export DocxSectionBreakBlock
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Section Break', () {
    test('DocxDocumentBuilder adds section break block', () {
      final builder = DocxDocumentBuilder();
      builder.h1('Page 1');

      builder.addSectionBreak(DocxSectionDef(
        orientation: DocxPageOrientation.landscape,
        marginTop: 1000,
      ));

      final doc = builder.build();
      expect(doc.elements.length, 2);
      expect(doc.elements[1], isA<DocxSectionBreakBlock>());

      final block = doc.elements[1] as DocxSectionBreakBlock;
      expect(block.section.orientation, DocxPageOrientation.landscape);
    });

    test('DocxSectionBreakBlock generates correct XML', () {
      final section = DocxSectionDef(
        orientation: DocxPageOrientation.landscape,
        marginTop: 1000,
      );
      final breakBlock = DocxSectionBreakBlock(section);

      final builder = XmlBuilder();
      breakBlock.buildXml(builder);

      final xml = builder.buildDocument().toXmlString();
      // Should be <w:p><w:pPr><w:sectPr>...
      expect(xml, contains('<w:p><w:pPr><w:sectPr>'));
      expect(xml, contains('w:orient="landscape"'));
      expect(xml, contains('w:top="1000"'));
    });
  });
}
