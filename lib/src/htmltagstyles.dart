// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';

class HtmlTagStyle {
  final TextStyle? boldStyle;
  final TextStyle? italicStyle;
  final TextStyle? h1Style;
  final TextStyle? h2Style;
  final TextStyle? h3Style;
  final TextStyle? h4Style;
  final TextStyle? h5Style;
  final TextStyle? h6Style;
  final TextStyle? strikeThrough;
  final Alignment imageAlignment;
  final TextStyle? paragraphStyle;
  final TextStyle? codeStyle;
  final TextStyle? headingStyle;
  final TextStyle? listIndexStyle;
  final TextStyle? linkStyle;
  final PdfColor? quoteBarColor;
  final PdfColor? bulletListIconColor;
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
  });
}
