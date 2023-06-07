import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

class HTMLToPdf extends HtmlCodec {
  @override
  Future<List<Widget>> convert(String html) async {
    return await WidgetsHTMLDecoder.convert(html);
  }
}

abstract class HtmlCodec {
  Future<List<Widget>> convert(String html);
}
