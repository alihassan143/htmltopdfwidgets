import 'package:xml/xml.dart';

import '../../../docx_creator.dart';
import '../models/docx_style.dart';
import '../reader_context.dart';

/// Parses and manages document styles from styles.xml.
///
/// Enhanced to support full theme extraction including:
/// - Document defaults
/// - Named styles with inheritance
/// - Latent styles
/// - Table conditional styles
class StyleParser {
  final ReaderContext context;

  /// Parsed document defaults.
  DocxStyle? _defaultParagraphStyle;
  DocxStyle? _defaultRunStyle;

  /// Parsed latent styles.
  final Map<String, LatentStyleDef> _latentStyles = {};

  StyleParser(this.context);

  /// Gets the parsed default paragraph style.
  DocxStyle? get defaultParagraphStyle => _defaultParagraphStyle;

  /// Gets the parsed default run style.
  DocxStyle? get defaultRunStyle => _defaultRunStyle;

  /// Gets the parsed latent styles.
  Map<String, LatentStyleDef> get latentStyles =>
      Map.unmodifiable(_latentStyles);

  /// Parse styles.xml and populate the context's styles map.
  void parse(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);

      // Parse document defaults
      _parseDocDefaults(xml);

      // Parse latent styles
      _parseLatentStyles(xml);

      // Parse named styles
      _parseNamedStyles(xml);
    } catch (e) {
      // Ignore style parsing errors - graceful degradation
      print('Error parsing styles: $e');
    }
  }

  /// Parse document defaults (docDefaults element).
  void _parseDocDefaults(XmlDocument xml) {
    final docDefaults = xml.findAllElements('w:docDefaults').firstOrNull;
    if (docDefaults == null) return;

    // Parse default paragraph properties
    final pPrDefault = docDefaults.findAllElements('w:pPrDefault').firstOrNull;
    if (pPrDefault != null) {
      final pPr = pPrDefault.getElement('w:pPr');
      if (pPr != null) {
        _defaultParagraphStyle = DocxStyle.fromXml(
          '__docDefault_pPr',
          pPr: pPr,
        );
      }
    }

    // Parse default run properties
    final rPrDefault = docDefaults.findAllElements('w:rPrDefault').firstOrNull;
    if (rPrDefault != null) {
      final rPr = rPrDefault.getElement('w:rPr');
      if (rPr != null) {
        _defaultRunStyle = DocxStyle.fromXml(
          '__docDefault_rPr',
          rPr: rPr,
        );
      }
    }
  }

  /// Parse latent styles (latentStyles element).
  void _parseLatentStyles(XmlDocument xml) {
    final latentStyles = xml.findAllElements('w:latentStyles').firstOrNull;
    if (latentStyles == null) return;

    for (var lsdException in latentStyles.findAllElements('w:lsdException')) {
      final name = lsdException.getAttribute('w:name');
      if (name == null) continue;

      _latentStyles[name] = LatentStyleDef(
        name: name,
        semiHidden: lsdException.getAttribute('w:semiHidden') == '1',
        unhideWhenUsed: lsdException.getAttribute('w:unhideWhenUsed') == '1',
        uiPriority:
            int.tryParse(lsdException.getAttribute('w:uiPriority') ?? ''),
        qFormat: lsdException.getAttribute('w:qFormat') == '1',
      );
    }
  }

  /// Parse named styles (w:style elements).
  void _parseNamedStyles(XmlDocument xml) {
    for (var styleElem in xml.findAllElements('w:style')) {
      final styleId = styleElem.getAttribute('w:styleId');
      final type = styleElem.getAttribute('w:type');
      if (styleId == null) continue;

      final basedOn = styleElem.getElement('w:basedOn')?.getAttribute('w:val');
      final pPr = styleElem.getElement('w:pPr');
      final rPr = styleElem.getElement('w:rPr');
      final tcPr = styleElem.getElement('w:tcPr');

      // Parse conditional table styles
      final tableConditionals = <String, DocxStyle>{};
      for (var tblStylePr in styleElem.findAllElements('w:tblStylePr')) {
        final condType = tblStylePr.getAttribute('w:type');
        if (condType != null) {
          final condPPr = tblStylePr.getElement('w:pPr');
          final condRPr = tblStylePr.getElement('w:rPr');
          final condTcPr = tblStylePr.getElement('w:tcPr');

          tableConditionals[condType] = DocxStyle.fromXml(
            'conditional',
            pPr: condPPr,
            rPr: condRPr,
            tcPr: condTcPr,
          );
        }
      }

      context.styles[styleId] = DocxStyle.fromXml(
        styleId,
        type: type,
        basedOn: basedOn,
        pPr: pPr,
        rPr: rPr,
        tcPr: tcPr,
        tableConditionals: tableConditionals,
      );
    }
  }

  /// Resolve a style by ID with inheritance support.
  /// Delegates to context.resolveStyle for centralized resolution.
  DocxStyle resolve(String? styleId) => context.resolveStyle(styleId);

  /// Builds a complete DocxTheme from the parsed styles.
  DocxTheme buildTheme({
    DocxThemeColors? colors,
    DocxThemeFonts? fonts,
  }) {
    return DocxTheme(
      defaultParagraphStyle: _defaultParagraphStyle,
      defaultRunStyle: _defaultRunStyle,
      styles: Map.from(context.styles),
      colors: colors ?? const DocxThemeColors(),
      fonts: fonts ?? const DocxThemeFonts(),
      latentStyles: Map.from(_latentStyles),
    );
  }
}

/// Parses theme colors and fonts from theme1.xml.
class ThemeParser {
  /// Parse theme1.xml and extract colors and fonts.
  static (DocxThemeColors, DocxThemeFonts) parse(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);
      return (_parseColors(xml), _parseFonts(xml));
    } catch (e) {
      return (const DocxThemeColors(), const DocxThemeFonts());
    }
  }

  static DocxThemeColors _parseColors(XmlDocument xml) {
    final clrScheme = xml.findAllElements('a:clrScheme').firstOrNull;
    if (clrScheme == null) return const DocxThemeColors();

    String getColor(String name) {
      final elem = clrScheme.getElement('a:$name');
      if (elem == null) return '';

      // Check for sysClr (system color)
      final sysClr = elem.getElement('a:sysClr');
      if (sysClr != null) {
        return sysClr.getAttribute('lastClr') ??
            sysClr.getAttribute('val') ??
            '';
      }

      // Check for srgbClr (SRGB color)
      final srgbClr = elem.getElement('a:srgbClr');
      if (srgbClr != null) {
        return srgbClr.getAttribute('val') ?? '';
      }

      return '';
    }

    return DocxThemeColors(
      dk1: getColor('dk1').isNotEmpty ? getColor('dk1') : '000000',
      lt1: getColor('lt1').isNotEmpty ? getColor('lt1') : 'FFFFFF',
      dk2: getColor('dk2').isNotEmpty ? getColor('dk2') : '1F497D',
      lt2: getColor('lt2').isNotEmpty ? getColor('lt2') : 'EEECE1',
      accent1: getColor('accent1').isNotEmpty ? getColor('accent1') : '4F81BD',
      accent2: getColor('accent2').isNotEmpty ? getColor('accent2') : 'C0504D',
      accent3: getColor('accent3').isNotEmpty ? getColor('accent3') : '9BBB59',
      accent4: getColor('accent4').isNotEmpty ? getColor('accent4') : '8064A2',
      accent5: getColor('accent5').isNotEmpty ? getColor('accent5') : '4BACC6',
      accent6: getColor('accent6').isNotEmpty ? getColor('accent6') : 'F79646',
      hlink: getColor('hlink').isNotEmpty ? getColor('hlink') : '0000FF',
      folHlink:
          getColor('folHlink').isNotEmpty ? getColor('folHlink') : '800080',
    );
  }

  static DocxThemeFonts _parseFonts(XmlDocument xml) {
    final fontScheme = xml.findAllElements('a:fontScheme').firstOrNull;
    if (fontScheme == null) return const DocxThemeFonts();

    String getMajorFont(String script) {
      final majorFont = fontScheme.getElement('a:majorFont');
      if (majorFont == null) return '';
      final elem = majorFont.getElement('a:$script');
      return elem?.getAttribute('typeface') ?? '';
    }

    String getMinorFont(String script) {
      final minorFont = fontScheme.getElement('a:minorFont');
      if (minorFont == null) return '';
      final elem = minorFont.getElement('a:$script');
      return elem?.getAttribute('typeface') ?? '';
    }

    return DocxThemeFonts(
      majorLatin: getMajorFont('latin').isNotEmpty
          ? getMajorFont('latin')
          : 'Calibri Light',
      majorEastAsia: getMajorFont('ea'),
      majorComplexScript: getMajorFont('cs'),
      minorLatin:
          getMinorFont('latin').isNotEmpty ? getMinorFont('latin') : 'Calibri',
      minorEastAsia: getMinorFont('ea'),
      minorComplexScript: getMinorFont('cs'),
    );
  }
}

/// Parses numbering definitions from numbering.xml.
class NumberingParser {
  final ReaderContext context;

  /// Parsed abstract numbering definitions.
  final Map<int, List<DocxNumberingLevel>> _abstractNums = {};

  /// Parsed numbering instances.
  final Map<int, DocxNumberingDef> _numberings = {};

  NumberingParser(this.context);

  /// Gets parsed numbering definitions.
  Map<int, DocxNumberingDef> get numberings => Map.unmodifiable(_numberings);

  /// Parse numbering.xml content.
  void parse(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);

      // First pass: parse abstract numbering definitions
      for (var abstractNum in xml.findAllElements('w:abstractNum')) {
        final abstractNumId =
            int.tryParse(abstractNum.getAttribute('w:abstractNumId') ?? '');
        if (abstractNumId == null) continue;

        final levels = <DocxNumberingLevel>[];
        for (var lvl in abstractNum.findAllElements('w:lvl')) {
          final level = _parseLevel(lvl);
          if (level != null) levels.add(level);
        }
        _abstractNums[abstractNumId] = levels;
      }

      // Second pass: parse numbering instances
      for (var num in xml.findAllElements('w:num')) {
        final numId = int.tryParse(num.getAttribute('w:numId') ?? '');
        if (numId == null) continue;

        final abstractNumIdRef =
            num.getElement('w:abstractNumId')?.getAttribute('w:val');
        final abstractNumId = int.tryParse(abstractNumIdRef ?? '');
        if (abstractNumId == null) continue;

        _numberings[numId] = DocxNumberingDef(
          abstractNumId: abstractNumId,
          numId: numId,
          levels: _abstractNums[abstractNumId] ?? [],
        );
      }
    } catch (e) {
      print('Error parsing numbering: $e');
    }
  }

  DocxNumberingLevel? _parseLevel(XmlElement lvl) {
    final ilvl = int.tryParse(lvl.getAttribute('w:ilvl') ?? '');
    if (ilvl == null) return null;

    final numFmt =
        lvl.getElement('w:numFmt')?.getAttribute('w:val') ?? 'decimal';
    final lvlText = lvl.getElement('w:lvlText')?.getAttribute('w:val');
    final start =
        int.tryParse(lvl.getElement('w:start')?.getAttribute('w:val') ?? '1') ??
            1;

    // Parse indentation
    int? indentLeft;
    int? hanging;
    final pPr = lvl.getElement('w:pPr');
    if (pPr != null) {
      final ind = pPr.getElement('w:ind');
      if (ind != null) {
        indentLeft = int.tryParse(ind.getAttribute('w:left') ?? '');
        hanging = int.tryParse(ind.getAttribute('w:hanging') ?? '');
      }
    }

    // Parse bullet character
    String? bulletChar;
    String? bulletFont;
    final rPr = lvl.getElement('w:rPr');
    if (numFmt == 'bullet') {
      bulletChar = lvlText;
      if (rPr != null) {
        final rFonts = rPr.getElement('w:rFonts');
        bulletFont =
            rFonts?.getAttribute('w:ascii') ?? rFonts?.getAttribute('w:hAnsi');
      }
    }

    return DocxNumberingLevel(
      level: ilvl,
      numFmt: numFmt,
      lvlText: lvlText,
      start: start,
      indentLeft: indentLeft,
      hanging: hanging,
      bulletChar: bulletChar,
      bulletFont: bulletFont,
    );
  }

  /// Gets the numbering definition for a numId.
  DocxNumberingDef? getNumbering(int numId) => _numberings[numId];

  /// Gets the level definition for a numbering.
  DocxNumberingLevel? getLevel(int numId, int ilvl) {
    final def = _numberings[numId];
    if (def == null) return null;
    return def.levels.where((l) => l.level == ilvl).firstOrNull;
  }
}

/// Parses section properties from document.xml.
class SectionPropertiesParser {
  /// Parse a sectPr element.
  static DocxSectionProperties parse(XmlElement sectPr) {
    // Page size
    int pageWidth = 12240;
    int pageHeight = 15840;
    var orientation = DocxPageOrientation.portrait;
    final pgSz = sectPr.getElement('w:pgSz');
    if (pgSz != null) {
      pageWidth = int.tryParse(pgSz.getAttribute('w:w') ?? '') ?? 12240;
      pageHeight = int.tryParse(pgSz.getAttribute('w:h') ?? '') ?? 15840;
      if (pgSz.getAttribute('w:orient') == 'landscape') {
        orientation = DocxPageOrientation.landscape;
      }
    }

    // Page margins
    int marginTop = 1440, marginBottom = 1440;
    int marginLeft = 1440, marginRight = 1440;
    int marginHeader = 720, marginFooter = 720;
    int gutter = 0;
    final pgMar = sectPr.getElement('w:pgMar');
    if (pgMar != null) {
      marginTop = int.tryParse(pgMar.getAttribute('w:top') ?? '') ?? 1440;
      marginBottom = int.tryParse(pgMar.getAttribute('w:bottom') ?? '') ?? 1440;
      marginLeft = int.tryParse(pgMar.getAttribute('w:left') ?? '') ?? 1440;
      marginRight = int.tryParse(pgMar.getAttribute('w:right') ?? '') ?? 1440;
      marginHeader = int.tryParse(pgMar.getAttribute('w:header') ?? '') ?? 720;
      marginFooter = int.tryParse(pgMar.getAttribute('w:footer') ?? '') ?? 720;
      gutter = int.tryParse(pgMar.getAttribute('w:gutter') ?? '') ?? 0;
    }

    // Columns
    int columns = 1;
    int columnSpace = 720;
    bool equalWidth = true;
    bool lineBetween = false;
    List<int>? columnWidths;
    final cols = sectPr.getElement('w:cols');
    if (cols != null) {
      columns = int.tryParse(cols.getAttribute('w:num') ?? '') ?? 1;
      columnSpace = int.tryParse(cols.getAttribute('w:space') ?? '') ?? 720;
      equalWidth = cols.getAttribute('w:equalWidth') != '0';
      lineBetween = cols.getAttribute('w:sep') == '1';

      if (!equalWidth) {
        columnWidths = [];
        for (var col in cols.findAllElements('w:col')) {
          final w = int.tryParse(col.getAttribute('w:w') ?? '');
          if (w != null) columnWidths.add(w);
        }
      }
    }

    // Section type
    String sectionType = 'nextPage';
    final type = sectPr.getElement('w:type');
    if (type != null) {
      sectionType = type.getAttribute('w:val') ?? 'nextPage';
    }

    // Header/footer references
    String? headerDefault, headerFirst, headerEven;
    String? footerDefault, footerFirst, footerEven;
    for (var hdrRef in sectPr.findAllElements('w:headerReference')) {
      final type = hdrRef.getAttribute('w:type');
      final rId = hdrRef.getAttribute('r:id');
      if (type == 'default') headerDefault = rId;
      if (type == 'first') headerFirst = rId;
      if (type == 'even') headerEven = rId;
    }
    for (var ftrRef in sectPr.findAllElements('w:footerReference')) {
      final type = ftrRef.getAttribute('w:type');
      final rId = ftrRef.getAttribute('r:id');
      if (type == 'default') footerDefault = rId;
      if (type == 'first') footerFirst = rId;
      if (type == 'even') footerEven = rId;
    }

    // Title page
    final titlePage = sectPr.getElement('w:titlePg') != null;

    return DocxSectionProperties(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      orientation: orientation,
      marginTop: marginTop,
      marginBottom: marginBottom,
      marginLeft: marginLeft,
      marginRight: marginRight,
      marginHeader: marginHeader,
      marginFooter: marginFooter,
      gutter: gutter,
      columns: columns,
      columnSpace: columnSpace,
      equalColumnWidth: equalWidth,
      columnWidths: columnWidths,
      lineBetweenColumns: lineBetween,
      sectionType: sectionType,
      headerDefault: headerDefault,
      headerFirst: headerFirst,
      headerEven: headerEven,
      footerDefault: footerDefault,
      footerFirst: footerFirst,
      footerEven: footerEven,
      titlePage: titlePage,
    );
  }
}
