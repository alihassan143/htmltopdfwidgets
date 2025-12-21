import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML Parser Color Collision Tests', () {
    test('Scenario A: Foreground Only', () async {
      // Test: <span style="color: #FF0000;">Red Text</span>
      final html = '<p><span style="color: #FF0000;">Red Text</span></p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      expect(nodes.first, isA<DocxParagraph>());

      final para = nodes.first as DocxParagraph;
      expect(para.children.length, 1);
      expect(para.children.first, isA<DocxText>());

      final text = para.children.first as DocxText;
      expect(text.content, 'Red Text');
      expect(text.color?.hex, 'FF0000', reason: 'Text color should be red');
      expect(text.shadingFill, isNull, reason: 'No background specified');
    });

    test('Scenario B: Background Only', () async {
      // Test: <span style="background-color: #FFFF00;">Yellow Background</span>
      final html =
          '<p><span style="background-color: #FFFF00;">Yellow Background</span></p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.first as DocxParagraph;
      final text = para.children.first as DocxText;

      expect(text.content, 'Yellow Background');
      expect(text.shadingFill, 'FFFF00', reason: 'Background should be yellow');
    });

    test('Scenario C: Collision Case (Foreground + Background)', () async {
      // Test: <span style="color: #FF0000; background-color: #FFFF00;">Red on Yellow</span>
      final html =
          '<p><span style="color: #FF0000; background-color: #FFFF00;">Red on Yellow</span></p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.first as DocxParagraph;
      final text = para.children.first as DocxText;

      expect(text.content, 'Red on Yellow');
      expect(text.color?.hex, 'FF0000',
          reason: 'Text color should be red (not overwritten)');
      expect(text.shadingFill, 'FFFF00',
          reason: 'Background should be yellow (not overwritten)');
    });

    test('Scenario C2: Reverse Order (Background first, then Foreground)',
        () async {
      // Test: <span style="background-color: #FFFF00; color: #FF0000;">Red on Yellow</span>
      final html =
          '<p><span style="background-color: #FFFF00; color: #FF0000;">Red on Yellow Reversed</span></p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.first as DocxParagraph;
      final text = para.children.first as DocxText;

      expect(text.content, 'Red on Yellow Reversed');
      expect(text.color?.hex, 'FF0000', reason: 'Text color should be red');
      expect(text.shadingFill, 'FFFF00', reason: 'Background should be yellow');
    });

    test('Scenario D: Code Block with Nested Styles', () async {
      // Test: <pre><code style="background:#000;"><span style="color:#FFF;">White on Black Code</span></code></pre>
      final html =
          '<pre><code style="background-color:#000000;"><span style="color:#FFFFFF;">White on Black Code</span></code></pre>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      // Pre blocks become paragraphs with code text children
      final para = nodes.first as DocxParagraph;

      // At least one text element should exist
      expect(para.children, isNotEmpty);
    });

    test('Scenario E: Inline code with styles', () async {
      // Test: <span style="background-color: lightGray; color: black;">inline_code()</span>
      final html =
          '<p><span style="background-color: lightGray; color: black;">inline_code()</span></p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.first as DocxParagraph;
      final text = para.children.first as DocxText;

      expect(text.content, 'inline_code()');
      expect(text.color?.hex, '000000', reason: 'Text color should be black');
      expect(text.shadingFill, 'D3D3D3',
          reason: 'Background should be lightGray');
    });

    test('Scenario F: Verify XML output contains both w:color and w:shd',
        () async {
      // Create a text run with both color and shading
      final textRun = DocxText(
        'Red on Yellow',
        color: DocxColor('#FF0000'),
        shadingFill: 'FFFF00',
      );

      final doc = DocxDocumentBuilder()
          .paragraph(DocxParagraph(children: [textRun]))
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
      );
      final documentXml = String.fromCharCodes(documentFile.content);

      // Should contain both color and shading in run properties
      expect(documentXml, contains('<w:color w:val="FF0000"/>'),
          reason: 'XML should have red color');
      expect(documentXml, contains('<w:shd'),
          reason: 'XML should have shading element');
      expect(documentXml, contains('w:fill="FFFF00"'),
          reason: 'XML should have yellow fill');
    });
  });
}
