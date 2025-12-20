import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxColor', () {
    test('predefined colors', () {
      expect(DocxColor.red.hex, 'FF0000');
      expect(DocxColor.blue.hex, '0000FF');
      expect(DocxColor.black.hex, '000000');
    });

    test('custom hex color', () {
      final color = DocxColor('4285F4');
      expect(color.hex, '4285F4');
    });

    test('fromHex with # prefix', () {
      final color = DocxColor.fromHex('#FF5722');
      expect(color.hex, 'FF5722');
    });
  });

  group('DocxText', () {
    test('basic text', () {
      final text = DocxText('Hello');
      expect(text.content, 'Hello');
      expect(text.isBold, false);
    });

    test('bold text', () {
      final text = DocxText.bold('Bold');
      expect(text.isBold, true);
    });

    test('text with predefined color', () {
      final text = DocxText('Red', color: DocxColor.red);
      expect(text.effectiveColorHex, 'FF0000');
    });

    test('text with custom color', () {
      final text = DocxText('Custom', color: DocxColor('4285F4'));
      expect(text.effectiveColorHex, '4285F4');
    });

    test('superscript', () {
      final text = DocxText.superscript('2');
      expect(text.isSuperscript, true);
    });
  });

  group('DocxParagraph', () {
    test('simple text paragraph', () {
      final para = DocxParagraph.text('Hello');
      expect(para.children.length, 1);
    });

    test('heading levels', () {
      expect(DocxParagraph.heading1('H1').styleId, 'Heading1');
      expect(DocxParagraph.heading2('H2').styleId, 'Heading2');
      expect(DocxParagraph.heading3('H3').styleId, 'Heading3');
    });
  });

  group('DocxList', () {
    test('bullet list', () {
      final list = DocxList.bullet(['A', 'B', 'C']);
      expect(list.items.length, 3);
      expect(list.isOrdered, false);
    });

    test('numbered list', () {
      final list = DocxList.numbered(['1', '2', '3']);
      expect(list.isOrdered, true);
    });
  });

  group('DocxTable', () {
    test('from data', () {
      final table = DocxTable.fromData([
        ['A', 'B'],
        ['1', '2'],
      ]);
      expect(table.rows.length, 2);
    });

    test('styles', () {
      expect(DocxTableStyle.zebra.headerFill, 'E0E0E0');
      expect(DocxTableStyle.plain.border, DocxBorder.none);
    });
  });

  group('DocxDocumentBuilder', () {
    test('builds document', () {
      final doc = docx().h1('Title').p('Content').build();
      expect(doc.elements.length, 2);
    });

    test('with section', () {
      final doc =
          docx().section(header: DocxHeader.text('Header')).h1('Title').build();
      expect(doc.section?.header, isNotNull);
    });
  });

  group('DocxParser', () {
    test('parses HTML', () {
      final elements = DocxParser.fromHtml('<h1>Title</h1>');
      expect(elements.length, 1);
    });

    test('parses Markdown', () {
      final elements = DocxParser.fromMarkdown('# Title');
      expect(elements.length, 1);
    });
  });

  group('DocxExporter', () {
    test('exports to bytes', () async {
      final doc = docx().h1('Test').build();
      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
      // ZIP signature
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });

  group('HtmlExporter', () {
    test('exports to HTML', () {
      final doc = docx().h1('Title').build();
      final html = HtmlExporter().export(doc);
      expect(html.contains('<h1>'), true);
    });
  });

  group('DocxBackgroundImage', () {
    test('basic creation with defaults', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
      );
      expect(bg.fillMode, DocxBackgroundFillMode.stretch);
      expect(bg.opacity, 1.0);
      expect(bg.normalizedExtension, 'png');
    });

    test('normalizes jpg to jpeg', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'jpg',
      );
      expect(bg.normalizedExtension, 'jpeg');
    });

    test('normalizes tif to tiff', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'tif',
      );
      expect(bg.normalizedExtension, 'tiff');
    });

    test('tile fill mode returns correct VML type', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
        fillMode: DocxBackgroundFillMode.tile,
      );
      expect(bg.vmlFillType, 'tile');
    });

    test('stretch fill mode returns frame VML type', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
        fillMode: DocxBackgroundFillMode.stretch,
      );
      expect(bg.vmlFillType, 'frame');
    });

    test('content type for various formats', () {
      expect(
        DocxBackgroundImage(
          bytes: Uint8List.fromList([1]),
          extension: 'png',
        ).contentType,
        'image/png',
      );
      expect(
        DocxBackgroundImage(
          bytes: Uint8List.fromList([1]),
          extension: 'jpeg',
        ).contentType,
        'image/jpeg',
      );
      expect(
        DocxBackgroundImage(
          bytes: Uint8List.fromList([1]),
          extension: 'gif',
        ).contentType,
        'image/gif',
      );
    });

    test('section with background image', () {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
      );
      final doc = docx().section(backgroundImage: bg).h1('Title').build();
      expect(doc.section?.backgroundImage, isNotNull);
      expect(doc.section?.backgroundImage?.fillMode,
          DocxBackgroundFillMode.stretch);
    });

    test('exports document with background image', () async {
      final bg = DocxBackgroundImage(
        bytes: Uint8List.fromList([
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
          0xDE,
        ]),
        extension: 'png',
        opacity: 0.5,
      );
      final doc = docx().section(backgroundImage: bg).h1('Test').build();

      final bytes = await DocxExporter().exportToBytes(doc);
      expect(bytes.length, greaterThan(0));
      // ZIP signature
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });
}
