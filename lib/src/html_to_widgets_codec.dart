import 'dart:async';

import '../htmltopdfwidgets.dart';
import 'html_to_widgets.dart';

class HTMLToPdf {

  Future<List<Widget>> convert(
      String html,
      { List<Font> fontFallback = const [],
        FutureOr<Font> Function(String, bool, bool)? fontResolver,
        String defaultFontFamily = "Roboto",
        double defaultFontSize = 12.0,
        HtmlTagStyle tagStyle = const HtmlTagStyle()
      }) async {

    final widgetDecoder = WidgetsHTMLDecoder(
        fontFallback: [...fontFallback],
        fontResolver: fontResolver,
        defaultFontFamily: defaultFontFamily,
        defaultFontSize: defaultFontSize,
        customStyles: tagStyle
    );
    return await widgetDecoder.convert(html);
  }
}
