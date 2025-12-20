import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxReader Round-Trip', () {
    test('full document round-trip', () async {
      // 1. Create a complex document
      final dummyImageBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x02,
        0x00,
        0x00,
        0x00,
        0x90,
        0x77,
        0x53,
        0xDE
      ]); // Simple 1x1 PNG

      final header = DocxHeader(children: [
        DocxParagraph(children: [DocxText('Header Text')]),
      ]);

      final footer = DocxFooter(children: [
        DocxParagraph(children: [DocxText('Footer Text')]),
      ]);

      final inlineImage = DocxInlineImage(
          bytes: dummyImageBytes,
          extension: 'png',
          width: 100,
          height: 100,
          altText: 'Inline Image');

      final blockImage = DocxImage(
          bytes: dummyImageBytes,
          extension: 'png',
          width: 200,
          height: 200,
          altText: 'Block Image');

      final doc = docx()
          .section(
              header: header,
              footer: footer,
              pageSize: DocxPageSize.a4,
              orientation: DocxPageOrientation.landscape)
          .h1('Title')
          .p('Paragraph 1')
          .add(DocxParagraph(children: [
            DocxText('Text before image '),
            inlineImage,
            DocxText(' Text after image')
          ]))
          .table([
            ['Row 1 Col 1', 'Row 1 Col 2'],
            ['Row 2 Col 1', 'Row 2 Col 2']
          ])
          .image(blockImage)
          .build();

      // 2. Export to bytes
      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);

      // 3. Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);

      // 4. Verify Content

      // Verify Section Properties
      expect(readDoc.section, isNotNull);
      // Note: Parsing orientation/size happens in reader
      // Currently my reader implementation of section properties parses w:pgSz
      // Let's check if it did it correctly.
      expect(readDoc.section!.orientation, DocxPageOrientation.landscape);
      expect(readDoc.section!.pageSize, DocxPageSize.a4);

      // Verify Header/Footer
      expect(readDoc.section!.header, isNotNull);
      final readHeader = readDoc.section!.header!;
      expect(readHeader.children.length, 1);
      expect(
          (readHeader.children.first as DocxParagraph).children.first
              is DocxText,
          true);
      expect(
          ((readHeader.children.first as DocxParagraph).children.first
                  as DocxText)
              .content,
          'Header Text'); // Requires text extraction to be precise

      expect(readDoc.section!.footer, isNotNull);

      // Verify Elements
      final elements = readDoc.elements;
      // h1, p, p(with inline image), p(wrapping block image)
      // Note: block image DocxImage generates a w:p.
      // DocxReader reads strictly what's in body.
      // So structure might map slightly differently:
      // 1. Paragraph (Title)
      // 2. Paragraph (Paragraph 1)
      // 3. Paragraph (Text before...)
      // 4. Table
      // 5. Paragraph (Block Image)

      expect(elements.length, 5);

      // Check Heading
      final h1Para = elements[0] as DocxParagraph;
      expect(h1Para.children.first, isA<DocxText>());
      expect((h1Para.children.first as DocxText).content, 'Title');
      expect(h1Para.styleId, 'Heading1');

      // Check Inline Image Paragraph
      final inlineImgPara = elements[2] as DocxParagraph;
      expect(inlineImgPara.children.length, 3); // Text, Image, Text

      expect((inlineImgPara.children[0] as DocxText).content.trim(),
          'Text before image');
      expect(inlineImgPara.children[1], isA<DocxInlineImage>());
      final readInlineImg = inlineImgPara.children[1] as DocxInlineImage;
      expect(readInlineImg.width, closeTo(100, 0.1));
      expect(readInlineImg.extension, 'png');

      // Check Table
      expect(elements[3], isA<DocxTable>());
      final table = elements[3] as DocxTable;
      expect(table.rows.length, 2);
      expect(table.rows[0].cells.length, 2);
      // Verify cell content? DocxReader parses cell content as paragraphs.
      // Basic check
      final cell00 = table.rows[0].cells[0];
      expect(cell00.children.isNotEmpty, true);

      // Check Block Image
      final blockImgPara = elements[4] as DocxParagraph;
      expect(blockImgPara.children.length, 1);
      expect(blockImgPara.children.first, isA<DocxInlineImage>());

      // Verify IDs/Relationships were handled
      // Implicitly verified if image content is present
      // To strictly verify bytes, we could check readInlineImg.bytes length
      expect(readInlineImg.bytes.isNotEmpty, true);
    });
    test('preserves styles and numbering on round-trip', () async {
      // 1. Create a simple document (will generate default styles/numbering)
      final doc = docx().h1('Title').bullet(['Item 1']).build();

      // 2. Export (Generates default styles.xml and numbering.xml)
      final bytes1 = await DocxExporter().exportToBytes(doc);

      // 3. Read it back
      final readDoc1 = await DocxReader.loadFromBytes(bytes1);

      // Verify existence
      expect(readDoc1.stylesXml, isNotNull);
      expect(readDoc1.stylesXml, contains('w:style'));
      expect(readDoc1.numberingXml, isNotNull); // Because we used bullet()
      expect(readDoc1.numberingXml, contains('w:numbering'));

      // Verify other preserved parts
      expect(readDoc1.settingsXml, isNotNull);
      expect(readDoc1.fontTableXml, isNotNull);
      expect(readDoc1.contentTypesXml, isNotNull);
      expect(readDoc1.rootRelsXml, isNotNull);

      // 4. Export the READ document (should use the preserved XML)
      // We can't easily intercept the internal call, but we can check the consistency.
      final bytes2 = await DocxExporter().exportToBytes(readDoc1);

      // 5. Read it back AGAIN
      final readDoc2 = await DocxReader.loadFromBytes(bytes2);

      // Verify content is identical or at least structurally similar
      expect(readDoc2.stylesXml, equals(readDoc1.stylesXml));
      // Numbering IDs might change if re-generated, but since we preserve raw XML,
      // they should remain EXACTLY the same.
      expect(readDoc2.numberingXml, equals(readDoc1.numberingXml));
      expect(readDoc2.settingsXml, equals(readDoc1.settingsXml));
      expect(readDoc2.fontTableXml, equals(readDoc1.fontTableXml));
      expect(readDoc2.contentTypesXml, equals(readDoc1.contentTypesXml));
      expect(readDoc2.rootRelsXml, equals(readDoc1.rootRelsXml));
    });
  });
}
