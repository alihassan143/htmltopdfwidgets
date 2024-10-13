// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';

//apply custom styles to html stylee
class HtmlTagStyle {
  //bold  style that will merge with default style
  final TextStyle? boldStyle;
  //italic style that will merge with default style
  final TextStyle? italicStyle;
  //bold and italic style that will merge with default style
  final TextStyle? boldItalicStyle;
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
  //heading style that will merge with default style
  final TextStyle? headingStyle;
  //list index style that will merge with default style
  final TextStyle? listIndexStyle;
  //href link style that will merge with default style
  final TextStyle? linkStyle;
  //quote bar style that will merge with default style
  final PdfColor? quoteBarColor;
  //bullet list style that will merge with default style
  final double listTopPadding;
  //bullet list style that will merge with default style
  final double listBottomPadding;
  //bullet list style that will merge with default style
  final PdfColor? bulletListIconColor;
  //bullet list style that will merge with default style
  final double bulletListDotSize;
  //bullet list style that will merge with default style
  final double bulletListIconSize;
  //bullet list style that will merge with default style
  final EdgeInsets listItemIndicatorPadding;
  //bullet list style that will merge with default style
  final double listItemIndicatorWidth;
  //bullet list style that will merge with default style
  final double listItemVerticalSeparatorSize;
  //bullet list style that will merge with default style
  final double headingTopSpacing;
  //bullet list style that will merge with default style
  final double headingBottomSpacing;
  //bullet list style that will merge with default style
  final EdgeInsets tablePadding;

  const HtmlTagStyle({
    this.boldStyle,
    this.italicStyle,
    this.boldItalicStyle,
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
    this.listTopPadding = 6.0,
    this.listBottomPadding = 6.0,
    this.bulletListIconColor,
    this.bulletListDotSize = 5.0,
    this.bulletListIconSize = 14.0,
    this.listItemIndicatorPadding = const EdgeInsets.only(right: 12.0),
    this.listItemIndicatorWidth = 24.0,
    this.listItemVerticalSeparatorSize = 6.0,
    this.headingTopSpacing = 12.0,
    this.headingBottomSpacing = 18.0,
    this.tablePadding = const EdgeInsets.all(6.0),
  });
}
