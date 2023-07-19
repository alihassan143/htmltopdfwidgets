import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

class HTMLToPdf extends HtmlCodec {
  @override
  Future<List<Widget>> convert(String html,
      {List<Font> fontFallback = const [],
      Font? defaultFont,
      HtmlTagStyle tagStyle = const HtmlTagStyle()}) async {
    final widgetDecoder = WidgetsHTMLDecoder(
        fontFallback: [...fontFallback],
        font: defaultFont,
        customStyles: tagStyle);
    return await widgetDecoder.convert(html);
  }
}

abstract class HtmlCodec {
  Future<List<Widget>> convert(String html,
      {List<Font> fontFallback = const [],
      Font? defaultFont,
      HtmlTagStyle tagStyle = const HtmlTagStyle()});
}
