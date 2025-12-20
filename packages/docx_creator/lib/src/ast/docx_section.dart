import 'package:xml/xml.dart';

import '../core/defaults.dart';
import '../core/enums.dart';
import 'docx_background_image.dart';
import 'docx_block.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// Customizable heading style.
///
/// ```dart
/// final h1Style = DocxHeadingStyle(
///   fontSize: 28,
///   color: DocxColor('#2E74B5'),
///   fontFamily: 'Georgia',
///   spacingBefore: 300,
/// );
///
/// DocxParagraph.heading(DocxHeadingLevel.h1, 'Title', style: h1Style)
/// ```
class DocxHeadingStyle {
  final double fontSize;
  final DocxColor? color;
  final String? fontFamily;
  final bool bold;
  final int spacingBefore;
  final int spacingAfter;
  final DocxAlign align;

  const DocxHeadingStyle({
    this.fontSize = 24,
    this.color,
    this.fontFamily,
    this.bold = true,
    this.spacingBefore = 240,
    this.spacingAfter = 120,
    this.align = DocxAlign.left,
  });

  /// Default styles for each heading level
  static DocxHeadingStyle forLevel(DocxHeadingLevel level) {
    switch (level) {
      case DocxHeadingLevel.h1:
        return const DocxHeadingStyle(fontSize: 24, spacingBefore: 300);
      case DocxHeadingLevel.h2:
        return const DocxHeadingStyle(fontSize: 20, spacingBefore: 240);
      case DocxHeadingLevel.h3:
        return const DocxHeadingStyle(fontSize: 16, spacingBefore: 200);
      case DocxHeadingLevel.h4:
        return const DocxHeadingStyle(fontSize: 14, spacingBefore: 160);
      case DocxHeadingLevel.h5:
        return const DocxHeadingStyle(fontSize: 12, spacingBefore: 120);
      case DocxHeadingLevel.h6:
        return const DocxHeadingStyle(fontSize: 11, spacingBefore: 100);
    }
  }

  DocxHeadingStyle copyWith({
    double? fontSize,
    DocxColor? color,
    String? fontFamily,
    bool? bold,
    int? spacingBefore,
    int? spacingAfter,
    DocxAlign? align,
  }) {
    return DocxHeadingStyle(
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      spacingBefore: spacingBefore ?? this.spacingBefore,
      spacingAfter: spacingAfter ?? this.spacingAfter,
      align: align ?? this.align,
    );
  }
}

/// Document section with page layout and headers/footers.
///
/// ```dart
/// DocxSectionDef(
///   backgroundColor: DocxColor('#F5F5F5'),
///   header: DocxHeader.text('My Document'),
///   footer: DocxFooter.pageNumbers(),
/// )
/// ```
class DocxSectionDef extends DocxSection {
  final DocxPageOrientation orientation;
  final DocxPageSize pageSize;
  final int? customWidth;
  final int? customHeight;
  final int marginTop;
  final int marginBottom;
  final int marginLeft;
  final int marginRight;
  final DocxSectionBreak breakType;
  final DocxHeader? header;
  final DocxFooter? footer;

  /// Background color for all pages in this section.
  final DocxColor? backgroundColor;

  /// Background image for all pages in this section.
  ///
  /// If both [backgroundColor] and [backgroundImage] are set,
  /// the image will be rendered on top of the color.
  final DocxBackgroundImage? backgroundImage;

  const DocxSectionDef({
    this.orientation = DocxPageOrientation.portrait,
    this.pageSize = DocxPageSize.letter,
    this.customWidth,
    this.customHeight,
    this.marginTop = kDefaultMarginTop,
    this.marginBottom = kDefaultMarginBottom,
    this.marginLeft = kDefaultMarginLeft,
    this.marginRight = kDefaultMarginRight,
    this.breakType = DocxSectionBreak.nextPage,
    this.header,
    this.footer,
    this.backgroundColor,
    this.backgroundImage,
    super.id,
  });

  /// Returns a copy with specified modifications.
  DocxSectionDef copyWith({
    DocxPageOrientation? orientation,
    DocxPageSize? pageSize,
    int? customWidth,
    int? customHeight,
    int? marginTop,
    int? marginBottom,
    int? marginLeft,
    int? marginRight,
    DocxSectionBreak? breakType,
    DocxHeader? header,
    DocxFooter? footer,
    DocxColor? backgroundColor,
    DocxBackgroundImage? backgroundImage,
  }) {
    return DocxSectionDef(
      orientation: orientation ?? this.orientation,
      pageSize: pageSize ?? this.pageSize,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      breakType: breakType ?? this.breakType,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      id: id,
    );
  }

  int get effectiveWidth {
    if (pageSize == DocxPageSize.custom && customWidth != null) {
      return customWidth!;
    }
    switch (pageSize) {
      case DocxPageSize.letter:
        return 12240;
      case DocxPageSize.a4:
        return 11906;
      case DocxPageSize.legal:
        return 12240;
      case DocxPageSize.tabloid:
        return 15840;
      case DocxPageSize.custom:
        return customWidth ?? 12240;
    }
  }

  int get effectiveHeight {
    if (pageSize == DocxPageSize.custom && customHeight != null) {
      return customHeight!;
    }
    switch (pageSize) {
      case DocxPageSize.letter:
        return 15840;
      case DocxPageSize.a4:
        return 16838;
      case DocxPageSize.legal:
        return 20160;
      case DocxPageSize.tabloid:
        return 24480;
      case DocxPageSize.custom:
        return customHeight ?? 15840;
    }
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitSection(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:sectPr',
      nest: () {
        final isLandscape = orientation == DocxPageOrientation.landscape;
        builder.element(
          'w:pgSz',
          nest: () {
            builder.attribute(
              'w:w',
              (isLandscape ? effectiveHeight : effectiveWidth).toString(),
            );
            builder.attribute(
              'w:h',
              (isLandscape ? effectiveWidth : effectiveHeight).toString(),
            );
            if (isLandscape) builder.attribute('w:orient', 'landscape');
          },
        );
        builder.element(
          'w:pgMar',
          nest: () {
            builder.attribute('w:top', marginTop.toString());
            builder.attribute('w:right', marginRight.toString());
            builder.attribute('w:bottom', marginBottom.toString());
            builder.attribute('w:left', marginLeft.toString());
            builder.attribute('w:header', kDefaultHeaderDistance.toString());
            builder.attribute('w:footer', kDefaultFooterDistance.toString());
          },
        );
      },
    );
  }
}

/// Header content for a document section.
///
/// ## Simple
/// ```dart
/// DocxHeader.text('My Document')
/// ```
///
/// ## Styled
/// ```dart
/// DocxHeader.styled('Title', color: DocxColor.blue, fontSize: 14)
/// ```
///
/// ## Rich Content
/// ```dart
/// DocxHeader(children: [
///   DocxParagraph(children: [
///     DocxText.bold('Company Name'),
///     DocxText(' - Confidential'),
///   ]),
/// ])
/// ```
class DocxHeader extends DocxSection {
  final List<DocxBlock> children;

  const DocxHeader({required this.children, super.id});

  /// Simple text header.
  factory DocxHeader.text(String text, {DocxAlign align = DocxAlign.center}) {
    return DocxHeader(
      children: [
        DocxParagraph(align: align, children: [DocxText(text)]),
      ],
    );
  }

  /// Styled text header.
  factory DocxHeader.styled(
    String text, {
    DocxColor? color,
    double? fontSize,
    String? fontFamily,
    bool bold = false,
    DocxAlign align = DocxAlign.center,
  }) {
    return DocxHeader(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText(
              text,
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
            ),
          ],
        ),
      ],
    );
  }

  DocxHeader copyWith({List<DocxBlock>? children}) {
    return DocxHeader(children: children ?? this.children, id: id);
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitHeader(this);

  @override
  void buildXml(XmlBuilder builder) {
    for (var child in children) {
      child.buildXml(builder);
    }
  }
}

/// Footer content for a document section.
///
/// ## Simple
/// ```dart
/// DocxFooter.text('© 2024 Company')
/// ```
///
/// ## Page Numbers
/// ```dart
/// DocxFooter.pageNumbers()
/// ```
///
/// ## Styled
/// ```dart
/// DocxFooter.styled('Confidential', color: DocxColor.gray)
/// ```
class DocxFooter extends DocxSection {
  final List<DocxBlock> children;

  const DocxFooter({required this.children, super.id});

  /// Simple text footer.
  factory DocxFooter.text(String text, {DocxAlign align = DocxAlign.center}) {
    return DocxFooter(
      children: [
        DocxParagraph(align: align, children: [DocxText(text)]),
      ],
    );
  }

  /// Styled text footer.
  factory DocxFooter.styled(
    String text, {
    DocxColor? color,
    double? fontSize,
    String? fontFamily,
    bool bold = false,
    DocxAlign align = DocxAlign.center,
  }) {
    return DocxFooter(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText(
              text,
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
            ),
          ],
        ),
      ],
    );
  }

  /// Footer with page numbers.
  factory DocxFooter.pageNumbers({DocxAlign align = DocxAlign.center}) {
    return DocxFooter(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText('Page '),
            DocxPageNumber(),
            DocxText(' of '),
            DocxPageCount(),
          ],
        ),
      ],
    );
  }

  DocxFooter copyWith({List<DocxBlock>? children}) {
    return DocxFooter(children: children ?? this.children, id: id);
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitFooter(this);

  @override
  void buildXml(XmlBuilder builder) {
    for (var child in children) {
      child.buildXml(builder);
    }
  }
}

/// Page number field.
class DocxPageNumber extends DocxInline {
  const DocxPageNumber({super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:fldChar',
          nest: () {
            builder.attribute('w:fldCharType', 'begin');
          },
        );
      },
    );
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:instrText',
          nest: () {
            builder.text(' PAGE ');
          },
        );
      },
    );
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:fldChar',
          nest: () {
            builder.attribute('w:fldCharType', 'end');
          },
        );
      },
    );
  }
}

/// Total page count field.
class DocxPageCount extends DocxInline {
  const DocxPageCount({super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:fldChar',
          nest: () {
            builder.attribute('w:fldCharType', 'begin');
          },
        );
      },
    );
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:instrText',
          nest: () {
            builder.text(' NUMPAGES ');
          },
        );
      },
    );
    builder.element(
      'w:r',
      nest: () {
        builder.element(
          'w:fldChar',
          nest: () {
            builder.attribute('w:fldCharType', 'end');
          },
        );
      },
    );
  }
}
