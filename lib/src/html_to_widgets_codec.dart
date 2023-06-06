import 'dart:convert';

import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

List<Widget> htmlToWidgets(String html) {
  return WidgetsHTMLDecoder().convert(html);
}

class HTMLToPdfCodec extends Codec<List<Widget>, String> {
  const HTMLToPdfCodec();

  @override
  Converter<String, List<Widget>> get decoder => WidgetsHTMLDecoder();

  @override
  // TODO: implement encoder
  Converter<List<Widget>, String> get encoder => throw UnimplementedError();
}
