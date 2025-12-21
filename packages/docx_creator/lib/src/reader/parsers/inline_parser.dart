import 'package:xml/xml.dart';

import '../../../docx_creator.dart';
import '../models/docx_style.dart';
import '../reader_context.dart';

/// Parses inline content (runs, text, hyperlinks).
class InlineParser {
  final ReaderContext context;

  InlineParser(this.context);

  /// Parse inline children from a container element.
  List<DocxInline> parseChildren(Iterable<XmlNode> nodes,
      {DocxStyle? parentStyle}) {
    final children = <DocxInline>[];
    for (var child in nodes) {
      if (child is XmlElement) {
        if (child.name.local == 'r') {
          children.add(parseRun(child, parentStyle: parentStyle));
        } else if (child.name.local == 'hyperlink') {
          children.addAll(_parseHyperlink(child, parentStyle: parentStyle));
        } else if (['ins', 'del', 'smartTag', 'sdt']
            .contains(child.name.local)) {
          // Handle inline containers (Track Changes, Smart Tags, etc.)
          var contentNodes = child.children;
          if (child.name.local == 'sdt') {
            final content = child.findAllElements('w:sdtContent').firstOrNull;
            if (content != null) contentNodes = content.children;
          }
          children
              .addAll(parseChildren(contentNodes, parentStyle: parentStyle));
        }
      }
    }
    return children;
  }

  /// Parse a single run (w:r) element.
  DocxInline parseRun(XmlElement run, {DocxStyle? parentStyle}) {
    // Check for line break
    if (run.findAllElements('w:br').isNotEmpty) {
      return const DocxLineBreak();
    }
    // Check for tab
    if (run.findAllElements('w:tab').isNotEmpty) {
      return const DocxTab();
    }

    // Check for drawings (handled separately by MediaHandler)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      // Return placeholder - actual parsing done by MediaHandler
      return _parseDrawing(drawing);
    }

    // Parse formatting
    final rPr = run.getElement('w:rPr');
    String? rStyle;
    if (rPr != null) {
      final rStyleElem = rPr.getElement('w:rStyle');
      if (rStyleElem != null) {
        rStyle = rStyleElem.getAttribute('w:val');
      }
    }

    // 1. Base style = Parent Paragraph Style (if any) or Default
    var baseStyle = parentStyle ?? context.resolveStyle('DefaultParagraphFont');

    // 2. Run Style (Character Style) - Overrides paragraph style properties
    if (rStyle != null) {
      final cStyle = context.resolveStyle(rStyle);
      baseStyle = baseStyle.merge(cStyle);
    }

    // 3. Direct Properties - Overrides everything
    final parsedProps = DocxStyle.fromXml('temp', rPr: rPr);
    final finalProps = baseStyle.merge(parsedProps);

    // Extract text
    final textElem = run.getElement('w:t');
    if (textElem != null) {
      return DocxText(
        textElem.innerText,
        fontWeight: finalProps.fontWeight ?? DocxFontWeight.normal,
        fontStyle: finalProps.fontStyle ?? DocxFontStyle.normal,
        decoration: finalProps.decoration ?? DocxTextDecoration.none,
        color: finalProps.color,
        shadingFill: finalProps.shadingFill,
        fontSize: finalProps.fontSize,
        fontFamily: finalProps.fontFamily,
        highlight: finalProps.highlight ?? DocxHighlight.none,
        isSuperscript: finalProps.isSuperscript ?? false,
        isSubscript: finalProps.isSubscript ?? false,
        isAllCaps: finalProps.isAllCaps ?? false,
        isSmallCaps: finalProps.isSmallCaps ?? false,
        isDoubleStrike: finalProps.isDoubleStrike ?? false,
        isOutline: finalProps.isOutline ?? false,
        isShadow: finalProps.isShadow ?? false,
        isEmboss: finalProps.isEmboss ?? false,
        isImprint: finalProps.isImprint ?? false,
      );
    }

    return DocxRawInline(run.toXmlString());
  }

  List<DocxInline> _parseHyperlink(XmlElement hyperlink,
      {DocxStyle? parentStyle}) {
    final results = <DocxInline>[];
    final rId = hyperlink.getAttribute('r:id');
    String? href;
    if (rId != null) {
      final rel = context.getRelationship(rId);
      if (rel != null) href = rel.target;
    }

    for (var grandChild in hyperlink.findAllElements('w:r')) {
      final run = parseRun(grandChild, parentStyle: parentStyle);
      if (run is DocxText && href != null) {
        results.add(run.copyWith(
          href: href,
          decoration: DocxTextDecoration.underline,
          color: DocxColor.blue,
        ));
      } else {
        results.add(run);
      }
    }
    return results;
  }

  DocxInline _parseDrawing(XmlElement drawing) {
    // Check for image
    final blip = drawing.findAllElements('a:blip').firstOrNull ??
        drawing.findAllElements('v:imagedata').firstOrNull;
    if (blip != null) {
      final embedId = blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
      if (embedId != null) {
        final rel = context.getRelationship(embedId);
        if (rel != null) {
          // Read image from archive
          String target = rel.target;
          if (!target.startsWith('/')) target = 'word/$target';
          final imageBytes = context.readBytes(target);
          if (imageBytes != null) {
            // Get dimensions
            double width = 100, height = 100;
            final extent = drawing.findAllElements('wp:extent').firstOrNull ??
                drawing.findAllElements('a:ext').firstOrNull;
            if (extent != null) {
              final cx = extent.getAttribute('cx');
              final cy = extent.getAttribute('cy');
              if (cx != null) width = int.parse(cx) / 914400 * 72;
              if (cy != null) height = int.parse(cy) / 914400 * 72;
            }
            // Determine extension from file path
            String ext = 'png';
            if (target.contains('.')) {
              ext = target.split('.').last.toLowerCase();
            }
            return DocxInlineImage(
              bytes: imageBytes,
              extension: ext,
              width: width,
              height: height,
            );
          }
        }
      }
    }

    // Check for shape
    final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
    if (wsp != null) {
      return _parseShape(drawing, wsp);
    }

    // Fallback
    return DocxRawInline(drawing.toXmlString());
  }

  DocxShape _parseShape(XmlElement drawingNode, XmlElement wsp) {
    // Determine position mode (inline vs floating)
    final isInline = drawingNode.findAllElements('wp:inline').isNotEmpty;
    final position =
        isInline ? DocxDrawingPosition.inline : DocxDrawingPosition.floating;

    // Read dimensions from extent (1 pt = 12700 EMU)
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

    return DocxShape(
      width: width,
      height: height,
      preset: preset,
      position: position,
      fillColor: fillColor,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      text: text,
    );
  }
}
