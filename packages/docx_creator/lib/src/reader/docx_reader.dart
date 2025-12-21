import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../docx_creator.dart';
import '../core/font_manager.dart'; // Add import

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

    // Parse Document Background
    DocxColor? backgroundColor;
    final bgElem = documentXml.findAllElements('w:background').firstOrNull;
    if (bgElem != null) {
      final colorHex = bgElem.getAttribute('w:color');
      if (colorHex != null && colorHex != 'auto') {
        backgroundColor = DocxColor('#$colorHex');
      }
    }

    // Parse Section Properties
    final section =
        _parseSectionProperties(body, backgroundColor: backgroundColor);

    // Read Styles and Numbering (Raw)
    final stylesXml = _readXmlContent('word/styles.xml');
    final numberingXml = _readXmlContent('word/numbering.xml');
    final settingsXml = _readXmlContent('word/settings.xml');
    final fontTableXml = _readXmlContent('word/fontTable.xml');
    final contentTypesXml = _readXmlContent('[Content_Types].xml');
    final rootRelsXml = _readXmlContent('_rels/.rels');
    final headerBgXml = _readXmlContent('word/header_bg.xml');
    final headerBgRelsXml = _readXmlContent('word/_rels/header_bg.xml.rels');
    final fontTableRelsXml = _readXmlContent('word/_rels/fontTable.xml.rels');

    final fonts = _readFonts(fontTableXml, fontTableRelsXml);

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
      fonts: fonts,
    );
  }

  List<EmbeddedFont> _readFonts(
      String? fontTableXml, String? fontTableRelsXml) {
    if (fontTableXml == null || fontTableRelsXml == null) return [];

    final fonts = <EmbeddedFont>[];
    final ftXml = XmlDocument.parse(fontTableXml);
    final ftrXml = XmlDocument.parse(fontTableRelsXml);

    // Parse relationships
    final rels = <String, String>{}; // Id -> Target
    for (var rel in ftrXml.findAllElements('Relationship')) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id != null && target != null) rels[id] = target;
    }

    // Parse fonts
    for (var fontElem in ftXml.findAllElements('w:font')) {
      final name = fontElem.getAttribute('w:name');
      if (name == null) continue;

      // Check for embedded regular
      final embed = fontElem.findAllElements('w:embedRegular').firstOrNull;
      if (embed != null) {
        final id = embed.getAttribute('r:id');
        final key = embed.getAttribute('w:fontKey'); // {GUID}

        if (id != null && key != null && rels.containsKey(id)) {
          String target = rels[id]!;

          // Locate file in archive
          // Target usually relative to word/ e.g. "fonts/foo.odttf"
          // We need search: "word/" + target
          ArchiveFile? file;
          if (target.startsWith('/')) {
            target = target
                .substring(1); // absolute in zip? usually not used in rels.
            file = archive.findFile(target);
          } else {
            file = archive.findFile('word/$target');
          }

          if (file != null) {
            String cleanKey = key.replaceAll(RegExp(r'[{}]'), '');
            fonts.add(EmbeddedFont.fromObfuscated(
              familyName: name,
              obfuscatedBytes: Uint8List.fromList(file.content as List<int>),
              obfuscationKey: cleanKey,
            ));
          }
        }
      }
    }
    return fonts;
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
    return _parseBlocks(body.children);
  }

  DocxParagraph _parseParagraph(XmlElement xml) {
    final children = <DocxInline>[];
    String? pStyle;
    DocxAlign align = DocxAlign.left;
    String? shadingFill;
    int? numId;
    int? ilvl;
    int? spacingAfter;
    int? spacingBefore;
    int? lineSpacing;
    int? indentLeft;
    int? indentRight;
    int? indentFirstLine;

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
        if (val == 'right' || val == 'end') align = DocxAlign.right;
        if (val == 'both' || val == 'distribute') align = DocxAlign.justify;
        if (val == 'left' || val == 'start') align = DocxAlign.left;
      }

      // Spacing
      final spacingElem = pPr.getElement('w:spacing');
      if (spacingElem != null) {
        final after = spacingElem.getAttribute('w:after');
        if (after != null) spacingAfter = int.tryParse(after);

        final before = spacingElem.getAttribute('w:before');
        if (before != null) spacingBefore = int.tryParse(before);

        final line = spacingElem.getAttribute('w:line');
        if (line != null) lineSpacing = int.tryParse(line);
      }

      // Indentation
      final indElem = pPr.getElement('w:ind');
      if (indElem != null) {
        final left =
            indElem.getAttribute('w:left') ?? indElem.getAttribute('w:start');
        if (left != null) indentLeft = int.tryParse(left);

        final right =
            indElem.getAttribute('w:right') ?? indElem.getAttribute('w:end');
        if (right != null) indentRight = int.tryParse(right);

        final firstLine = indElem.getAttribute('w:firstLine');
        if (firstLine != null) indentFirstLine = int.tryParse(firstLine);
      }

      // Shading
      final shdElem = pPr.getElement('w:shd');
      if (shdElem != null) {
        shadingFill = shdElem.getAttribute('w:fill');
        if (shadingFill == 'auto') shadingFill = null;
      }

      // Numbering/Lists
      final numPr = pPr.getElement('w:numPr');
      if (numPr != null) {
        final numIdElem = numPr.getElement('w:numId');
        final ilvlElem = numPr.getElement('w:ilvl');

        if (numIdElem != null) {
          numId = int.tryParse(numIdElem.getAttribute('w:val') ?? '');
        }
        if (ilvlElem != null) {
          ilvl = int.tryParse(ilvlElem.getAttribute('w:val') ?? '');
        }
      }
    }

    // Parse runs and other inline content
    for (var child in xml.children) {
      if (child is XmlElement) {
        if (child.name.local == 'r') {
          children.add(_parseRun(child));
        } else if (child.name.local == 'hyperlink') {
          // Extract href from relationship
          final rId = child.getAttribute('r:id');
          String? href;
          if (rId != null && _documentRelationships.containsKey(rId)) {
            href = _documentRelationships[rId]!.target;
          }

          // Parse all runs within the hyperlink
          for (var grandChild in child.findAllElements('w:r')) {
            final run = _parseRun(grandChild);
            // Apply href to DocxText elements
            if (run is DocxText && href != null) {
              children.add(run.copyWith(
                href: href,
                decoration: DocxTextDecoration.underline,
                color: DocxColor.blue,
              ));
            } else {
              children.add(run);
            }
          }
        }
      }
    }

    return DocxParagraph(
      children: children,
      styleId: pStyle,
      align: align,
      shadingFill: shadingFill,
      numId: numId,
      ilvl: ilvl,
      spacingAfter: spacingAfter,
      spacingBefore: spacingBefore,
      lineSpacing: lineSpacing,
      indentLeft: indentLeft,
      indentRight: indentRight,
      indentFirstLine: indentFirstLine,
    );
  }

  DocxInline _parseRun(XmlElement run) {
    // Check for drawings (Images or Shapes)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      // Check for shape (wsp:wsp) first
      final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
      if (wsp != null) {
        return _readShape(drawing, wsp);
      }

      // Check for image (a:blip)
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
    String? shadingFill;
    double? fontSize;
    String? fontFamily;
    var highlight = DocxHighlight.none;
    bool isSuperscript = false;
    bool isSubscript = false;
    bool isAllCaps = false;
    bool isSmallCaps = false;
    bool isDoubleStrike = false;
    bool isOutline = false;
    bool isShadow = false;
    bool isEmboss = false;
    bool isImprint = false;

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

      final shdElem = rPr.getElement('w:shd');
      if (shdElem != null) {
        shadingFill = shdElem.getAttribute('w:fill');
        if (shadingFill == 'auto') shadingFill = null;
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

      // Highlight
      final highlightElem = rPr.getElement('w:highlight');
      if (highlightElem != null) {
        final val = highlightElem.getAttribute('w:val');
        if (val != null) {
          // Map string to enum
          for (var h in DocxHighlight.values) {
            if (h.name == val) {
              highlight = h;
              break;
            }
          }
        }
      }

      // Text Effects
      if (rPr.getElement('w:caps') != null) isAllCaps = true;
      if (rPr.getElement('w:smallCaps') != null) isSmallCaps = true;
      if (rPr.getElement('w:dstrike') != null) isDoubleStrike = true;
      if (rPr.getElement('w:outline') != null) isOutline = true;
      if (rPr.getElement('w:shadow') != null) isShadow = true;
      if (rPr.getElement('w:emboss') != null) isEmboss = true;
      if (rPr.getElement('w:imprint') != null) isImprint = true;

      // Vertical Align (Super/Sub)
      final vertAlignElem = rPr.getElement('w:vertAlign');
      if (vertAlignElem != null) {
        final val = vertAlignElem.getAttribute('w:val');
        if (val == 'superscript') isSuperscript = true;
        if (val == 'subscript') isSubscript = true;
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
        shadingFill: shadingFill,
        fontSize: fontSize,
        fontFamily: fontFamily,
        highlight: highlight,
        isSuperscript: isSuperscript,
        isSubscript: isSubscript,
        isAllCaps: isAllCaps,
        isSmallCaps: isSmallCaps,
        isDoubleStrike: isDoubleStrike,
        isOutline: isOutline,
        isShadow: isShadow,
        isEmboss: isEmboss,
        isImprint: isImprint,
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

  DocxShape _readShape(XmlElement drawingNode, XmlElement wsp) {
    // Determine position mode (inline vs floating)
    final isInline = drawingNode.findAllElements('wp:inline').isNotEmpty;
    final position =
        isInline ? DocxDrawingPosition.inline : DocxDrawingPosition.floating;

    // Read dimensions from extent
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

    // Read preset geometry
    var preset = DocxShapePreset.rect;
    final prstGeom = wsp.findAllElements('a:prstGeom').firstOrNull;
    if (prstGeom != null) {
      final prstName = prstGeom.getAttribute('prst');
      if (prstName != null) {
        for (var p in DocxShapePreset.values) {
          if (p.name == prstName) {
            preset = p;
            break;
          }
        }
      }
    }

    // Read fill color
    DocxColor? fillColor;
    final solidFill = wsp.findAllElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      final srgbClr = solidFill.findAllElements('a:srgbClr').firstOrNull;
      if (srgbClr != null) {
        final val = srgbClr.getAttribute('val');
        if (val != null) {
          fillColor = DocxColor(val);
        }
      }
    }

    // Read outline color and width
    DocxColor? outlineColor;
    double outlineWidth = 1;
    final ln = wsp.findAllElements('a:ln').firstOrNull;
    if (ln != null) {
      final wAttr = ln.getAttribute('w');
      if (wAttr != null) {
        final wEmu = int.tryParse(wAttr);
        if (wEmu != null) {
          outlineWidth = wEmu / 12700.0;
        }
      }
      final lnFill = ln.findAllElements('a:solidFill').firstOrNull;
      if (lnFill != null) {
        final srgbClr = lnFill.findAllElements('a:srgbClr').firstOrNull;
        if (srgbClr != null) {
          final val = srgbClr.getAttribute('val');
          if (val != null) {
            outlineColor = DocxColor(val);
          }
        }
      }
    }

    // Read text content
    String? text;
    final txbx = wsp.findAllElements('wsp:txbx').firstOrNull;
    if (txbx != null) {
      final textContent =
          txbx.findAllElements('w:t').map((t) => t.innerText).join();
      if (textContent.isNotEmpty) {
        text = textContent;
      }
    }

    // Read rotation
    double rotation = 0;
    final xfrm = wsp.findAllElements('a:xfrm').firstOrNull;
    if (xfrm != null) {
      final rot = xfrm.getAttribute('rot');
      if (rot != null) {
        final rotVal = int.tryParse(rot);
        if (rotVal != null) {
          rotation = rotVal / 60000.0;
        }
      }
    }

    // Read floating-specific properties
    var horizontalFrom = DocxHorizontalPositionFrom.column;
    var verticalFrom = DocxVerticalPositionFrom.paragraph;
    DrawingHAlign? horizontalAlign;
    DrawingVAlign? verticalAlign;
    double? horizontalOffset;
    double? verticalOffset;
    var textWrap = DocxTextWrap.square;
    bool behindDocument = false;

    if (position == DocxDrawingPosition.floating) {
      final anchor = drawingNode.findAllElements('wp:anchor').firstOrNull;
      if (anchor != null) {
        final behindAttr = anchor.getAttribute('behindDoc');
        behindDocument = behindAttr == '1';

        // Horizontal position
        final posH = anchor.findAllElements('wp:positionH').firstOrNull;
        if (posH != null) {
          final relFrom = posH.getAttribute('relativeFrom');
          if (relFrom != null) {
            for (var h in DocxHorizontalPositionFrom.values) {
              if (h.name == relFrom) {
                horizontalFrom = h;
                break;
              }
            }
          }
          final alignElem = posH.findAllElements('wp:align').firstOrNull;
          if (alignElem != null) {
            for (var a in DrawingHAlign.values) {
              if (a.name == alignElem.innerText) {
                horizontalAlign = a;
                break;
              }
            }
          }
          final offsetElem = posH.findAllElements('wp:posOffset').firstOrNull;
          if (offsetElem != null) {
            final off = int.tryParse(offsetElem.innerText);
            if (off != null) {
              horizontalOffset = off / 12700.0;
            }
          }
        }

        // Vertical position
        final posV = anchor.findAllElements('wp:positionV').firstOrNull;
        if (posV != null) {
          final relFrom = posV.getAttribute('relativeFrom');
          if (relFrom != null) {
            for (var v in DocxVerticalPositionFrom.values) {
              if (v.name == relFrom) {
                verticalFrom = v;
                break;
              }
            }
          }
          final alignElem = posV.findAllElements('wp:align').firstOrNull;
          if (alignElem != null) {
            for (var a in DrawingVAlign.values) {
              if (a.name == alignElem.innerText) {
                verticalAlign = a;
                break;
              }
            }
          }
          final offsetElem = posV.findAllElements('wp:posOffset').firstOrNull;
          if (offsetElem != null) {
            final off = int.tryParse(offsetElem.innerText);
            if (off != null) {
              verticalOffset = off / 12700.0;
            }
          }
        }

        // Text wrapping
        if (anchor.findAllElements('wp:wrapNone').isNotEmpty) {
          textWrap = DocxTextWrap.none;
        } else if (anchor.findAllElements('wp:wrapSquare').isNotEmpty) {
          textWrap = DocxTextWrap.square;
        } else if (anchor.findAllElements('wp:wrapTight').isNotEmpty) {
          textWrap = DocxTextWrap.tight;
        } else if (anchor.findAllElements('wp:wrapThrough').isNotEmpty) {
          textWrap = DocxTextWrap.through;
        } else if (anchor.findAllElements('wp:wrapTopAndBottom').isNotEmpty) {
          textWrap = DocxTextWrap.topAndBottom;
        }
      }
    }

    return DocxShape(
      width: width,
      height: height,
      preset: preset,
      position: position,
      fillColor: fillColor,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      text: text,
      horizontalFrom: horizontalFrom,
      verticalFrom: verticalFrom,
      horizontalAlign: horizontalAlign,
      verticalAlign: verticalAlign,
      horizontalOffset: horizontalOffset,
      verticalOffset: verticalOffset,
      textWrap: textWrap,
      behindDocument: behindDocument,
      rotation: rotation,
    );
  }

  List<DocxBlock> _parseBlocks(Iterable<XmlNode> children) {
    final nodes = <DocxBlock>[];
    final pendingListItems = <DocxParagraph>[];
    int? currentNumId;

    void flushPendingList() {
      if (pendingListItems.isNotEmpty && currentNumId != null) {
        nodes.add(_createListFromParagraphs(pendingListItems, currentNumId!)
            as DocxBlock);
        pendingListItems.clear();
        currentNumId = null;
      }
    }

    for (var child in children) {
      if (child is XmlElement) {
        if (child.name.local == 'p') {
          final para = _parseParagraph(child);
          if (para.numId != null) {
            if (currentNumId == null || currentNumId == para.numId) {
              pendingListItems.add(para);
              currentNumId = para.numId;
            } else {
              flushPendingList();
              pendingListItems.add(para);
              currentNumId = para.numId;
            }
          } else {
            flushPendingList();
            nodes.add(para);
          }
        } else if (child.name.local == 'tbl') {
          flushPendingList();
          nodes.add(_parseTable(child));
        } else if (child.name.local == 'sectPr') {
          continue;
        }
      }
    }
    flushPendingList();
    return nodes;
  }

  DocxTable _parseTable(XmlElement xml) {
    final rows = <DocxTableRow>[];
    for (var row in xml.findElements('w:tr')) {
      final cells = <DocxTableCell>[];
      for (var cell in row.findElements('w:tc')) {
        String? shadingFill;
        final tcPr = cell.getElement('w:tcPr');
        if (tcPr != null) {
          final shd = tcPr.getElement('w:shd');
          if (shd != null) {
            shadingFill = shd.getAttribute('w:fill');
            if (shadingFill == 'auto') shadingFill = null;
          }
        }

        final cellContent = _parseBlocks(cell.children);
        cells.add(
            DocxTableCell(children: cellContent, shadingFill: shadingFill));
      }
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows);
  }

  DocxList _createListFromParagraphs(
      List<DocxParagraph> paragraphs, int numId) {
    final items = paragraphs.map((para) {
      return DocxListItem(para.children, level: para.ilvl ?? 0);
    }).toList();

    // Determine if ordered/unordered by checking numbering.xml
    final isOrdered = _isOrderedList(numId);

    return DocxList(
      items: items,
      isOrdered: isOrdered,
    )..numId = numId;
  }

  bool _isOrderedList(int numId) {
    // Parse numbering.xml to determine list type
    final numberingXml = _readXmlContent('word/numbering.xml');
    if (numberingXml == null) {
      // Fallback: assume bullet lists are common
      return false;
    }

    try {
      final doc = XmlDocument.parse(numberingXml);

      // Find the w:num element with matching numId
      for (var numElem in doc.findAllElements('w:num')) {
        final numIdAttr = numElem.getAttribute('w:numId');
        if (numIdAttr != null && int.tryParse(numIdAttr) == numId) {
          // Get the abstractNumId reference
          final abstractNumIdElem = numElem.getElement('w:abstractNumId');
          if (abstractNumIdElem != null) {
            final abstractNumIdVal = abstractNumIdElem.getAttribute('w:val');
            if (abstractNumIdVal != null) {
              final abstractNumId = int.tryParse(abstractNumIdVal);
              if (abstractNumId != null) {
                // Find the abstractNum with this ID and check the numFmt
                for (var abstractNum in doc.findAllElements('w:abstractNum')) {
                  final absIdAttr = abstractNum.getAttribute('w:abstractNumId');
                  if (absIdAttr != null &&
                      int.tryParse(absIdAttr) == abstractNumId) {
                    // Check the first level's numFmt
                    final lvl0 = abstractNum.findElements('w:lvl').firstOrNull;
                    if (lvl0 != null) {
                      final numFmtElem = lvl0.getElement('w:numFmt');
                      if (numFmtElem != null) {
                        final numFmt = numFmtElem.getAttribute('w:val');
                        // 'bullet' means unordered, anything else is ordered
                        return numFmt != 'bullet';
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // If parsing fails, fall back to heuristic
    }

    // Fallback: assume unordered (bullet)
    return false;
  }

  DocxSectionDef _parseSectionProperties(XmlElement body,
      {DocxColor? backgroundColor}) {
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
    DocxBackgroundImage? backgroundImage;

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
        final type = headerRef.getAttribute('w:type') ?? 'default';
        if (rId != null && _documentRelationships.containsKey(rId)) {
          if (rId == 'rIdBgHdr' || _isBackgroundHeader(rId)) {
            backgroundImage = _readBackgroundImage(rId);
          } else if (type == 'default' || header == null) {
            header = _readHeader(_documentRelationships[rId]!);
          }
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
      backgroundColor: backgroundColor,
      backgroundImage: backgroundImage,
    );
  }

  bool _isBackgroundHeader(String rId) {
    // Relationship target usually points to header_bg.xml or contains 'header_bg'
    final rel = _documentRelationships[rId];
    return rel?.target.contains('header_bg') ?? false;
  }

  DocxBackgroundImage? _readBackgroundImage(String rId) {
    final rel = _documentRelationships[rId]!;
    final xml = _readXmlFile(rel.target);
    if (xml == null) return null;

    // Look for drawing -> blip
    final blip = xml.findAllElements('a:blip').firstOrNull;
    if (blip == null) return null;

    final embedId = blip.getAttribute('r:embed');
    if (embedId == null) return null;

    // We need the relationship relative to the header file
    final headerPath = rel.target; // e.g. "header_bg.xml"
    final relsFile = archive.findFile('word/_rels/$headerPath.rels');
    if (relsFile == null) return null;

    final relsXml =
        XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
    for (var r in relsXml.findAllElements('Relationship')) {
      if (r.getAttribute('Id') == embedId) {
        final target = r.getAttribute('Target')!;
        final imgPath = 'word/$target';
        final imgFile = archive.findFile(imgPath);
        if (imgFile != null) {
          return DocxBackgroundImage(
            bytes: Uint8List.fromList(imgFile.content as List<int>),
            extension: target.split('.').last,
          );
        }
      }
    }
    return null;
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
