import 'package:xml/xml.dart';

import '../../../docx_creator.dart';

/// Represents parsed style properties from styles.xml.
///
/// Combines both paragraph (pPr) and run (rPr) properties into a single
/// object for easier merging and application.
class DocxStyle {
  final String id;
  final String? type;
  final String? basedOn;

  // Paragraph Properties
  final DocxAlign? align;
  final String? shadingFill;
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
  final DocxBorderSide? textBorder; // w:bdr element - border around text

  const DocxStyle({
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
    this.textBorder,
  });

  /// Creates an empty style with no properties set.
  factory DocxStyle.empty() => const DocxStyle(id: 'empty');

  /// Parse a style element from styles.xml.
  factory DocxStyle.fromXml(String id,
      {String? type, String? basedOn, XmlElement? pPr, XmlElement? rPr}) {
    final pProps = _parseParagraphProperties(pPr);
    final rProps = _parseRunProperties(rPr);

    return DocxStyle(
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
      textBorder: rProps.textBorder,
    );
  }

  /// Merge this style (as base) with override properties from another style.
  DocxStyle merge(DocxStyle other) {
    return DocxStyle(
      id: other.id == 'temp' || other.id == 'empty' ? id : other.id,
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
      textBorder: other.textBorder ?? textBorder,
    );
  }

  // ============================================================
  // PARAGRAPH PROPERTIES PARSER
  // ============================================================

  static DocxStyle _parseParagraphProperties(XmlElement? pPr) {
    if (pPr == null) return const DocxStyle(id: 'temp');

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
      borderTop = _parseBorderSide(pBdr.getElement('w:top'));
      borderBottomSide = _parseBorderSide(pBdr.getElement('w:bottom'));
      borderLeft = _parseBorderSide(pBdr.getElement('w:left'));
      borderRight = _parseBorderSide(pBdr.getElement('w:right'));
      borderBetween = _parseBorderSide(pBdr.getElement('w:between'));
    }

    return DocxStyle(
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
    );
  }

  // ============================================================
  // RUN PROPERTIES PARSER
  // ============================================================

  static DocxStyle _parseRunProperties(XmlElement? rPr) {
    if (rPr == null) return const DocxStyle(id: 'temp');

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

    // Parse text border (w:bdr) - box around text
    DocxBorderSide? textBorder;
    final bdrElem = rPr.getElement('w:bdr');
    if (bdrElem != null) {
      textBorder = _parseBorderSide(bdrElem);
    }

    return DocxStyle(
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
      textBorder: textBorder,
    );
  }

  // ============================================================
  // BORDER PARSER HELPER
  // ============================================================

  static DocxBorderSide? _parseBorderSide(XmlElement? el) {
    if (el == null) return null;
    final val = el.getAttribute('w:val');
    if (val == null || val == 'none' || val == 'nil') return null;

    int size = 4;
    final szAttr = el.getAttribute('w:sz');
    if (szAttr != null) {
      final s = int.tryParse(szAttr);
      if (s != null) size = s;
    }

    var color = DocxColor.black;
    final colorAttr = el.getAttribute('w:color');
    if (colorAttr != null && colorAttr != 'auto') {
      color = DocxColor(colorAttr);
    }

    var style = DocxBorder.single;
    for (var b in DocxBorder.values) {
      if (b.xmlValue == val) {
        style = b;
        break;
      }
    }

    return DocxBorderSide(style: style, size: size, color: color);
  }
}
