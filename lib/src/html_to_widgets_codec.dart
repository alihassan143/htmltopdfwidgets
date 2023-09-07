import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

// Define a class named HTMLToPdf that extends HtmlCodec. and it contains the converter that convert html string to pdf widgets
class HTMLToPdf extends HtmlCodec {
  // Override the convert method from HtmlCodec.
  @override
  Future<List<Widget>> convert(
      //html string that need to be converted
      String html,
      {
      //font fall back
      List<Font> fontFallback = const [],
      //default font the html string converted widgets
      Font? defaultFont,
      //custom html tag styles
      HtmlTagStyle tagStyle = const HtmlTagStyle()}) async {
    //decode that handle all html tags logic
    final widgetDecoder = WidgetsHTMLDecoder(
        //font fall back if privided
        fontFallback: [...fontFallback],
        //default font for the tags
        font: defaultFont,
        //custom html tags style
        customStyles: tagStyle);
    //convert function that convert string to dom nodes that that dom nodes will be converted
    return await widgetDecoder.convert(html);
  }
}

// Define an abstract class named HtmlCodec.
abstract class HtmlCodec {
  //this code defines a class HTMLToPdf that inherits from HtmlCodec
  // and overrides the convert method to convert HTML content into
  // a list of pdf widgets using the WidgetsHTMLDecoder class.
  // It also defines an abstract class HtmlCodec with an abstract method convert
  // that must be implemented by its subclasses. The code is structured for
  //handling HTML-to-pdf-widget conversion in a dart or flutter application
  Future<List<Widget>> convert(String html,
      {List<Font> fontFallback = const [],
      Font? defaultFont,
      HtmlTagStyle tagStyle = const HtmlTagStyle()});
}
