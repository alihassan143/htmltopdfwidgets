import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import '../../utils/image_resolver.dart';

/// Parses HTML image elements.
class HtmlImageParser {
  HtmlImageParser();

  /// Parse an image as a block-level element.
  Future<DocxNode?> parseBlockImage(dom.Element element) async {
    final src = element.attributes['src'];
    final alt = element.attributes['alt'];
    final widthStr = element.attributes['width'];
    final heightStr = element.attributes['height'];

    final width = _parseDimension(widthStr);
    final height = _parseDimension(heightStr);

    final result = await ImageResolver.resolve(
      src ?? '',
      width: width,
      height: height,
      alt: alt,
    );

    if (result != null) {
      return DocxImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
        align: DocxAlign.center,
      );
    }

    // Fallback placeholder
    return _parseImagePlaceholder(element);
  }

  /// Parse an image as an inline element.
  Future<DocxInlineImage?> parseInlineImage(dom.Element element) async {
    final src = element.attributes['src'];
    final alt = element.attributes['alt'];
    final widthStr = element.attributes['width'];
    final heightStr = element.attributes['height'];

    final width = _parseDimension(widthStr);
    final height = _parseDimension(heightStr);

    final result = await ImageResolver.resolve(
      src ?? '',
      width: width,
      height: height,
      alt: alt,
    );

    if (result != null) {
      return DocxInlineImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
      );
    }
    return null;
  }

  DocxNode? _parseImagePlaceholder(dom.Element element) {
    final src = element.attributes['src'];
    if (src == null || src.isEmpty) return null;
    final alt = element.attributes['alt'] ?? 'Image';
    return DocxParagraph(
      align: DocxAlign.center,
      children: [
        DocxText('[📷 '),
        DocxText.link(alt, href: src),
        DocxText(']'),
      ],
    );
  }

  double? _parseDimension(String? value) {
    if (value == null) return null;
    final cleaned =
        value.replaceAll(RegExp(r'px\s*$', caseSensitive: false), '').trim();
    return double.tryParse(cleaned);
  }
}
