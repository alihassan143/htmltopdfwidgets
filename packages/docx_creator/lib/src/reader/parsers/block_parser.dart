import 'package:xml/xml.dart';

import '../../../docx_creator.dart';
import '../models/docx_style.dart';
import '../reader_context.dart';
import 'inline_parser.dart';
import 'table_parser.dart';

/// Parses block-level content (paragraphs, lists, tables).
class BlockParser {
  final ReaderContext context;
  final InlineParser inlineParser;
  final TableParser tableParser;

  BlockParser(this.context)
      : inlineParser = InlineParser(context),
        tableParser = TableParser(context, InlineParser(context));

  /// Parse body element into list of DocxNodes.
  List<DocxNode> parseBody(XmlElement body) {
    return parseBlocks(body.children);
  }

  /// Parse a list of XML children into DocxNodes.
  List<DocxNode> parseBlocks(Iterable<XmlNode> children) {
    final result = <DocxNode>[];
    final pendingListItems = <DocxParagraph>[];
    int? currentNumId;

    void flushPendingList() {
      if (pendingListItems.isNotEmpty && currentNumId != null) {
        result.add(_createListFromParagraphs(pendingListItems, currentNumId!));
        pendingListItems.clear();
        currentNumId = null;
      }
    }

    for (var child in children) {
      if (child is XmlElement) {
        if (child.name.local == 'p') {
          // Check for drop cap first
          final pPr = child.getElement('w:pPr');
          final framePr = pPr?.getElement('w:framePr');
          final dropCapAttr = framePr?.getAttribute('w:dropCap');

          if (dropCapAttr != null &&
              (dropCapAttr == 'drop' || dropCapAttr == 'margin')) {
            // This is a drop cap paragraph
            final dropCap = _parseDropCap(child, framePr!, dropCapAttr);
            flushPendingList();
            result.add(dropCap);
          } else {
            final para = parseParagraph(child);
            if (para.numId != null) {
              // List item
              if (currentNumId != null && currentNumId != para.numId) {
                flushPendingList();
              }
              currentNumId = para.numId;
              pendingListItems.add(para);
            } else {
              flushPendingList();
              result.add(para);
            }
          }

          // Check for section break embedded in this paragraph (reuse pPr from above)
          if (pPr != null) {
            final sectPr = pPr.getElement('w:sectPr');
            if (sectPr != null) {
              final sectionDef = _parseSectionProperties(sectPr);
              result.add(DocxSectionBreakBlock(sectionDef));
            }
          }
        } else if (child.name.local == 'tbl') {
          flushPendingList();
          result.add(tableParser.parse(child));
        } else if (['ins', 'del', 'smartTag', 'sdt']
            .contains(child.name.local)) {
          // Handle block-level containers (Track Changes, etc.)
          var contentNodes = child.children;
          if (child.name.local == 'sdt') {
            final content = child.findAllElements('w:sdtContent').firstOrNull;
            if (content != null) contentNodes = content.children;
          }
          result.addAll(parseBlocks(contentNodes));
        }
      }
    }

    flushPendingList();
    return result;
  }

  /// Parse a paragraph element.
  DocxParagraph parseParagraph(XmlElement xml) {
    String? pStyle;

    // Parse paragraph properties
    final pPr = xml.getElement('w:pPr');
    if (pPr != null) {
      final pStyleElem = pPr.getElement('w:pStyle');
      if (pStyleElem != null) {
        pStyle = pStyleElem.getAttribute('w:val');
      }
    }

    // Resolve Style Properties
    final effectiveStyle = context.resolveStyle(pStyle ?? 'Normal');

    // Parse direct properties (override styles)
    final parsedProps = DocxStyle.fromXml('temp', pPr: pPr);

    // Merge: Style < Direct
    final finalProps = effectiveStyle.merge(parsedProps);

    // Parse runs and other inline content
    final children =
        inlineParser.parseChildren(xml.children, parentStyle: effectiveStyle);

    return DocxParagraph(
      children: children,
      styleId: pStyle,
      align: finalProps.align ?? DocxAlign.left,
      shadingFill: finalProps.shadingFill,
      numId: finalProps.numId,
      ilvl: finalProps.ilvl,
      spacingAfter: finalProps.spacingAfter,
      spacingBefore: finalProps.spacingBefore,
      lineSpacing: finalProps.lineSpacing,
      indentLeft: finalProps.indentLeft,
      indentRight: finalProps.indentRight,
      indentFirstLine: finalProps.indentFirstLine,
      borderTop: finalProps.borderTop,
      borderBottomSide: finalProps.borderBottomSide,
      borderLeft: finalProps.borderLeft,
      borderRight: finalProps.borderRight,
      borderBetween: finalProps.borderBetween,
      borderBottom: finalProps.borderBottom,
    );
  }

  /// Create a DocxList from collected list paragraphs.
  DocxList _createListFromParagraphs(
      List<DocxParagraph> paragraphs, int numId) {
    final items = paragraphs
        .map((p) => DocxListItem(
              p.children,
              level: p.ilvl ?? 0,
            ))
        .toList();

    return DocxList(
      items: items,
      isOrdered: _isOrderedList(numId),
    );
  }

  /// Determine if a list is ordered based on numbering definitions.
  bool _isOrderedList(int numId) {
    final numberingXml = context.numberingXml;
    if (numberingXml == null) return false;

    try {
      final xml = XmlDocument.parse(numberingXml);

      // Find abstract numId for this numId
      int? abstractNumId;
      for (var num in xml.findAllElements('w:num')) {
        final id = int.tryParse(num.getAttribute('w:numId') ?? '');
        if (id == numId) {
          final abstractRef = num.getElement('w:abstractNumId');
          if (abstractRef != null) {
            abstractNumId =
                int.tryParse(abstractRef.getAttribute('w:val') ?? '');
          }
          break;
        }
      }

      if (abstractNumId == null) return false;

      // Check numbering format
      for (var abstractNum in xml.findAllElements('w:abstractNum')) {
        final id =
            int.tryParse(abstractNum.getAttribute('w:abstractNumId') ?? '');
        if (id == abstractNumId) {
          final lvl = abstractNum.findAllElements('w:lvl').firstOrNull;
          if (lvl != null) {
            final numFmt = lvl.getElement('w:numFmt');
            if (numFmt != null) {
              final val = numFmt.getAttribute('w:val');
              return val != 'bullet';
            }
          }
          break;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Parse section properties from a w:sectPr element.
  DocxSectionDef _parseSectionProperties(XmlElement sectPr) {
    DocxPageSize pageSize = DocxPageSize.letter;
    DocxPageOrientation orientation = DocxPageOrientation.portrait;
    int? customWidth;
    int? customHeight;
    int marginTop = kDefaultMarginTop;
    int marginBottom = kDefaultMarginBottom;
    int marginLeft = kDefaultMarginLeft;
    int marginRight = kDefaultMarginRight;

    // Page Size
    final pgSz = sectPr.getElement('w:pgSz');
    if (pgSz != null) {
      final w = int.tryParse(pgSz.getAttribute('w:w') ?? '12240') ?? 12240;
      final h = int.tryParse(pgSz.getAttribute('w:h') ?? '15840') ?? 15840;
      final orient = pgSz.getAttribute('w:orient');

      if (orient == 'landscape') {
        orientation = DocxPageOrientation.landscape;
      }

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
      marginTop = int.tryParse(pgMar.getAttribute('w:top') ?? '') ?? marginTop;
      marginBottom =
          int.tryParse(pgMar.getAttribute('w:bottom') ?? '') ?? marginBottom;
      marginLeft =
          int.tryParse(pgMar.getAttribute('w:left') ?? '') ?? marginLeft;
      marginRight =
          int.tryParse(pgMar.getAttribute('w:right') ?? '') ?? marginRight;
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
    );
  }

  /// Parse a drop cap paragraph from w:framePr with w:dropCap.
  DocxDropCap _parseDropCap(
      XmlElement xml, XmlElement framePr, String dropCapAttr) {
    // Get drop cap style
    final style = dropCapAttr == 'margin'
        ? DocxDropCapStyle.margin
        : DocxDropCapStyle.drop;

    // Get number of lines
    final linesAttr = framePr.getAttribute('w:lines');
    final lines = int.tryParse(linesAttr ?? '3') ?? 3;

    // Get horizontal space
    final hSpaceAttr = framePr.getAttribute('w:hSpace');
    final hSpace = int.tryParse(hSpaceAttr ?? '0') ?? 0;

    // Extract the drop cap letter from the first run
    String letter = '';
    String? fontFamily;
    double? fontSize;

    final runs = xml.findAllElements('w:r');
    if (runs.isNotEmpty) {
      final firstRun = runs.first;
      final textElem = firstRun.getElement('w:t');
      if (textElem != null) {
        letter = textElem.innerText;
      }

      // Get font properties
      final rPr = firstRun.getElement('w:rPr');
      if (rPr != null) {
        final szElem = rPr.getElement('w:sz');
        if (szElem != null) {
          final szVal = int.tryParse(szElem.getAttribute('w:val') ?? '');
          if (szVal != null) fontSize = szVal / 2.0;
        }
        final rFonts = rPr.getElement('w:rFonts');
        if (rFonts != null) {
          fontFamily = rFonts.getAttribute('w:ascii');
        }
      }
    }

    return DocxDropCap(
      letter: letter,
      lines: lines,
      style: style,
      hSpace: hSpace,
      fontFamily: fontFamily,
      fontSize: fontSize,
      restOfParagraph: const [], // Rest of paragraph is typically in following paragraph
    );
  }
}
