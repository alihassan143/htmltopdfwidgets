import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

class HTMLToPdf extends HtmlCodec {
  @override
  Future<List<Widget>> convert(String html,
      {List<Font>? fontFallback, Font? defaultFont}) async {
    final widgetDecoder =
        WidgetsHTMLDecoder(fontFallback: fontFallback ?? [], font: defaultFont);
    return await widgetDecoder.convert(html);
  }
}

abstract class HtmlCodec {
  Future<List<Widget>> convert(String html,
      {List<Font>? fontFallback, Font? defaultFont});
}
