import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/docx_reader/models/docx_relationship.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/block_parser.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/inline_parser.dart';
import 'package:docx_creator/src/reader/docx_reader/reader_context/reader_context.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('TOC Generation', () {
    test('DocxTableOfContents builds valid SDT XML', () {
      final toc = DocxTableOfContents(
        instruction: 'TOC \\o "1-3" \\h \\z \\u',
        updateOnOpen: true,
        cachedContent: [
          DocxParagraph.text('Cached Heading'),
        ],
      );

      final builder = XmlBuilder();
      toc.buildXml(builder);
      final xml = builder.buildDocument().toXmlString(pretty: true);

      expect(xml, contains('<w:sdt>'));
      expect(xml, contains('<w:docPartGallery w:val="Table of Contents"/>'));
      expect(
          xml,
          contains(
              '<w:instrText xml:space="preserve">TOC \\o "1-3" \\h \\z \\u</w:instrText>'));
      expect(
          xml,
          contains(
              'w:dirty="true"')); // updateOnOpen attribute inside w:fldChar
      expect(xml, contains('Cached Heading')); // Content
    });

    test('BlockParser parses TOC from SDT', () {
      final inputXml = '''
      <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:sdt>
          <w:sdtPr>
            <w:docPartObj>
              <w:docPartGallery w:val="Table of Contents"/>
            </w:docPartObj>
          </w:sdtPr>
          <w:sdtContent>
            <w:p><w:r><w:t>TOC Entry</w:t></w:r></w:p>
          </w:sdtContent>
        </w:sdt>
      </w:body> 
      ''';

      final element = XmlDocument.parse(inputXml).rootElement;
      final context = ReaderContext(Archive()); // Mock archive
      final parser = BlockParser(context);

      final blocks = parser.parseBody(element);

      expect(blocks.length, equals(1));
      expect(blocks.first, isA<DocxTableOfContents>());
      final toc = blocks.first as DocxTableOfContents;
      expect(toc.cachedContent.length, equals(1));
    });
  });

  group('Floating Images', () {
    test('InlineParser parses floating image anchor attributes', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('word/image.png', 4, [1, 2, 3, 4]));

      final inputXml = '''
      <w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
           xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
           xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
           xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
           xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <w:drawing>
          <wp:anchor distT="100" distB="200" distL="300" distR="400" simplePos="1" relativeHeight="500">
             <wp:simplePos x="0" y="0"/>
             <wp:positionH relativeFrom="column"><wp:posOffset>0</wp:posOffset></wp:positionH>
             <wp:positionV relativeFrom="paragraph"><wp:posOffset>0</wp:posOffset></wp:positionV>
             <wp:extent cx="914400" cy="914400"/>
             <wp:docPr id="1" name="Picture 1"/>
             <a:graphic>
               <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                 <pic:pic>
                    <pic:nvPicPr>
                        <pic:cNvPr id="1" name="img"/>
                        <pic:cNvPicPr/>
                    </pic:nvPicPr>
                    <pic:blipFill><a:blip r:embed="rId1"/></pic:blipFill>
                    <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1" cy="1"/></a:xfrm><a:prstGeom prst="rect"/></pic:spPr>
                 </pic:pic>
               </a:graphicData>
             </a:graphic>
          </wp:anchor>
        </w:drawing>
      </w:r>
      ''';

      final element = XmlDocument.parse(inputXml).rootElement;
      final context = ReaderContext(archive);
      // Mock relationship
      context.relationships['rId1'] = DocxRelationship(
        id: 'rId1',
        target: 'image.png',
        type:
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
      );

      final parser = InlineParser(context);
      final inlines = parser.parseRun(element);

      // parseRun returns DocxInlineImage directly if handled?
      // No, InlineParser.parseRun returns DocxInline.
      // Wait, InlineParser calls _parseDrawing.

      expect(inlines, isA<DocxInlineImage>());
      final img = inlines as DocxInlineImage;

      expect(img.positionMode, equals(DocxDrawingPosition.floating));
      expect(img.distT, equals(100));
      expect(img.distB, equals(200));
      expect(img.distL, equals(300));
      expect(img.distR, equals(400));
      expect(img.simplePos, isTrue);
      expect(img.relativeHeight, equals(500));
    });
  });
}
