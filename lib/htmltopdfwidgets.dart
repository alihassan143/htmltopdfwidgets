library htmltopdfwidgets;

/// A Calculator.
import 'dart:collection';
import 'dart:ui';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import 'attributes.dart';

class HTMLTag {
  static const h1 = "h1";
  static const h2 = "h2";
  static const h3 = "h3";
  static const orderedList = "ol";
  static const unorderedList = "ul";
  static const list = "li";
  static const paragraph = "p";
  static const image = "img";
  static const anchor = "a";
  static const italic = "i";
  static const em = "em";
  static const bold = "b";
  static const underline = "u";
  static const del = "del";
  static const strong = "strong";
  static const span = "span";
  static const code = "code";
  static const blockQuote = "blockquote";
  static const div = "div";
  static const divider = "hr";

  static bool isTopLevel(String tag) {
    return tag == h1 ||
        tag == h2 ||
        tag == h3 ||
        tag == paragraph ||
        tag == div ||
        tag == blockQuote;
  }
}

/// Converting the HTML to nodes
class HtmlToPdfWidgets {
  final html.Document _document;

  /// This flag is used for parsing HTML pasting from Google Docs
  /// Google docs wraps the the content inside the `<b></b>` tag. It's strange.
  ///
  /// If a `<b>` element is parsing in the <p>, we regard it as as text spans.
  /// Otherwise, it's parsed as a container.
  bool _inParagraph = false;

  HtmlToPdfWidgets(String htmlString) : _document = parse(htmlString);

  Future<List<Widget>> toNodes() async {
    final childNodes = _document.body?.nodes.toList() ?? <html.Node>[];
    return await _handleContainer(childNodes);
  }

  Future<List<Widget>> _handleContainer(List<html.Node> childNodes) async {
    List<TextSpan> delta = [];
    final result = <Widget>[];
    for (final child in childNodes) {
      if (child is html.Element) {
        if (child.localName == HTMLTag.anchor ||
            child.localName == HTMLTag.span ||
            child.localName == HTMLTag.code ||
            child.localName == HTMLTag.strong ||
            child.localName == HTMLTag.underline ||
            child.localName == HTMLTag.italic ||
            child.localName == HTMLTag.em ||
            child.localName == HTMLTag.del) {
          _handleRichTextElement(delta, child);
        } else if (child.localName == HTMLTag.bold) {
          // Google docs wraps the the content inside the `<b></b>` tag.
          // It's strange
          if (!_inParagraph) {
            result.addAll(await _handleBTag(child));
          } else {
            result.add(await _handleRichText(child));
          }
        } else if (child.localName == HTMLTag.blockQuote) {
          result.addAll(await _handleBlockQuote(child));
        } else {
          result.addAll(await _handleElement(child));
        }
      } else {
        delta.add(TextSpan(text: child.text ?? ""));
      }
    }
    if (delta.isNotEmpty) {
      result.add(RichText(text: TextSpan(children: delta)));
    }
    return result;
  }

  Future<List<Widget>> _handleBlockQuote(html.Element element) async {
    final result = <Widget>[];

    for (final child in element.nodes.toList()) {
      if (child is html.Element) {
        result.addAll(await _handleElement(
            child, {"subtype": BuiltInAttributeKey.quote}));
      }
    }

    return result;
  }

  Future<List<Widget>> _handleBTag(html.Element element) async {
    final childNodes = element.nodes;
    return await _handleContainer(childNodes);
  }

  Future<List<Widget>> _handleElement(html.Element element,
      [Map<String, dynamic>? attributes]) async {
    if (element.localName == HTMLTag.h1) {
      return [_handleHeadingElement(element, HTMLTag.h1)];
    } else if (element.localName == HTMLTag.h2) {
      return [_handleHeadingElement(element, HTMLTag.h2)];
    } else if (element.localName == HTMLTag.h3) {
      return [_handleHeadingElement(element, HTMLTag.h3)];
    } else if (element.localName == HTMLTag.unorderedList) {
      return _handleUnorderedList(element);
    } else if (element.localName == HTMLTag.orderedList) {
      return _handleOrderedList(element);
    } else if (element.localName == HTMLTag.list) {
      return _handleListElement(element);
    } else if (element.localName == HTMLTag.paragraph) {
      return [await _handleParagraph(element, attributes)];
    } else if (element.localName == HTMLTag.image) {
      return [await _handleImage(element)];
    } else if (element.localName == HTMLTag.divider) {
      return [_handleDivider()];
    } else {
      final delta = <TextSpan>[];
      delta.add(TextSpan(text: element.text));
      if (delta.isNotEmpty) {
        return [RichText(text: TextSpan(children: delta))];
      }
    }

    return [];
  }

  Future<Widget> _handleParagraph(html.Element element,
      [Map<String, dynamic>? attributes]) async {
    _inParagraph = true;
    final node = await _handleRichText(element, attributes);
    _inParagraph = false;
    return node;
  }

  Widget _handleDivider() => Divider();

  Map<String, String> _cssStringToMap(String? cssString) {
    final result = <String, String>{};
    if (cssString == null) {
      return result;
    }

    final entries = cssString.split(";");
    for (final entry in entries) {
      final tuples = entry.split(":");
      if (tuples.length < 2) {
        continue;
      }
      result[tuples[0].trim()] = tuples[1].trim();
    }

    return result;
  }

  TextStyle? _getDeltaAttributesFromHtmlAttributes(
      LinkedHashMap<Object, String> htmlAttributes) {
    var style = const TextStyle();
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);

    final fontWeightStr = cssMap["font-weight"];
    if (fontWeightStr != null) {
      if (fontWeightStr == "bold") {
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else {
        int? weight = int.tryParse(fontWeightStr);
        if (weight != null && weight > 500) {
          style = style.copyWith(fontWeight: FontWeight.bold);
        }
      }
    }

    final textDecorationStr = cssMap["text-decoration"];
    if (textDecorationStr != null) {
      _assignTextDecorations(style, textDecorationStr);
    }

    final backgroundColorStr = cssMap["background-color"];
    final backgroundColor = backgroundColorStr == null
        ? null
        : ColorExtension.tryFromRgbaString(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(color: PdfColor.fromInt(backgroundColor.value));
      // attrs[BuiltInAttributeKey.backgroundColor] =
      //     '0x${backgroundColor.value.toRadixString(16)}';
    }

    if (cssMap["font-style"] == "italic") {
      style = style.copyWith(fontStyle: FontStyle.italic);
      // attrs[BuiltInAttributeKey.italic] = true;
    }

    return style;
  }

  _assignTextDecorations(TextStyle style, String decorationStr) {
    final decorations = decorationStr.split(" ");
    for (final d in decorations) {
      if (d == "line-through") {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
        // attrs[BuiltInAttributeKey.strike] = true;
      } else if (d == "underline") {
        style = style.copyWith(decoration: TextDecoration.underline);
      }
    }
  }

  _handleRichTextElement(List<TextSpan> delta, html.Element element) {
    if (element.localName == HTMLTag.span) {
      delta.add(TextSpan(
        text: element.text,
        style: _getDeltaAttributesFromHtmlAttributes(element.attributes),
      ));
    } else if (element.localName == HTMLTag.anchor) {
      final hyperLink = element.attributes["href"];
      Map<String, dynamic>? attributes;
      if (hyperLink != null) {
        attributes = {"href": hyperLink};
      }
      delta.add(TextSpan(
        text: element.text,
        style: _getDeltaAttributesFromHtmlAttributes(element.attributes),
      ));
    } else if (element.localName == HTMLTag.strong ||
        element.localName == HTMLTag.bold) {
      delta.add(TextSpan(
        text: element.text,
        style: TextStyle(fontWeight: FontWeight.bold),
      ));
    } else if (element.localName == HTMLTag.underline) {
      delta.add(TextSpan(
        text: element.text,
        style: const TextStyle(decoration: TextDecoration.underline),
      ));
    } else if ([HTMLTag.italic, HTMLTag.em].contains(element.localName)) {
      delta.add(TextSpan(
        text: element.text,
        style: TextStyle(fontStyle: FontStyle.italic),
      ));
    } else if (element.localName == HTMLTag.del) {
      delta.add(TextSpan(
        text: element.text,
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ));
    } else {
      delta.add(TextSpan(
        text: element.text,
      ));
    }
  }

  /// A container contains a <input type="checkbox" > will
  /// be regarded as a checkbox block.
  ///
  /// A container contains a <img /> will be regarded as a image block
  Future<Widget> _handleRichText(html.Element element,
      [Map<String, dynamic>? attributes]) async {
    final image = element.querySelector(HTMLTag.image);
    if (image != null) {
      final imageNode = await _handleImage(image);
      return imageNode;
    }
    final testInput = element.querySelector("input");
    bool checked = false;
    final isCheckbox =
        testInput != null && testInput.attributes["type"] == "checkbox";
    if (isCheckbox) {
      checked = testInput.attributes.containsKey("checked") &&
          testInput.attributes["checked"] != "false";
    }

    final delta = <TextSpan>[];

    for (final child in element.nodes.toList()) {
      if (child is html.Element) {
        _handleRichTextElement(delta, child);
      } else {
        delta.add(TextSpan(text: child.text ?? ""));
      }
    }

    final textNode = RichText(text: TextSpan(children: delta));
    return textNode;
  }

  Future<Widget> _handleImage(html.Element element) async {
    final src = element.attributes["src"];
    final attributes = <String, dynamic>{};
    if (src != null) {
      attributes["image_src"] = src;
    }
    final netImage = await networkImage('https://www.nfet.net/nfet.jpg');
    return Image(netImage);
  }

  Future<List<Widget>> _handleUnorderedList(html.Element element) async {
    final result = <Widget>[];
    for (var child in element.children) {
      result.addAll(await _handleListElement(
        child,
        {"subtype": BuiltInAttributeKey.bulletedList},
      ));
    }
    return result;
  }

  Future<List<Widget>> _handleOrderedList(html.Element element) async {
    final result = <Widget>[];
    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      result.addAll(await _handleListElement(
          child, {"subtype": BuiltInAttributeKey.numberList, "number": i + 1}));
    }
    return result;
  }

  Text _handleHeadingElement(
    html.Element element,
    String headingStyle,
  ) {
    return Text(element.text,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Future<List<Widget>> _handleListElement(html.Element element,
      [Map<String, dynamic>? attributes]) async {
    final result = <Widget>[];
    final childNodes = element.nodes.toList();
    for (final child in childNodes) {
      if (child is html.Element) {
        result.addAll(await _handleElement(child, attributes));
      }
    }
    return result;
  }
}

String stringify(html.Node node) {
  if (node is html.Element) {
    return node.outerHtml;
  }

  if (node is html.Text) {
    return node.text;
  }

  return "";
}

extension ColorExtension on Color {
  /// Try to parse the `rgba(red, greed, blue, alpha)`
  /// from the string.
  static Color? tryFromRgbaString(String colorString) {
    final reg = RegExp(r'rgba\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
    final match = reg.firstMatch(colorString);
    if (match == null) {
      return null;
    }

    if (match.groupCount < 4) {
      return null;
    }
    final redStr = match.group(1);
    final greenStr = match.group(2);
    final blueStr = match.group(3);
    final alphaStr = match.group(4);

    final red = redStr != null ? int.tryParse(redStr) : null;
    final green = greenStr != null ? int.tryParse(greenStr) : null;
    final blue = blueStr != null ? int.tryParse(blueStr) : null;
    final alpha = alphaStr != null ? int.tryParse(alphaStr) : null;

    if (red == null || green == null || blue == null || alpha == null) {
      return null;
    }

    return Color.fromARGB(alpha, red, green, blue);
  }

  String toRgbaString() {
    return 'rgba($red, $green, $blue, $alpha)';
  }
}
