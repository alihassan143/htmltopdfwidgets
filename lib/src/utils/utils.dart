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

bool isElementSublist(Element element) {

  if(element.localName != HTMLTags.listItem)
    return false;

  for(Element childElement in element.children)
    if(childElement.localName == HTMLTags.unorderedList ||
        childElement.localName == HTMLTags.orderedList)
      return true;

  return false;
}