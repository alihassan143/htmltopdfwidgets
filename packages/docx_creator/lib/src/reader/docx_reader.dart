import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../docx_creator.dart';

/// Reads and edits existing .docx files.
class DocxReader {
  /// Loads a .docx file and returns a [DocxBuiltDocument] that can be modified and saved.
  static Future<DocxBuiltDocument> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    return loadFromBytes(bytes);
  }

  /// Loads a .docx file from bytes.
  static Future<DocxBuiltDocument> loadFromBytes(Uint8List bytes) async {
    return _DocxReaderInternal(bytes).read();
  }
}

/// Internal reader class to maintain state during parsing.
class _DocxReaderInternal {
  final Archive archive;
  final Map<String, _DocxRelationship> _documentRelationships = {};
  final Map<String, String> _contentTypes = {}; // PartName -> ContentType

  _DocxReaderInternal(Uint8List bytes)
      : archive = ZipDecoder().decodeBytes(bytes);

  Future<DocxBuiltDocument> read() async {
    // 1. Read Content Types
    _readContentTypes();

    // 2. Read Document Relationships
    _readDocumentRelationships();

    // 3. Read Document Content
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw Exception('Invalid docx file: missing word/document.xml');
    }

    final documentXml =
        XmlDocument.parse(utf8.decode(documentFile.content as List<int>));

    // Parse Body
    final body = documentXml.findAllElements('w:body').first;
    final elements = _parseBody(body);

    // Parse Section Properties
    final section = _parseSectionProperties(body);

    // Read Styles and Numbering (Raw)
    final stylesXml = _readXmlContent('word/styles.xml');
    final numberingXml = _readXmlContent('word/numbering.xml');
    final settingsXml = _readXmlContent('word/settings.xml');
    final fontTableXml = _readXmlContent('word/fontTable.xml');
    final contentTypesXml = _readXmlContent('[Content_Types].xml');
    final rootRelsXml = _readXmlContent('_rels/.rels');
    final headerBgXml = _readXmlContent('word/header_bg.xml');
    final headerBgRelsXml = _readXmlContent('word/_rels/header_bg.xml.rels');

    return DocxBuiltDocument(
      elements: elements,
      section: section,
      stylesXml: stylesXml,
      numberingXml: numberingXml,
      settingsXml: settingsXml,
      fontTableXml: fontTableXml,
      contentTypesXml: contentTypesXml,
      rootRelsXml: rootRelsXml,
      headerBgXml: headerBgXml,
      headerBgRelsXml: headerBgRelsXml,
    );
  }

  String? _readXmlContent(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return utf8.decode(file.content as List<int>);
  }

  void _readContentTypes() {
    final file = archive.findFile('[Content_Types].xml');
    if (file != null) {
      final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
      for (var override in xml.findAllElements('Override')) {
        final partName = override.getAttribute('PartName');
        final contentType = override.getAttribute('ContentType');
        if (partName != null && contentType != null) {
          _contentTypes[partName] = contentType;
        }
      }
    }
  }

  void _readDocumentRelationships() {
    final file = archive.findFile('word/_rels/document.xml.rels');
    if (file != null) {
      final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
      for (var rel in xml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final type = rel.getAttribute('Type');
        final target = rel.getAttribute('Target');
        if (id != null && type != null && target != null) {
          _documentRelationships[id] = _DocxRelationship(id, type, target);
        }
      }
    }
  }

  List<DocxNode> _parseBody(XmlElement body) {
    final nodes = <DocxNode>[];

    for (var child in body.children) {
      if (child is XmlElement) {
        if (child.name.local == 'p') {
          nodes.add(_parseParagraph(child));
        } else if (child.name.local == 'tbl') {
          nodes.add(_parseTable(child));
        } else if (child.name.local == 'sectPr') {
          // Handled separately
          continue;
        } else {
          // Provide raw XML preservation for unknown nodes
          nodes.add(DocxRawXml(child.toXmlString()));
        }
      }
    }
    return nodes;
  }

  DocxParagraph _parseParagraph(XmlElement xml) {
    final children = <DocxInline>[];
    String? pStyle;
    DocxAlign align = DocxAlign.left;

    // Parse paragraph properties
    final pPr = xml.getElement('w:pPr');
    if (pPr != null) {
      // Style
      final pStyleElem = pPr.getElement('w:pStyle');
      if (pStyleElem != null) {
        pStyle = pStyleElem.getAttribute('w:val');
      }

      // Alignment
      final jcElem = pPr.getElement('w:jc');
      if (jcElem != null) {
        final val = jcElem.getAttribute('w:val');
        if (val == 'center') align = DocxAlign.center;
        if (val == 'right') align = DocxAlign.right;
        if (val == 'both' || val == 'distribute') align = DocxAlign.justify;
      }

      // TODO: Numbering/Lists
    }

    // Parse runs and other inline content
    for (var child in xml.children) {
      if (child is XmlElement) {
        if (child.name.local == 'r') {
          children.add(_parseRun(child));
        } else if (child.name.local == 'hyperlink') {
          // TODO: Handle hyperlinks more gracefully
          // For now, flatten content
          for (var grandChild in child.findAllElements('w:r')) {
            children.add(_parseRun(grandChild));
          }
        }
      }
    }

    return DocxParagraph(
      children: children,
      styleId: pStyle,
      align: align,
    );
  }

  DocxInline _parseRun(XmlElement run) {
    // Check for drawings (Images)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      final blip = drawing.findAllElements('a:blip').firstOrNull ??
          drawing.findAllElements('v:imagedata').firstOrNull;
      if (blip != null) {
        final embedId =
            blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
        if (embedId != null && _documentRelationships.containsKey(embedId)) {
          return _readImage(embedId, drawing);
        }
      }
    }

    // Check for line break
    if (run.findAllElements('w:br').isNotEmpty) {
      return const DocxLineBreak();
    }
    // Check for tab
    if (run.findAllElements('w:tab').isNotEmpty) {
      return const DocxTab();
    }

    // Parse formatting
    var fontWeight = DocxFontWeight.normal;
    var fontStyle = DocxFontStyle.normal;
    var decoration = DocxTextDecoration.none;
    DocxColor? color;
    double? fontSize;
    String? fontFamily;

    final rPr = run.getElement('w:rPr');
    if (rPr != null) {
      if (rPr.getElement('w:b') != null) fontWeight = DocxFontWeight.bold;
      if (rPr.getElement('w:i') != null) fontStyle = DocxFontStyle.italic;
      if (rPr.getElement('w:u') != null) {
        decoration = DocxTextDecoration.underline;
      }
      if (rPr.getElement('w:strike') != null) {
        decoration = DocxTextDecoration.strikethrough;
      }

      final colorElem = rPr.getElement('w:color');
      if (colorElem != null) {
        final val = colorElem.getAttribute('w:val');
        if (val != null && val != 'auto') {
          color = DocxColor('#$val');
        }
      }

      final szElem = rPr.getElement('w:sz');
      if (szElem != null) {
        final val = szElem.getAttribute('w:val');
        if (val != null) {
          final halfPoints = int.tryParse(val);
          if (halfPoints != null) {
            fontSize = halfPoints / 2.0;
          }
        }
      }

      final rFonts = rPr.getElement('w:rFonts');
      if (rFonts != null) {
        fontFamily = rFonts.getAttribute('w:ascii');
      }
    }

    final textElem = run.getElement('w:t');
    if (textElem != null) {
      return DocxText(
        textElem.innerText,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: decoration,
        color: color,
        fontSize: fontSize,
        fontFamily: fontFamily,
      );
    }

    // Fallback for unknown run content
    return DocxRawInline(run.toXmlString());
  }

  DocxInlineImage _readImage(String rId, XmlElement drawingNode) {
    final rel = _documentRelationships[rId]!;
    // Target is relative to word/ directory usually, e.g. "media/image1.png"
    // But in relationships file it might be "media/image1.png" or "/word/media/image1.png"

    String targetPath = rel.target;
    if (!targetPath.startsWith('/')) {
      targetPath = 'word/$targetPath';
    } else {
      targetPath = targetPath.substring(1); // remove leading /
    }

    final imageFile = archive.findFile(targetPath);
    if (imageFile == null) {
      // Flatten fallback
      return DocxInlineImage(bytes: Uint8List(0), extension: 'png');
      // Note: Returning empty image or throw?
      // Better: fall back to raw if possible but we need to return DocxInline.
      // DocxRawInline is DocxInline.
      // Check return type signature.
    }

    final extension = targetPath.split('.').last;

    // Try to determine dimensions from extent
    // <wp:extent cx="1270000" cy="1270000"/> (IMUs)
    // 1 pt = 12700 EMU
    double width = 100;
    double height = 100;

    final extent = drawingNode.findAllElements('wp:extent').firstOrNull;
    if (extent != null) {
      final cx = int.tryParse(extent.getAttribute('cx') ?? '');
      final cy = int.tryParse(extent.getAttribute('cy') ?? '');
      if (cx != null && cy != null) {
        width = cx / 12700.0;
        height = cy / 12700.0;
      }
    }

    // Alignment (found in pPr usually, but image object has one too)
    // Currently DocxReader doesn't pass down paragraph alignment easily to children,
    // but DocxImage usually aligns itself if block-level, or is inline.

    return DocxInlineImage(
      bytes: Uint8List.fromList(imageFile.content as List<int>),
      extension: extension,
      width: width,
      height: height,
      // align: ... derived from paragraph or defaults
    );
  }

  DocxTable _parseTable(XmlElement xml) {
    final rows = <DocxTableRow>[];
    for (var child in xml.findAllElements('w:tr')) {
      final cells = <DocxTableCell>[];
      for (var cell in child.findAllElements('w:tc')) {
        final cellContent = <DocxBlock>[];
        // Parse cell content
        for (var p in cell.findAllElements('w:p')) {
          cellContent.add(_parseParagraph(p));
        }
        // TODO: Tables can also contain other tables, checking recursively would be good
        cells.add(DocxTableCell(children: cellContent));
      }
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows);
  }

  DocxSectionDef _parseSectionProperties(XmlElement body) {
    // Find the last sectPr
    final sectPr = body.getElement('w:sectPr');

    DocxPageSize pageSize = DocxPageSize.letter;
    DocxPageOrientation orientation = DocxPageOrientation.portrait;
    int? customWidth;
    int? customHeight;
    int marginTop = kDefaultMarginTop;
    int marginBottom = kDefaultMarginBottom;
    int marginLeft = kDefaultMarginLeft;
    int marginRight = kDefaultMarginRight;
    DocxHeader? header;
    DocxFooter? footer;

    if (sectPr != null) {
      // Page Size
      final pgSz = sectPr.getElement('w:pgSz');
      if (pgSz != null) {
        final w = int.tryParse(pgSz.getAttribute('w:w') ?? '12240') ?? 12240;
        final h = int.tryParse(pgSz.getAttribute('w:h') ?? '15840') ?? 15840;
        final orient = pgSz.getAttribute('w:orient');

        if (orient == 'landscape') {
          orientation = DocxPageOrientation.landscape;
        }

        // Simple check for standard sizes
        if ((w == 12240 && h == 15840) || (w == 15840 && h == 12240)) {
          pageSize = DocxPageSize.letter;
        } else if ((w == 11906 && h == 16838) || (w == 16838 && h == 11906)) {
          pageSize = DocxPageSize.a4;
        } else {
          pageSize = DocxPageSize.custom;
          customWidth = w;
          customHeight = h;
        }
      }

      // Margins
      final pgMar = sectPr.getElement('w:pgMar');
      if (pgMar != null) {
        marginTop =
            int.tryParse(pgMar.getAttribute('w:top') ?? '') ?? marginTop;
        marginBottom =
            int.tryParse(pgMar.getAttribute('w:bottom') ?? '') ?? marginBottom;
        marginLeft =
            int.tryParse(pgMar.getAttribute('w:left') ?? '') ?? marginLeft;
        marginRight =
            int.tryParse(pgMar.getAttribute('w:right') ?? '') ?? marginRight;
      }

      // Headers and Footers
      for (var headerRef in sectPr.findAllElements('w:headerReference')) {
        final rId = headerRef.getAttribute('r:id');
        if (rId != null && _documentRelationships.containsKey(rId)) {
          // Only handling 'default' for now for simplicity, or just taking the first one
          // TODO: Handle 'first' and 'even'
          header = _readHeader(_documentRelationships[rId]!);
        }
      }

      for (var footerRef in sectPr.findAllElements('w:footerReference')) {
        final rId = footerRef.getAttribute('r:id');
        if (rId != null && _documentRelationships.containsKey(rId)) {
          footer = _readFooter(_documentRelationships[rId]!);
        }
      }
    }

    return DocxSectionDef(
      pageSize: pageSize,
      orientation: orientation,
      customWidth: customWidth,
      customHeight: customHeight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      marginLeft: marginLeft,
      marginRight: marginRight,
      header: header,
      footer: footer,
    );
  }

  DocxHeader? _readHeader(_DocxRelationship rel) {
    final xml = _readXmlFile(rel.target);
    if (xml == null) return null;

    final nodes = <DocxBlock>[];
    // Headers behave like body, so parse paragraphs
    for (var child in xml.rootElement.children) {
      if (child is XmlElement && child.name.local == 'p') {
        nodes.add(_parseParagraph(child));
      } else if (child is XmlElement && child.name.local == 'tbl') {
        nodes.add(_parseTable(child));
      }
    }
    return DocxHeader(children: nodes);
  }

  DocxFooter? _readFooter(_DocxRelationship rel) {
    final xml = _readXmlFile(rel.target);
    if (xml == null) return null;

    final nodes = <DocxBlock>[];
    for (var child in xml.rootElement.children) {
      if (child is XmlElement && child.name.local == 'p') {
        nodes.add(_parseParagraph(child));
      } else if (child is XmlElement && child.name.local == 'tbl') {
        nodes.add(_parseTable(child));
      }
    }
    return DocxFooter(children: nodes);
  }

  XmlDocument? _readXmlFile(String target) {
    String targetPath = target;
    if (!targetPath.startsWith('/')) {
      targetPath = 'word/$targetPath';
    } else {
      targetPath = targetPath.substring(1);
    }

    final file = archive.findFile(targetPath);
    if (file == null) return null;
    return XmlDocument.parse(utf8.decode(file.content as List<int>));
  }
}

class _DocxRelationship {
  final String id;
  final String type;
  final String target;

  _DocxRelationship(this.id, this.type, this.target);
}
