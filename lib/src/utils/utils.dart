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

bool hasPreviousElement(dom.Element element) => element.previousElementSibling != null;

bool isPreviousElement(dom.Element element, List<String> tags){
  if(!hasPreviousElement(element)) return false;
  for(String tag in tags)
    if(element.previousElementSibling!.localName == tag) return true;

  return false;
}

bool hasNextElement(dom.Element element) => element.nextElementSibling != null;

bool isNextElement(dom.Element element, List<String> tags){
  if(!hasNextElement(element)) return false;
  for(String tag in tags)
    if(element.nextElementSibling!.localName == tag) return true;

  return false;
}