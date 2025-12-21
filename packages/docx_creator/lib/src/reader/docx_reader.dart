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
  final Map<String, _DocxStyle> _styles = {}; // StyleId -> Style

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

    // Read Styles (Before parsing body so we can resolve them)
    // Note: We also store the raw XML string at the end for the wrapper object
    final stylesXml = _readXmlContent('word/styles.xml');
    if (stylesXml != null) _readStyles(stylesXml);

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

  void _readStyles(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);
      for (var styleElem in xml.findAllElements('w:style')) {
        final styleId = styleElem.getAttribute('w:styleId');
        final type = styleElem.getAttribute('w:type'); // paragraph, character
        if (styleId != null) {
          final basedOn =
              styleElem.getElement('w:basedOn')?.getAttribute('w:val');
          final pPr = styleElem.getElement('w:pPr');
          final rPr = styleElem.getElement('w:rPr');

          _styles[styleId] = _DocxStyle.fromXml(
            styleId,
            type: type,
            basedOn: basedOn,
            pPr: pPr,
            rPr: rPr,
          );
        }
      }
    } catch (e) {
      // Ignore style parsing errors
    }
  }

  _DocxStyle _resolveStyle(String? styleId) {
    if (styleId == null || !_styles.containsKey(styleId)) {
      // Default to 'Normal' if style not found or null
      if (styleId != 'Normal' && _styles.containsKey('Normal')) {
        return _styles['Normal']!;
      }
      return _DocxStyle(id: styleId ?? 'manual');
    }

    final style = _styles[styleId]!;
    if (style.basedOn != null) {
      final parentStyle = _resolveStyle(style.basedOn);
      return parentStyle.merge(style);
    }
    return style;
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

    // Border variables
    DocxBorderSide? borderTop;
    DocxBorderSide? borderBottomSide;
    DocxBorderSide? borderLeft;
    DocxBorderSide? borderRight;
    DocxBorderSide? borderBetween;
    DocxBorder? borderBottom; // Legacy fallback

    // Parse paragraph properties
    final pPr = xml.getElement('w:pPr');
    if (pPr != null) {
      // Style
      final pStyleElem = pPr.getElement('w:pStyle');
      if (pStyleElem != null) {
        pStyle = pStyleElem.getAttribute('w:val');
      }
    }

    // Resolve Style Properties
    final effectiveStyle = _resolveStyle(pStyle ?? 'Normal');

    // Parse direct properties (override styles)
    final parsedProps = _DocxStyle.fromParagraphProperties(pPr);

    // Merge: Style < Direct
    final finalProps = effectiveStyle.merge(parsedProps);

    // Map to local variables
    align = finalProps.align ?? DocxAlign.left;
    shadingFill = finalProps.shadingFill;
    numId = finalProps.numId;
    ilvl = finalProps.ilvl;
    spacingAfter = finalProps.spacingAfter;
    spacingBefore = finalProps.spacingBefore;
    lineSpacing = finalProps.lineSpacing;
    indentLeft = finalProps.indentLeft;
    indentRight = finalProps.indentRight;
    indentFirstLine = finalProps.indentFirstLine;
    borderTop = finalProps.borderTop;
    borderBottomSide = finalProps.borderBottomSide;
    borderLeft = finalProps.borderLeft;
    borderRight = finalProps.borderRight;
    borderBetween = finalProps.borderBetween;
    borderBottom = finalProps.borderBottom;

    // Parse runs and other inline content
    final children =
        _parseInlineChildren(xml.children, parentStyle: effectiveStyle);

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
      borderTop: borderTop,
      borderBottomSide: borderBottomSide,
      borderLeft: borderLeft,
      borderRight: borderRight,
      borderBetween: borderBetween,
      borderBottom: borderBottom,
    );
  }

  DocxInline _parseRun(XmlElement run, {_DocxStyle? parentStyle}) {
    // Check for drawings (Images or Shapes)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      // 1. Try VML Shape
      final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
      if (wsp != null) {
        return _readShape(drawing, wsp);
      }

      // 2. Try Image (a:blip)
      final blip = drawing.findAllElements('a:blip').firstOrNull ??
          drawing.findAllElements('v:imagedata').firstOrNull;
      if (blip != null) {
        final embedId =
            blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
        if (embedId != null && _documentRelationships.containsKey(embedId)) {
          return _readImage(embedId, drawing);
        }
      }

      // 3. DrawingML Shape (fallback)
      final prstGeom = drawing.findAllElements('a:prstGeom').firstOrNull;
      if (prstGeom != null) {
        return DocxShape(
            width: 100,
            height: 100,
            preset: DocxShapePreset.rect,
            text: 'Shape');
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

    // Resolve run style
    final rPr = run.getElement('w:rPr');
    String? rStyle;
    if (rPr != null) {
      final rStyleElem = rPr.getElement('w:rStyle');
      if (rStyleElem != null) {
        rStyle = rStyleElem.getAttribute('w:val');
      }
    }

    // Paragraph Style (affects runs if style type is paragraph)
    // NOTE: Paragraph styles can define run properties.
    // However, _DocxReaderInternal._parseParagraph already calls _resolveStyle
    // but the paragraph style isn't passed down to _parseRun easily here unless we pass it.
    // Ideally _parseRun is aware of the parent paragraph style, but for now let's just use run styles.
    // Explicit style application:

    // 1. Base style = Parent Paragraph Style (if any) or Default
    var baseStyle = parentStyle ?? _resolveStyle('DefaultParagraphFont');

    // 2. Run Style (Character Style) - Overrides paragraph style properties
    if (rStyle != null) {
      final cStyle = _resolveStyle(rStyle);
      baseStyle = baseStyle.merge(cStyle);
    }

    // 3. Direct Properties - Overrides everything
    final parsedProps = _DocxStyle.fromRunProperties(rPr);
    final finalProps = baseStyle.merge(parsedProps);

    fontWeight = finalProps.fontWeight ?? DocxFontWeight.normal;
    fontStyle = finalProps.fontStyle ?? DocxFontStyle.normal;
    decoration = finalProps.decoration ?? DocxTextDecoration.none;
    color = finalProps.color;
    shadingFill = finalProps.shadingFill;
    fontSize = finalProps.fontSize;
    fontFamily = finalProps.fontFamily;
    highlight = finalProps.highlight ?? DocxHighlight.none;
    isSuperscript = finalProps.isSuperscript ?? false;
    isSubscript = finalProps.isSubscript ?? false;
    isAllCaps = finalProps.isAllCaps ?? false;
    isSmallCaps = finalProps.isSmallCaps ?? false;
    isDoubleStrike = finalProps.isDoubleStrike ?? false;
    isOutline = finalProps.isOutline ?? false;
    isShadow = finalProps.isShadow ?? false;
    isEmboss = finalProps.isEmboss ?? false;
    isImprint = finalProps.isImprint ?? false;

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

    return DocxRawInline(run.toXmlString());
  }

  List<DocxInline> _parseInlineChildren(Iterable<XmlNode> nodes,
      {_DocxStyle? parentStyle}) {
    final children = <DocxInline>[];
    for (var child in nodes) {
      if (child is XmlElement) {
        if (child.name.local == 'r') {
          children.add(_parseRun(child, parentStyle: parentStyle));
        } else if (child.name.local == 'hyperlink') {
          // Extract href from relationship
          final rId = child.getAttribute('r:id');
          String? href;
          if (rId != null && _documentRelationships.containsKey(rId)) {
            href = _documentRelationships[rId]!.target;
          }

          // Parse all runs within the hyperlink
          for (var grandChild in child.findAllElements('w:r')) {
            final run = _parseRun(grandChild, parentStyle: parentStyle);
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
        } else if (['ins', 'del', 'smartTag', 'sdt']
            .contains(child.name.local)) {
          // Handle inline containers
          var contentNodes = child.children;
          if (child.name.local == 'sdt') {
            final content = child.findAllElements('w:sdtContent').firstOrNull;
            if (content != null) contentNodes = content.children;
          }
          children.addAll(
              _parseInlineChildren(contentNodes, parentStyle: parentStyle));
        }
      }
    }
    return children;
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
        } else if (['ins', 'del', 'smartTag', 'sdt']
            .contains(child.name.local)) {
          // Flatten block content from these containers
          flushPendingList();
          var contentNodes = child.children;
          if (child.name.local == 'sdt') {
            final content = child.findAllElements('w:sdtContent').firstOrNull;
            if (content != null) contentNodes = content.children;
          }
          nodes.addAll(_parseBlocks(contentNodes));
        }
      }
    }
    flushPendingList();
    return nodes;
  }

  DocxTable _parseTable(XmlElement node) {
    // 1. Parse Table Properties
    DocxTableStyle style = const DocxTableStyle();
    int? tableWidth;
    DocxWidthType widthType = DocxWidthType.auto;

    final tblPr = node.getElement('w:tblPr');
    if (tblPr != null) {
      // Table Borders
      final tblBorders = tblPr.getElement('w:tblBorders');
      if (tblBorders != null) {
        style = DocxTableStyle(
          borderTop: _parseBorderSide(tblBorders.getElement('w:top')),
          borderBottom: _parseBorderSide(tblBorders.getElement('w:bottom')),
          borderLeft: _parseBorderSide(tblBorders.getElement('w:left')),
          borderRight: _parseBorderSide(tblBorders.getElement('w:right')),
          borderInsideH: _parseBorderSide(tblBorders.getElement('w:insideH')),
          borderInsideV: _parseBorderSide(tblBorders.getElement('w:insideV')),
          // Preserve other defaults or map them?
          // DocxTableStyle defaults: border=single etc.
          // If we have explicit borders, we might want to set basic border to custom?
          // But DocxTableStyle uses specific fields now.
        );
      }

      // Table Width
      final tblW = tblPr.getElement('w:tblW');
      if (tblW != null) {
        final w = int.tryParse(tblW.getAttribute('w:w') ?? '');
        final type = tblW.getAttribute('w:type');
        if (w != null) tableWidth = w;
        if (type == 'dxa') widthType = DocxWidthType.dxa;
        if (type == 'pct') widthType = DocxWidthType.pct;
        if (type == 'auto') widthType = DocxWidthType.auto;
      }
    }

    // 2. Parse Rows and Cells into temporary structure
    final rawRows = <List<_TempCell>>[];

    for (var child in node.children) {
      if (child is XmlElement && child.name.local == 'tr') {
        final row = <_TempCell>[];
        for (var cellNode in child.children) {
          if (cellNode is XmlElement && cellNode.name.local == 'tc') {
            // Parse cell properties
            final tcPr = cellNode.getElement('w:tcPr');
            int gridSpan = 1;
            String? vMergeVal;
            String? shadingFill;
            int? cellWidth;
            DocxBorderSide? borderTop;
            DocxBorderSide? borderBottom;
            DocxBorderSide? borderLeft;
            DocxBorderSide? borderRight;

            if (tcPr != null) {
              final gs = tcPr.getElement('w:gridSpan');
              if (gs != null) {
                gridSpan = int.tryParse(gs.getAttribute('w:val') ?? '1') ?? 1;
              }

              final vm = tcPr.getElement('w:vMerge');
              if (vm != null) {
                vMergeVal = vm.getAttribute('w:val') ?? 'continue';
              }

              final shd = tcPr.getElement('w:shd');
              if (shd != null) {
                shadingFill = shd.getAttribute('w:fill');
                if (shadingFill == 'auto') shadingFill = null;
              }

              final tcW = tcPr.getElement('w:tcW');
              if (tcW != null) {
                cellWidth = int.tryParse(tcW.getAttribute('w:w') ?? '');
              }

              final tcBorders = tcPr.getElement('w:tcBorders');
              if (tcBorders != null) {
                borderTop = _parseBorderSide(tcBorders.getElement('w:top'));
                borderBottom =
                    _parseBorderSide(tcBorders.getElement('w:bottom'));
                borderLeft = _parseBorderSide(tcBorders.getElement('w:left'));
                borderRight = _parseBorderSide(tcBorders.getElement('w:right'));
              }
            }

            final children = <DocxBlock>[];
            for (var c in cellNode.children) {
              if (c is XmlElement && c.name.local == 'p') {
                children.add(_parseParagraph(c));
              } else if (c is XmlElement && c.name.local == 'tbl') {
                children.add(_parseTable(c));
              }
            }

            row.add(_TempCell(
              children: children,
              gridSpan: gridSpan,
              vMerge: vMergeVal,
              shadingFill: shadingFill,
              width: cellWidth,
              borderTop: borderTop,
              borderBottom: borderBottom,
              borderLeft: borderLeft,
              borderRight: borderRight,
            ));
          }
        }
        if (row.isNotEmpty) rawRows.add(row);
      }
    }

    final grid = _resolveRowSpans(rawRows);
    final finalRows = <DocxTableRow>[];

    for (var r in grid) {
      final cells = r
          .map((c) => DocxTableCell(
                children: c.children,
                colSpan: c.gridSpan,
                rowSpan: c.finalRowSpan,
                shadingFill: c.shadingFill,
                width: c.width,
                borderTop: c.borderTop,
                borderBottom: c.borderBottom,
                borderLeft: c.borderLeft,
                borderRight: c.borderRight,
              ))
          .toList();
      finalRows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(
      rows: finalRows,
      style: style,
      width: tableWidth,
      widthType: widthType,
    );
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

class _TempCell {
  final List<DocxBlock> children;
  final int gridSpan;
  final String? vMerge;
  final String? shadingFill;

  int finalRowSpan = 1;
  bool isMerged =
      false; // If true, this cell is part of a merge but NOT the start (should be skipped or hidden?)
  // Actually, for DocxViewer/Table, we usually want the start cell to have rowSpan > 1,
  // and subsequent cells to NOT EXIST in the row?
  // CustomTableLayout expects them to exist?
  // No, CustomTableLayout expects "cells" list.
  // If use "Table", we need to emit correct number of cells (ghost cells).
  // But DocxTableCell definition implies we return the structure.
  // I will keep the cells but mark them?
  // If DocxViewer's TableBuilder ignores cells that are "covered", we should provide them?
  // My new CustomTableWidget handles occupied cells.
  // So I should return ALL cells, but correct rowSpan.
  // Wait, if rowSpan is 2, the cell in the next row at that col should exist?
  // In HTML tables, spanning cells cover slots. The slots in next row are implicit?
  // In CustomTableWidget logic: "Track which cells span...". It expects the *next* row to NOT have a cell definition for that slot?
  // Or it effectively skips them.
  // Whatever logic I implemented in CustomTableWidget, I should match.
  // CustomTableWidget: "for (final cell in cells) ... if (cell.rowSpan > 1) ... spanningCells".
  // ... "while (currentCol < columnCount) ... if (occupiedCols.contains) ... empty spacer".
  // So CustomTableWidget handles it.
  // So _DocxReader should produce cells with correct span.
  // For "continued" cells (vMerge=continue), should they have rowSpan=0? Or -1?
  // Or should they be REMOVED from the row?
  // If I remove them, CustomTableLayout needs to know they are missing.
  // CustomTableLayout iterates input cells.
  // So if I have row 1: Cell(span=2)
  // Row 2: (Empty because covered).
  // Then Row 2 in AST should have NO cell for that column?
  // Yes.
  // So my _resolveRowSpans should filtering out "continued" cells?
  // Let's implement that.

  _TempCell({
    required this.children,
    required this.gridSpan,
    this.vMerge,
    this.shadingFill,
    this.width,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
  });

  final int? width;
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
}

List<List<_TempCell>> _resolveRowSpans(List<List<_TempCell>> rawRows) {
  // Track active merge starts per column index
  // ColIndex -> _TempCell (the start of the merge)
  final activeMerges = <int, _TempCell>{};

  // We need to map visual columns.
  // Since gridSpan affects column index.

  for (int r = 0; r < rawRows.length; r++) {
    final row = rawRows[r];
    int colIndex = 0;

    for (int c = 0; c < row.length; c++) {
      final cell = row[c];

      // Calculate current range of columns
      final startCol = colIndex;
      // final endCol = colIndex + cell.gridSpan;

      if (cell.vMerge == 'restart') {
        // Start a new merge
        // Close previous if any (shouldn't happen for restart unless nested, but key is colIndex)
        // For gridSpan > 1, we track the FIRST col index.
        activeMerges[startCol] = cell;
        cell.finalRowSpan = 1;
      } else if (cell.vMerge == 'continue' ||
          (cell.vMerge != null && cell.vMerge!.isEmpty)) {
        // Continue merge
        final startCell = activeMerges[startCol];
        if (startCell != null) {
          startCell.finalRowSpan++;
          cell.isMerged = true; // Mark to remove
        }
      } else {
        // No merge.
        activeMerges.remove(startCol);
      }

      colIndex += cell.gridSpan;
    }
  }

  // Filter out merged cells (continue)
  // We recreate the rows without the 'continue' cells
  final result = <List<_TempCell>>[];
  for (final row in rawRows) {
    result.add(row.where((c) => !c.isMerged).toList());
  }
  return result;
}

DocxBorderSide? _parseBorderSide(XmlElement? borderElem) {
  if (borderElem == null) return null;
  final val = borderElem.getAttribute('w:val');
  if (val == null || val == 'none' || val == 'nil') {
    return const DocxBorderSide.none();
  }

  var style = DocxBorder.single;
  for (var s in DocxBorder.values) {
    if (s.xmlValue == val) {
      style = s;
      break;
    }
  }

  // Size is in 1/8 pt
  int size = 4;
  final szAttr = borderElem.getAttribute('w:sz');
  if (szAttr != null) {
    size = int.tryParse(szAttr) ?? 4;
  }

  // Space
  int space = 0;
  final spAttr = borderElem.getAttribute('w:space');
  if (spAttr != null) {
    space = int.tryParse(spAttr) ?? 0;
  }

  // Color
  var color = DocxColor.auto;
  final colorAttr = borderElem.getAttribute('w:color');
  if (colorAttr != null && colorAttr != 'auto') {
    color = DocxColor(colorAttr);
  }

  return DocxBorderSide(
    style: style,
    size: size,
    space: space,
    color: color,
  );
}

class _DocxStyle {
  final String id;
  final String? type;
  final String? basedOn;

  // Paragraph Properties
  final DocxAlign? align;
  final String? shadingFill; // shared with run
  final int? numId;
  final int? ilvl;
  final int? spacingAfter;
  final int? spacingBefore;
  final int? lineSpacing;
  final int? indentLeft;
  final int? indentRight;
  final int? indentFirstLine;
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottomSide;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
  final DocxBorderSide? borderBetween;
  final DocxBorder? borderBottom;

  // Run Properties
  final DocxFontWeight? fontWeight;
  final DocxFontStyle? fontStyle;
  final DocxTextDecoration? decoration;
  final DocxColor? color;
  final double? fontSize;
  final String? fontFamily;
  final DocxHighlight? highlight;
  final bool? isSuperscript;
  final bool? isSubscript;
  final bool? isAllCaps;
  final bool? isSmallCaps;
  final bool? isDoubleStrike;
  final bool? isOutline;
  final bool? isShadow;
  final bool? isEmboss;
  final bool? isImprint;

  // Raw Elements (for lazy parsing if needed, but we parse eagerly now)
  // ignore: unused_field
  final XmlElement? _pPr;
  // ignore: unused_field
  final XmlElement? _rPr;

  const _DocxStyle({
    required this.id,
    this.type,
    this.basedOn,
    this.align,
    this.shadingFill,
    this.numId,
    this.ilvl,
    this.spacingAfter,
    this.spacingBefore,
    this.lineSpacing,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.borderTop,
    this.borderBottomSide,
    this.borderLeft,
    this.borderRight,
    this.borderBetween,
    this.borderBottom,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.color,
    this.fontSize,
    this.fontFamily,
    this.highlight,
    this.isSuperscript,
    this.isSubscript,
    this.isAllCaps,
    this.isSmallCaps,
    this.isDoubleStrike,
    this.isOutline,
    this.isShadow,
    this.isEmboss,
    this.isImprint,
    XmlElement? pPr,
    XmlElement? rPr,
  })  : _pPr = pPr,
        _rPr = rPr;

  // Create from raw elements by parsing them immediately
  factory _DocxStyle.fromXml(String id,
      {String? type, String? basedOn, XmlElement? pPr, XmlElement? rPr}) {
    final pProps = fromParagraphProperties(pPr);
    final rProps = fromRunProperties(rPr);

    final style = _DocxStyle(
      id: id,
      type: type,
      basedOn: basedOn,
      // P props
      align: pProps.align,
      shadingFill: pProps.shadingFill ?? rProps.shadingFill,
      numId: pProps.numId,
      ilvl: pProps.ilvl,
      spacingAfter: pProps.spacingAfter,
      spacingBefore: pProps.spacingBefore,
      lineSpacing: pProps.lineSpacing,
      indentLeft: pProps.indentLeft,
      indentRight: pProps.indentRight,
      indentFirstLine: pProps.indentFirstLine,
      borderTop: pProps.borderTop,
      borderBottomSide: pProps.borderBottomSide,
      borderLeft: pProps.borderLeft,
      borderRight: pProps.borderRight,
      borderBetween: pProps.borderBetween,
      borderBottom: pProps.borderBottom,
      // R Props
      fontWeight: rProps.fontWeight,
      fontStyle: rProps.fontStyle,
      decoration: rProps.decoration,
      color: rProps.color,
      fontSize: rProps.fontSize,
      fontFamily: rProps.fontFamily,
      highlight: rProps.highlight,
      isSuperscript: rProps.isSuperscript,
      isSubscript: rProps.isSubscript,
      isAllCaps: rProps.isAllCaps,
      isSmallCaps: rProps.isSmallCaps,
      isDoubleStrike: rProps.isDoubleStrike,
      isOutline: rProps.isOutline,
      isShadow: rProps.isShadow,
      isEmboss: rProps.isEmboss,
      isImprint: rProps.isImprint,
    );

    return style;
  }

  // Parses just paragraph properties block
  static _DocxStyle fromParagraphProperties(XmlElement? pPr) {
    if (pPr == null) return const _DocxStyle(id: 'temp');

    DocxAlign? align;
    String? shadingFill;
    int? numId;
    int? ilvl;
    int? spacingAfter;
    int? spacingBefore;
    int? lineSpacing;
    int? indentLeft;
    int? indentRight;
    int? indentFirstLine;
    DocxBorderSide? borderTop;
    DocxBorderSide? borderBottomSide;
    DocxBorderSide? borderLeft;
    DocxBorderSide? borderRight;
    DocxBorderSide? borderBetween;
    DocxBorder? borderBottom; // Legacy fallback

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

    // Borders
    final pBdr = pPr.getElement('w:pBdr');
    if (pBdr != null) {
      // Helper to parse border side
      DocxBorderSide? parseSide(XmlElement? el) {
        if (el == null) return null;
        final val = el.getAttribute('w:val');
        if (val == null || val == 'none' || val == 'nil') return null;

        // Size
        int size = 4;
        final szAttr = el.getAttribute('w:sz');
        if (szAttr != null) {
          final s = int.tryParse(szAttr);
          if (s != null) size = s;
        }

        // Color
        var color = DocxColor.black;
        final colorAttr = el.getAttribute('w:color');
        if (colorAttr != null && colorAttr != 'auto') {
          color = DocxColor(colorAttr);
        }

        // Style
        var style = DocxBorder.single;
        for (var b in DocxBorder.values) {
          if (b.xmlValue == val) {
            style = b;
            break;
          }
        }

        return DocxBorderSide(style: style, size: size, color: color);
      }

      borderTop = parseSide(pBdr.getElement('w:top'));
      borderBottomSide = parseSide(pBdr.getElement('w:bottom'));
      borderLeft = parseSide(pBdr.getElement('w:left'));
      borderRight = parseSide(pBdr.getElement('w:right'));
      borderBetween = parseSide(pBdr.getElement('w:between'));
    }

    return _DocxStyle(
      id: 'temp',
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
      borderTop: borderTop,
      borderBottomSide: borderBottomSide,
      borderLeft: borderLeft,
      borderRight: borderRight,
      borderBetween: borderBetween,
      borderBottom: borderBottom,
    );
  }

  // Parses just run properties block
  static _DocxStyle fromRunProperties(XmlElement? rPr) {
    if (rPr == null) return const _DocxStyle(id: 'temp');

    DocxFontWeight? fontWeight;
    DocxFontStyle? fontStyle;
    DocxTextDecoration? decoration;
    DocxColor? color;
    String? shadingFill;
    double? fontSize;
    String? fontFamily;
    DocxHighlight? highlight;
    bool? isSuperscript;
    bool? isSubscript;
    bool? isAllCaps;
    bool? isSmallCaps;
    bool? isDoubleStrike;
    bool? isOutline;
    bool? isShadow;
    bool? isEmboss;
    bool? isImprint;

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
      if (val != null && val != 'auto') color = DocxColor('#$val');
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
        if (halfPoints != null) fontSize = halfPoints / 2.0;
      }
    }

    final rFonts = rPr.getElement('w:rFonts');
    if (rFonts != null) fontFamily = rFonts.getAttribute('w:ascii');

    final highlightElem = rPr.getElement('w:highlight');
    if (highlightElem != null) {
      final val = highlightElem.getAttribute('w:val');
      if (val != null) {
        for (var h in DocxHighlight.values) {
          if (h.name == val) {
            highlight = h;
            break;
          }
        }
      }
    }

    if (rPr.getElement('w:caps') != null) isAllCaps = true;
    if (rPr.getElement('w:smallCaps') != null) isSmallCaps = true;
    if (rPr.getElement('w:dstrike') != null) isDoubleStrike = true;
    if (rPr.getElement('w:outline') != null) isOutline = true;
    if (rPr.getElement('w:shadow') != null) isShadow = true;
    if (rPr.getElement('w:emboss') != null) isEmboss = true;
    if (rPr.getElement('w:imprint') != null) isImprint = true;

    final vertAlignElem = rPr.getElement('w:vertAlign');
    if (vertAlignElem != null) {
      final val = vertAlignElem.getAttribute('w:val');
      if (val == 'superscript') isSuperscript = true;
      if (val == 'subscript') isSubscript = true;
    }

    return _DocxStyle(
      id: 'temp',
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

  // Merge this style (as base/effective) with override properties
  _DocxStyle merge(_DocxStyle other) {
    return _DocxStyle(
      id: other.id == 'temp' ? id : other.id,
      type: type,
      basedOn: basedOn,
      // P props
      align: other.align ?? align,
      shadingFill: other.shadingFill ?? shadingFill,
      numId: other.numId ?? numId,
      ilvl: other.ilvl ?? ilvl,
      spacingAfter: other.spacingAfter ?? spacingAfter,
      spacingBefore: other.spacingBefore ?? spacingBefore,
      lineSpacing: other.lineSpacing ?? lineSpacing,
      indentLeft: other.indentLeft ?? indentLeft,
      indentRight: other.indentRight ?? indentRight,
      indentFirstLine: other.indentFirstLine ?? indentFirstLine,
      borderTop: other.borderTop ?? borderTop,
      borderBottomSide: other.borderBottomSide ?? borderBottomSide,
      borderLeft: other.borderLeft ?? borderLeft,
      borderRight: other.borderRight ?? borderRight,
      borderBetween: other.borderBetween ?? borderBetween,
      borderBottom: other.borderBottom ?? borderBottom,
      // R props
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      decoration: other.decoration ?? decoration,
      color: other.color ?? color,
      fontSize: other.fontSize ?? fontSize,
      fontFamily: other.fontFamily ?? fontFamily,
      highlight: other.highlight ?? highlight,
      isSuperscript: other.isSuperscript ?? isSuperscript,
      isSubscript: other.isSubscript ?? isSubscript,
      isAllCaps: other.isAllCaps ?? isAllCaps,
      isSmallCaps: other.isSmallCaps ?? isSmallCaps,
      isDoubleStrike: other.isDoubleStrike ?? isDoubleStrike,
      isOutline: other.isOutline ?? isOutline,
      isShadow: other.isShadow ?? isShadow,
      isEmboss: other.isEmboss ?? isEmboss,
      isImprint: other.isImprint ?? isImprint,
    );
  }
}
