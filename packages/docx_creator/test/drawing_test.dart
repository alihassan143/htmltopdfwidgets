import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxShape Drawing Tests', () {
    test('Creates inline rectangle shape', () async {
      final shape = DocxShape.rectangle(
        width: 100,
        height: 60,
        fillColor: DocxColor.blue,
        outlineColor: DocxColor.black,
        outlineWidth: 2,
      );

      expect(shape.width, 100);
      expect(shape.height, 60);
      expect(shape.preset, DocxShapePreset.rect);
      expect(shape.position, DocxDrawingPosition.inline);
      expect(shape.fillColor?.hex, '0000FF');
    });

    test('Creates inline ellipse shape', () async {
      final shape = DocxShape.ellipse(
        width: 80,
        height: 80,
        fillColor: DocxColor.red,
      );

      expect(shape.width, 80);
      expect(shape.height, 80);
      expect(shape.preset, DocxShapePreset.ellipse);
    });

    test('Creates circle shape', () async {
      final shape = DocxShape.circle(
        diameter: 50,
        fillColor: DocxColor.green,
      );

      expect(shape.width, 50);
      expect(shape.height, 50);
      expect(shape.preset, DocxShapePreset.ellipse);
    });

    test('Creates triangle shape', () async {
      final shape = DocxShape.triangle(
        width: 100,
        height: 100,
        fillColor: DocxColor.yellow,
      );

      expect(shape.preset, DocxShapePreset.triangle);
    });

    test('Creates star shape', () async {
      final shape5 = DocxShape.star(points: 5, fillColor: DocxColor.gold);
      final shape4 = DocxShape.star(points: 4, fillColor: DocxColor.gold);
      final shape6 = DocxShape.star(points: 6, fillColor: DocxColor.gold);

      expect(shape5.preset, DocxShapePreset.star5);
      expect(shape4.preset, DocxShapePreset.star4);
      expect(shape6.preset, DocxShapePreset.star6);
    });

    test('Creates arrow shapes', () async {
      final rightArrow = DocxShape.rightArrow(
        width: 100,
        height: 40,
        fillColor: DocxColor.blue,
      );

      final leftArrow = DocxShape.leftArrow(
        width: 100,
        height: 40,
        fillColor: DocxColor.red,
      );

      expect(rightArrow.preset, DocxShapePreset.rightArrow);
      expect(leftArrow.preset, DocxShapePreset.leftArrow);
    });

    test('Creates diamond shape', () async {
      final shape = DocxShape.diamond(
        width: 80,
        height: 80,
        fillColor: DocxColor.purple,
      );

      expect(shape.preset, DocxShapePreset.diamond);
    });

    test('Creates line shape', () async {
      final shape = DocxShape.line(
        width: 200,
        outlineColor: DocxColor.black,
        outlineWidth: 2,
      );

      expect(shape.preset, DocxShapePreset.line);
      expect(shape.fillColor, isNull);
    });

    test('Creates floating shape', () async {
      final shape = DocxShape(
        width: 100,
        height: 100,
        preset: DocxShapePreset.rect,
        position: DocxDrawingPosition.floating,
        fillColor: DocxColor.blue,
        horizontalFrom: DocxHorizontalPositionFrom.page,
        verticalFrom: DocxVerticalPositionFrom.page,
        horizontalAlign: DrawingHAlign.center,
        verticalAlign: DrawingVAlign.top,
        textWrap: DocxTextWrap.square,
      );

      expect(shape.position, DocxDrawingPosition.floating);
      expect(shape.horizontalFrom, DocxHorizontalPositionFrom.page);
      expect(shape.textWrap, DocxTextWrap.square);
    });

    test('Shape with text content', () async {
      final shape = DocxShape.rectangle(
        width: 150,
        height: 80,
        fillColor: DocxColor.lightGray,
        text: 'Hello World',
      );

      expect(shape.text, 'Hello World');
    });

    test('DocxShapeBlock creates block-level shape', () async {
      final shapeBlock = DocxShapeBlock.rectangle(
        width: 200,
        height: 100,
        fillColor: DocxColor.blue,
        align: DocxAlign.center,
      );

      expect(shapeBlock.align, DocxAlign.center);
      expect(shapeBlock.shape.width, 200);
    });

    test('Shape exports to valid DOCX', () async {
      final doc = DocxDocumentBuilder()
          .p('Here is a shape:')
          .add(DocxShapeBlock.rectangle(
            width: 100,
            height: 60,
            fillColor: DocxColor.blue,
            outlineColor: DocxColor.black,
          ))
          .p('Shape above.')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify document.xml exists and contains drawing elements
      final documentFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
      );
      final documentXml = String.fromCharCodes(documentFile.content);

      expect(documentXml, contains('w:drawing'));
      expect(documentXml, contains('wp:inline'));
      expect(documentXml, contains('wsp:wsp'));
      expect(documentXml, contains('a:prstGeom'));
    });

    test('Multiple shapes in document', () async {
      final doc = DocxDocumentBuilder()
          .p('Shapes demo:')
          .add(DocxShapeBlock.rectangle(
            width: 100,
            height: 50,
            fillColor: DocxColor.red,
          ))
          .add(DocxShapeBlock.ellipse(
            width: 80,
            height: 80,
            fillColor: DocxColor.green,
          ))
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);

      expect(bytes.isNotEmpty, true);
    });

    test('Shape round-trip (write then read)', () async {
      // Create document with shapes
      final doc = DocxDocumentBuilder()
          .p('Test shapes:')
          .add(DocxShapeBlock.rectangle(
            width: 150,
            height: 80,
            fillColor: DocxColor.blue,
            outlineColor: DocxColor.black,
            outlineWidth: 2,
          ))
          .build();

      // Export to bytes
      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);

      // Read back
      final readDoc = await DocxReader.loadFromBytes(bytes);

      // Verify document was read
      expect(readDoc.elements.length, greaterThanOrEqualTo(2));

      // Find the paragraph containing shape
      bool foundShape = false;
      for (final element in readDoc.elements) {
        if (element is DocxParagraph) {
          for (final child in element.children) {
            if (child is DocxShape) {
              foundShape = true;
              expect(child.preset, DocxShapePreset.rect);
              expect(child.width, closeTo(150, 1));
              expect(child.height, closeTo(80, 1));
              expect(child.fillColor?.hex, '0000FF');
              expect(child.outlineColor?.hex, '000000');
            }
          }
        }
      }

      expect(foundShape, true,
          reason: 'Shape should be found in read document');
    });
  });
}
