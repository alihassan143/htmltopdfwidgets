import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('DocxText XML with default serialization should preserve spaces', () {
    final text = DocxText('Red ', color: DocxColor.red);
    final builder = XmlBuilder();
    text.buildXml(builder);
    final xml = builder.buildDocument().toXmlString();

    print('Generated DocxText XML:\n$xml');
    // Check if space is preserved
    expect(xml, contains('xml:space="preserve"'));
    expect(xml, contains('>Red <'));
  });

  test('XmlBuilder itself with default serialization and xml:space', () {
    final builder = XmlBuilder();
    builder.element('w:t', nest: () {
      builder.attribute('xml:space', 'preserve');
      builder.text('Red ');
    });
    final xml = builder.buildDocument().toXmlString();
    print('Raw XmlBuilder:\n$xml');
    expect(xml, contains('xml:space="preserve"'));
    expect(xml, contains('>Red <'));
  });

  test('Full DocxParagraph serialization should preserve spaces', () {
    final p = DocxParagraph(
      children: [
        DocxText('Red ', color: DocxColor.red),
        DocxText('Blue ', color: DocxColor.blue),
      ],
    );
    final builder = XmlBuilder();
    p.buildXml(builder);
    final xml = builder.buildDocument().toXmlString();

    print('Generated Paragraph XML:\n$xml');
    expect(xml, contains('>Red <'));
    expect(xml, contains('>Blue <'));
  });
}
