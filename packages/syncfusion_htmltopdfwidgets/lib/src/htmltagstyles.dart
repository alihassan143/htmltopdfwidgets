import 'package:flutter/painting.dart';

/// apply custom styles to html style
class HtmlTagStyle {
  //bold  style that will merge with default style
  final TextStyle? boldStyle;
  //italic style that will merge with default style
  final TextStyle? italicStyle;
  //h1 tag style that will merge with default style
  final TextStyle? h1Style;
  //h2 tag style that will merge with default style
  final TextStyle? h2Style;
  //h3 tag style that will merge with default style
  final TextStyle? h3Style;
  //h4 tag style that will merge with default style
  final TextStyle? h4Style;
  //h5 tag style that will merge with default style
  final TextStyle? h5Style;
  //h6 tag style that will merge with default style
  final TextStyle? h6Style;
  //strike through style that will merge with default style
  final TextStyle? strikeThrough;
  //image alignment style that will merge with default style
  final Alignment imageAlignment;
  //paragraph style style that will merge with default style
  final TextStyle? paragraphStyle;
  //code tag style that will merge with default style
  final TextStyle? codeStyle;
  //heading style style that will merge with default style
  final TextStyle? headingStyle;
  //list index style style that will merge with default style
  final TextStyle? listIndexStyle;
  //href link style style that will merge with default style
  final TextStyle? linkStyle;
  //quote bar style that will merge with default style
  final Color? quoteBarColor;
  //bullet list style style that will merge with default style
  /// The color of the bullet list icon in a PDF document.
  final Color? bulletListIconColor;

  /// The color of the divider in a PDF document.
  final Color dividerColor;

  /// The thickness of the divider in a PDF document.
  /// The thickness of the divider line.
  ///
  /// This value determines how thick the divider line will be.
  final double dividerthickness;

  /// The background color of the code block.
  ///
  /// This color is used as the background for code blocks in the PDF.
  final Color codeBlockBackgroundColor;

  /// The color of the code block text.
  ///
  /// This color is used for the text within code blocks in the PDF.
  final Color codeblockColor;
  // The decoration style that will merge with default style
  final BoxDecoration? codeDecoration;

  /// The height of the divider in a PDF document.
  final double dividerHight;

  /// Enable browser-standard default styles (margins, padding, etc.)
  final bool useDefaultStyles;

  /// Custom default paragraph margin (overrides browser defaults if set)
  final EdgeInsets? paragraphMargin;

  /// Custom default heading margins by level (overrides browser defaults if set)
  final Map<int, EdgeInsets>? headingMargins;

  /// Custom default list margin (overrides browser defaults if set)
  final EdgeInsets? listMargin;

  /// Custom table cell padding (overrides browser defaults if set)
  final EdgeInsets? tableCellPadding;

  /// Custom table header cell padding (overrides browser defaults if set)
  final EdgeInsets? tableHeaderPadding;

  /// Size of the checkbox icon in points.
  final double checkboxSize;

  /// Color for the checked checkbox icon (used when rendering default or SVG).
  final Color? checkedIconColor;

  /// Color for the unchecked checkbox icon (used when rendering default or SVG).
  final Color? uncheckedIconColor;

  const HtmlTagStyle({
    this.boldStyle,
    this.italicStyle,
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.imageAlignment = Alignment.center,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.strikeThrough,
    this.paragraphStyle,
    this.codeStyle,
    this.headingStyle,
    this.listIndexStyle,
    this.linkStyle,
    this.quoteBarColor,
    this.bulletListIconColor,
    this.dividerHight = 0.5,
    this.codeBlockBackgroundColor = const Color(0xFFFFCC00),
    this.codeblockColor = const Color(0xFF9E9E9E),
    this.codeDecoration,
    this.dividerthickness = 1.0,
    this.dividerColor = const Color(0xFF9E9E9E),
    this.useDefaultStyles = true,
    this.paragraphMargin,
    this.headingMargins,
    this.listMargin,
    this.tableCellPadding,
    this.tableHeaderPadding,
    this.checkboxSize = 14.0,
    this.checkedIconColor,
    this.uncheckedIconColor,
  });
}
