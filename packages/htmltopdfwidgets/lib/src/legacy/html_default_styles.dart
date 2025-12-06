import 'package:pdf/widgets.dart';

/// Browser default styles following W3C user agent stylesheet standards
class HtmlDefaultStyles {
  // Block element margins (in points)
  static const double blockMarginTop = 16.0;
  static const double blockMarginBottom = 16.0;

  // Heading font sizes (based on browser defaults)
  static const Map<int, double> headingSizes = {
    1: 32.0, // 2em
    2: 24.0, // 1.5em
    3: 18.67, // 1.17em
    4: 16.0, // 1em
    5: 13.28, // 0.83em
    6: 10.72, // 0.67em
  };

  // Heading margins (in points, browser-standard)
  static const Map<int, EdgeInsets> headingMargins = {
    1: EdgeInsets.symmetric(vertical: 21.44), // 0.67em top/bottom
    2: EdgeInsets.symmetric(vertical: 19.92), // 0.83em top/bottom
    3: EdgeInsets.symmetric(vertical: 18.67), // 1em top/bottom
    4: EdgeInsets.symmetric(vertical: 21.28), // 1.33em top/bottom
    5: EdgeInsets.symmetric(vertical: 21.84), // 1.67em top/bottom
    6: EdgeInsets.symmetric(vertical: 28.8), // 2.33em top/bottom
  };

  // Paragraph default margin
  static const EdgeInsets paragraphMargin =
      EdgeInsets.symmetric(vertical: 16.0); // 1em top/bottom

  // List margins and padding (browser defaults)
  static const double listMarginTop = 16.0; // 1em
  static const double listMarginBottom = 16.0; // 1em
  static const double listPaddingLeft = 40.0; // Standard indent

  // Blockquote margins (browser defaults)
  static const EdgeInsets blockquoteMargin = EdgeInsets.only(
    top: 16.0,
    bottom: 16.0,
    left: 40.0,
    right: 40.0,
  );

  // Table defaults
  static const double tableBorderSpacing = 2.0;
  static const EdgeInsets tableCellPadding = EdgeInsets.all(1.0);
  static const EdgeInsets thCellPadding = EdgeInsets.all(2.0);

  // Font weights
  static const FontWeight boldWeight = FontWeight.bold;
  static const FontWeight normalWeight = FontWeight.normal;

  /// Get default margin for HTML element
  static EdgeInsets? getDefaultMargin(String tagName) {
    switch (tagName) {
      case 'h1':
        return headingMargins[1];
      case 'h2':
        return headingMargins[2];
      case 'h3':
        return headingMargins[3];
      case 'h4':
        return headingMargins[4];
      case 'h5':
        return headingMargins[5];
      case 'h6':
        return headingMargins[6];
      case 'p':
        return paragraphMargin;
      case 'blockquote':
        return blockquoteMargin;
      case 'ul':
      case 'ol':
        return EdgeInsets.only(
          top: listMarginTop,
          bottom: listMarginBottom,
        );
      default:
        return null;
    }
  }

  /// Get default padding for HTML element
  static EdgeInsets? getDefaultPadding(String tagName) {
    switch (tagName) {
      case 'ul':
      case 'ol':
        return EdgeInsets.only(left: listPaddingLeft);
      case 'td':
        return tableCellPadding;
      case 'th':
        return thCellPadding;
      default:
        return null;
    }
  }

  /// Get default font size for HTML element
  static double? getDefaultFontSize(String tagName, double baseFontSize) {
    if (tagName.startsWith('h') && tagName.length == 2) {
      final level = int.tryParse(tagName[1]);
      if (level != null && level >= 1 && level <= 6) {
        return headingSizes[level];
      }
    }
    return null;
  }

  /// Get default font weight for HTML element
  static FontWeight? getDefaultFontWeight(String tagName) {
    switch (tagName) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'b':
      case 'strong':
      case 'th':
        return boldWeight;
      default:
        return null;
    }
  }

  /// Get default font style for HTML element
  static FontStyle? getDefaultFontStyle(String tagName) {
    switch (tagName) {
      case 'i':
      case 'em':
        return FontStyle.italic;
      default:
        return null;
    }
  }

  /// Get default text alignment for HTML element
  static TextAlign? getDefaultTextAlign(String tagName) {
    switch (tagName) {
      case 'th':
        return TextAlign.center;
      case 'td':
        return TextAlign.left;
      default:
        return null;
    }
  }
}
