import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:http/http.dart';

import '../../htmltopdfwidgets.dart';

Future<Widget> parseImageElement(dom.Element element,
    {required HtmlTagStyle customStyles}) async {
  final src = element.attributes["src"];
  try {
    if (src != null) {
      if (src.startsWith("data:image/")) {
        // To handle a case if someone added a space after base64 string
        final List<String> components = src.split(",");

        if (components.length > 1) {
          var base64Encoded = components.last;
          Uint8List listData = base64Decode(base64Encoded);
          return Image(MemoryImage(listData),
              alignment: customStyles.imageAlignment);
        }
        return Text("");
      }
      if (src.startsWith("http") || src.startsWith("https")) {
        final netImage = await _saveImage(src);
        return Image(MemoryImage(netImage),
            alignment: customStyles.imageAlignment);
      }

      final localImage = File(src);
      if (await localImage.exists()) {
        return Image(MemoryImage(await localImage.readAsBytes()));
      }
    }
    return Text("");
  } catch (e) {
    return Text("");
  }
}

/// Function to download and save an image from a URL
Future<Uint8List> _saveImage(String url) async {
  try {
    /// Download image
    final Response response = await get(Uri.parse(url));

    /// Get temporary directory

    return response.bodyBytes;
  } catch (e) {
    throw Exception(e);
  }
}
