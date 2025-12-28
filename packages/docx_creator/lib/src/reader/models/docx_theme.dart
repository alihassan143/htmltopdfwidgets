import 'dart:typed_data';

import '../../../docx_creator.dart';
import 'docx_style.dart';

/// Represents the complete theme and style information from a DOCX document.
///
/// This class captures:
/// - Document defaults (default paragraph and run styles)
/// - Named styles (Normal, Heading1, etc.)
/// - Theme colors (accent colors, hyperlink colors, etc.)
/// - Theme fonts (major/minor fonts for headings and body)
/// - Numbering definitions
///
/// Use [DocxTheme] to understand the full styling context of a document.
class DocxTheme {
  /// Document default paragraph properties.
  final DocxStyle? defaultParagraphStyle;

  /// Document default run (character) properties.
  final DocxStyle? defaultRunStyle;

  /// Named styles map (styleId -> DocxStyle).
  final Map<String, DocxStyle> styles;

  /// Theme colors from theme1.xml.
  final DocxThemeColors colors;

  /// Theme fonts from theme1.xml.
  final DocxThemeFonts fonts;

  /// Latent style defaults (for styles not explicitly defined).
  final Map<String, LatentStyleDef> latentStyles;

  const DocxTheme({
    this.defaultParagraphStyle,
    this.defaultRunStyle,
    this.styles = const {},
    this.colors = const DocxThemeColors(),
    this.fonts = const DocxThemeFonts(),
    this.latentStyles = const {},
  });

  /// Creates an empty theme with defaults.
  factory DocxTheme.empty() => const DocxTheme();

  /// Gets a style by ID, returning null if not found.
  DocxStyle? getStyle(String styleId) => styles[styleId];

  /// Gets all styles of a specific type.
  List<DocxStyle> getStylesByType(String type) {
    return styles.values.where((s) => s.type == type).toList();
  }

  /// Gets all paragraph styles.
  List<DocxStyle> get paragraphStyles => getStylesByType('paragraph');

  /// Gets all character (run) styles.
  List<DocxStyle> get characterStyles => getStylesByType('character');

  /// Gets all table styles.
  List<DocxStyle> get tableStyles => getStylesByType('table');

  /// Gets all numbering styles.
  List<DocxStyle> get numberingStyles => getStylesByType('numbering');

  /// Gets the Normal paragraph style.
  DocxStyle? get normalStyle => styles['Normal'];

  /// Gets heading styles (Heading1, Heading2, etc.).
  List<DocxStyle> get headingStyles {
    return styles.entries
        .where((e) => e.key.startsWith('Heading'))
        .map((e) => e.value)
        .toList();
  }
}

/// Theme color definitions from theme1.xml.
///
/// Colors in OOXML themes use a scheme-based system where colors are
/// defined by role (accent1, accent2, etc.) rather than fixed values.
class DocxThemeColors {
  /// Dark 1 color (typically black or near-black).
  final String dk1;

  /// Light 1 color (typically white or near-white).
  final String lt1;

  /// Dark 2 color.
  final String dk2;

  /// Light 2 color.
  final String lt2;

  /// Accent colors (1-6).
  final String accent1;
  final String accent2;
  final String accent3;
  final String accent4;
  final String accent5;
  final String accent6;

  /// Hyperlink color.
  final String hlink;

  /// Followed hyperlink color.
  final String folHlink;

  const DocxThemeColors({
    this.dk1 = '000000',
    this.lt1 = 'FFFFFF',
    this.dk2 = '1F497D',
    this.lt2 = 'EEECE1',
    this.accent1 = '4F81BD',
    this.accent2 = 'C0504D',
    this.accent3 = '9BBB59',
    this.accent4 = '8064A2',
    this.accent5 = '4BACC6',
    this.accent6 = 'F79646',
    this.hlink = '0000FF',
    this.folHlink = '800080',
  });

  /// Gets a color by scheme name.
  ///
  /// Supports standard names (dk1, lt1, accent1-6, hlink, folHlink)
  /// and OOXML aliases (text1/2, background1/2).
  String? getColor(String schemeName) {
    switch (schemeName) {
      case 'dk1':
      case 'text1': // OOXML alias for dk1
        return dk1;
      case 'lt1':
      case 'background1': // OOXML alias for lt1
        return lt1;
      case 'dk2':
      case 'text2': // OOXML alias for dk2
        return dk2;
      case 'lt2':
      case 'background2': // OOXML alias for lt2
        return lt2;
      case 'accent1':
        return accent1;
      case 'accent2':
        return accent2;
      case 'accent3':
        return accent3;
      case 'accent4':
        return accent4;
      case 'accent5':
        return accent5;
      case 'accent6':
        return accent6;
      case 'hlink':
        return hlink;
      case 'folHlink':
        return folHlink;
      default:
        return null;
    }
  }

  /// All accent colors as a list.
  List<String> get accents =>
      [accent1, accent2, accent3, accent4, accent5, accent6];
}

/// Theme font definitions from theme1.xml.
class DocxThemeFonts {
  /// Major font (used for headings).
  final String majorLatin;
  final String majorEastAsia;
  final String majorComplexScript;

  /// Minor font (used for body text).
  final String minorLatin;
  final String minorEastAsia;
  final String minorComplexScript;

  const DocxThemeFonts({
    this.majorLatin = 'Calibri Light',
    this.majorEastAsia = '',
    this.majorComplexScript = '',
    this.minorLatin = 'Calibri',
    this.minorEastAsia = '',
    this.minorComplexScript = '',
  });

  /// Gets the font for headings.
  String get headingFont => majorLatin;

  /// Gets the font for body text.
  String get bodyFont => minorLatin;

  /// Gets a font by theme reference name (e.g. 'majorHAnsi').
  String? getFont(String themeFontName) {
    switch (themeFontName) {
      case 'majorHAnsi':
      case 'majorAscii':
        return majorLatin;
      case 'majorEastAsia':
        return majorEastAsia;
      case 'majorBidi':
        return majorComplexScript;
      case 'minorHAnsi':
      case 'minorAscii':
        return minorLatin;
      case 'minorEastAsia':
        return minorEastAsia;
      case 'minorBidi':
        return minorComplexScript;
      default:
        return null;
    }
  }
}

/// Latent style definition for styles not explicitly defined.
class LatentStyleDef {
  final String name;
  final bool semiHidden;
  final bool unhideWhenUsed;
  final int? uiPriority;
  final bool qFormat;

  const LatentStyleDef({
    required this.name,
    this.semiHidden = false,
    this.unhideWhenUsed = false,
    this.uiPriority,
    this.qFormat = false,
  });
}

/// Numbering definition from numbering.xml.
class DocxNumberingDef {
  /// Abstract numbering ID.
  final int abstractNumId;

  /// Numbering ID (used in paragraphs).
  final int numId;

  /// Level definitions (0-8).
  final List<DocxNumberingLevel> levels;

  const DocxNumberingDef({
    required this.abstractNumId,
    required this.numId,
    this.levels = const [],
  });
}

/// A single level in a numbering definition.
class DocxNumberingLevel {
  /// Level index (0-8).
  final int level;

  /// Numbering format (decimal, bullet, lowerLetter, etc.).
  final String numFmt;

  /// Level text pattern (e.g., "%1.", "%1.%2").
  final String? lvlText;

  /// Start value.
  final int start;

  /// Indentation left (twips).
  final int? indentLeft;

  /// Hanging indent (twips).
  final int? hanging;

  /// Bullet character (for bullet lists).
  final String? bulletChar;

  /// Font for bullet character.
  final String? bulletFont;

  /// Theme font reference.
  final String? themeFont;

  /// Theme color reference.
  final String? themeColor;
  final String? themeTint;
  final String? themeShade;

  /// Picture bullet ID (references a numPicBullet definition).
  final int? picBulletId;

  /// Picture bullet image bytes (resolved from media folder).
  final Uint8List? picBulletImage;

  const DocxNumberingLevel({
    required this.level,
    required this.numFmt,
    this.lvlText,
    this.start = 1,
    this.indentLeft,
    this.hanging,
    this.bulletChar,
    this.bulletFont,
    this.themeFont,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.picBulletId,
    this.picBulletImage,
  });

  /// Returns true if this is a bullet level.
  bool get isBullet => numFmt == 'bullet';

  /// Returns true if this is a numbered level.
  bool get isNumbered => !isBullet;

  /// Returns true if this is an image bullet level.
  bool get isImageBullet => picBulletId != null || picBulletImage != null;
}

/// Section properties from document.xml.
class DocxSectionProperties {
  /// Page width in twips.
  final int pageWidth;

  /// Page height in twips.
  final int pageHeight;

  /// Page orientation.
  final DocxPageOrientation orientation;

  /// Margins in twips.
  final int marginTop;
  final int marginBottom;
  final int marginLeft;
  final int marginRight;
  final int marginHeader;
  final int marginFooter;

  /// Gutter size in twips (extra margin for binding).
  final int gutter;

  /// Gutter position ('left' or 'top').
  final String gutterPosition;

  /// Number of columns.
  final int columns;

  /// Space between columns in twips.
  final int columnSpace;

  /// Whether columns have equal width.
  final bool equalColumnWidth;

  /// Individual column widths (if not equal).
  final List<int>? columnWidths;

  /// Line between columns.
  final bool lineBetweenColumns;

  /// Section type (continuous, nextPage, evenPage, oddPage).
  final String sectionType;

  /// Header/footer references.
  final String? headerDefault;
  final String? headerFirst;
  final String? headerEven;
  final String? footerDefault;
  final String? footerFirst;
  final String? footerEven;

  /// Whether first page has different header/footer.
  final bool titlePage;

  const DocxSectionProperties({
    this.pageWidth = 12240, // Letter width
    this.pageHeight = 15840, // Letter height
    this.orientation = DocxPageOrientation.portrait,
    this.marginTop = 1440,
    this.marginBottom = 1440,
    this.marginLeft = 1440,
    this.marginRight = 1440,
    this.marginHeader = 720,
    this.marginFooter = 720,
    this.gutter = 0,
    this.gutterPosition = 'left',
    this.columns = 1,
    this.columnSpace = 720,
    this.equalColumnWidth = true,
    this.columnWidths,
    this.lineBetweenColumns = false,
    this.sectionType = 'nextPage',
    this.headerDefault,
    this.headerFirst,
    this.headerEven,
    this.footerDefault,
    this.footerFirst,
    this.footerEven,
    this.titlePage = false,
  });

  /// Creates from page size enum.
  factory DocxSectionProperties.fromPageSize(DocxPageSize size) {
    switch (size) {
      case DocxPageSize.letter:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 15840);
      case DocxPageSize.a4:
        return const DocxSectionProperties(pageWidth: 11906, pageHeight: 16838);
      case DocxPageSize.legal:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 20160);
      case DocxPageSize.tabloid:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 15840);

      case DocxPageSize.custom:
        return const DocxSectionProperties();
    }
  }
}
