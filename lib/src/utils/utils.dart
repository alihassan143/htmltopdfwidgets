import 'package:flutter/services.dart';
import 'package:html/dom.dart';

import '../html_tags.dart';

Future<String?> readStringFromAssets(String path) async {
  try {
    String result = await rootBundle.loadString(path);
    return result;
  } catch (e) {
    return null;
  }
}
