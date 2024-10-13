import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;

Future<String?> readStringFromAssets(String path) async {
  try {
    String result = await rootBundle.loadString(path);
    return result;
  } catch (e) {
    return null;
  }
}

dom.Element? nearestParent(dom.Element element, List<String> tags){
  if(element.parent == null) return null;
  for(String tag in tags)
    if(element.parent!.localName == tag) return element.parent!;

  return nearestParent(element.parent!, tags);
}

bool hasInParent(dom.Element element, List<String> tags){
  if(element.parent == null) return false;
  for(String tag in tags)
    if(element.parent!.localName == tag) return true;

  return hasInParent(element.parent!, tags);
}

bool isNextElement(dom.Element element, List<String> tags){
  if(element.parent == null) return false;
  for(String tag in tags)
    if(element.parent!.localName == tag) return true;

  return false;
}