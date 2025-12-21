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
        tableParser = TableParser(context);

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
}
