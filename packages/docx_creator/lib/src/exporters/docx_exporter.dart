import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../ast/docx_image.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../builder/docx_document_builder.dart';
import '../core/exceptions.dart';

/// Exports [DocxBuiltDocument] to .docx format.
class DocxExporter {
  final Map<String, Uint8List> _images = {};
  int _imageCounter = 0;
  int _uniqueIdCounter = 1;
  int _numIdCounter = 1;
  final List<bool> _listTypes = []; // true = ordered, false = bullet

  /// Exports the document to a file.
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    try {
      final bytes = await exportToBytes(doc);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      throw DocxExportException(
        'Failed to write file: $e',
        targetFormat: 'DOCX',
        context: filePath,
      );
    }
  }

  /// Exports the document to bytes.
  Future<Uint8List> exportToBytes(DocxBuiltDocument doc) async {
    _images.clear();
    _imageCounter = 0;
    _uniqueIdCounter = 1;
    _numIdCounter = 1;
    _listTypes.clear();

    // Process images and lists first
    for (var element in doc.elements) {
      if (element is DocxImage) {
        _imageCounter++;
        final rId = 'rId${_imageCounter + 10}';
        element.setRelationshipId(rId, _uniqueIdCounter++);
        _images['word/media/image$_imageCounter.${element.extension}'] =
            element.bytes;
      } else if (element is DocxList) {
        element.numId = _numIdCounter++;
        _listTypes.add(element.isOrdered);
      }
    }

    final archive = Archive();

    archive.addFile(_createContentTypes());
    archive.addFile(_createRootRels());
    archive.addFile(_createDocument(doc));
    archive.addFile(_createDocumentRels());
    archive.addFile(_createSettings());
    archive.addFile(_createStyles());
    archive.addFile(_createFontTable());
    archive.addFile(_createNumbering());

    // Headers and Footers
    if (doc.section?.header != null) {
      archive.addFile(_createHeader(doc.section!.header!));
    }
    if (doc.section?.footer != null) {
      archive.addFile(_createFooter(doc.section!.footer!));
    }

    // Images
    for (var entry in _images.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    if (bytes.isEmpty) {
      throw DocxExportException('Failed to encode ZIP', targetFormat: 'DOCX');
    }

    return Uint8List.fromList(bytes);
  }

  ArchiveFile _createContentTypes() {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Types',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/content-types',
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'rels');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-package.relationships+xml',
            );
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'xml');
            builder.attribute('ContentType', 'application/xml');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'png');
            builder.attribute('ContentType', 'image/png');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'jpeg');
            builder.attribute('ContentType', 'image/jpeg');
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/document.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/styles.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/settings.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/fontTable.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/numbering.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml',
            );
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      '[Content_Types].xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createRootRels() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId1');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
            );
            builder.attribute('Target', 'word/document.xml');
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      '_rels/.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createDocument(DocxBuiltDocument doc) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:document',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        builder.attribute(
          'xmlns:wp',
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
        );
        builder.attribute(
          'xmlns:r',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        );

        // Add background color if specified
        if (doc.section?.backgroundColor != null) {
          builder.element(
            'w:background',
            nest: () {
              builder.attribute('w:color', doc.section!.backgroundColor!.hex);
            },
          );
        }

        builder.element(
          'w:body',
          nest: () {
            for (var element in doc.elements) {
              element.buildXml(builder);
            }
            if (doc.section != null) {
              doc.section!.buildXml(builder);
            }
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      'word/document.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createDocumentRels() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId1');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles',
            );
            builder.attribute('Target', 'styles.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId2');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings',
            );
            builder.attribute('Target', 'settings.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId3');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable',
            );
            builder.attribute('Target', 'fontTable.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId4');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering',
            );
            builder.attribute('Target', 'numbering.xml');
          },
        );
        // Images
        int rIdOffset = 10;
        for (int i = 0; i < _images.length; i++) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rId${rIdOffset + i + 1}');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              );
              final ext = _images.keys.elementAt(i).split('.').last;
              builder.attribute('Target', 'media/image${i + 1}.$ext');
            },
          );
        }
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      'word/_rels/document.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createSettings() {
    final xml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:compat/><w:displayBackgroundShape/></w:settings>';
    return ArchiveFile(
      'word/settings.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createStyles() {
    final xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr><w:spacing w:after="200" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/><w:b/><w:sz w:val="48"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="200"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="40"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720"/></w:pPr></w:style>
  <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>
</w:styles>''';
    return ArchiveFile(
      'word/styles.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFontTable() {
    final xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="Calibri"><w:panose1 w:val="020F0502020204030204"/></w:font>
  <w:font w:name="Calibri Light"><w:panose1 w:val="020F0302020204030204"/></w:font>
  <w:font w:name="Times New Roman"><w:panose1 w:val="02020603050405020304"/></w:font>
  <w:font w:name="Courier New"><w:panose1 w:val="02070309020205020404"/></w:font>
  <w:font w:name="Symbol"><w:panose1 w:val="05050102010706020507"/></w:font>
</w:fonts>''';
    return ArchiveFile(
      'word/fontTable.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createNumbering() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );

    // Abstract numbering for bullets (abstractNumId=0)
    buffer.writeln('''
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr></w:lvl>
    <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="○"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr></w:lvl>
    <w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="▪"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr></w:lvl>
  </w:abstractNum>''');

    // Abstract numbering for decimal numbers (abstractNumId=1)
    buffer.writeln('''
  <w:abstractNum w:abstractNumId="1">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>
    <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%2."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr></w:lvl>
    <w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="lowerRoman"/><w:lvlText w:val="%3."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr></w:lvl>
  </w:abstractNum>''');

    // Generate num instances linking to correct abstractNumId
    for (int i = 0; i < _listTypes.length; i++) {
      final numId = i + 1;
      final abstractNumId = _listTypes[i] ? 1 : 0; // ordered = 1, bullet = 0
      buffer.writeln(
        '  <w:num w:numId="$numId"><w:abstractNumId w:val="$abstractNumId"/></w:num>',
      );
    }

    buffer.writeln('</w:numbering>');
    final xml = buffer.toString();
    return ArchiveFile(
      'word/numbering.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createHeader(dynamic header) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:hdr',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        (header as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      'word/header1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFooter(dynamic footer) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:ftr',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        (footer as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    return ArchiveFile(
      'word/footer1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }
}
