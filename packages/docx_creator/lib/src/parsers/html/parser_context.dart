import 'package:html/dom.dart' as dom;

/// Shared context for all HTML parser modules.
///
/// Holds the CSS class map and provides access to parsed styles.
class HtmlParserContext {
  /// CSS class map (className -> styleBody)
  final Map<String, String> cssMap;

  /// The parsed HTML document
  final dom.Document document;

  HtmlParserContext({
    required this.document,
    Map<String, String>? cssMap,
  }) : cssMap = cssMap ?? {};

  /// Create context from an HTML document, automatically parsing CSS classes.
  factory HtmlParserContext.fromDocument(dom.Document document) {
    final cssMap = _parseCssClasses(document);
    return HtmlParserContext(document: document, cssMap: cssMap);
  }

  /// Parse CSS classes from <style> tags in the document.
  static Map<String, String> _parseCssClasses(dom.Document document) {
    final cssMap = <String, String>{};
    final styles = document.querySelectorAll('style');
    for (var style in styles) {
      final text = style.text;
      // Simple regex for .className { ... }
      final matches =
          RegExp(r'\.([a-zA-Z0-9_-]+)\s*\{([^}]+)\}').allMatches(text);
      for (var match in matches) {
        final className = match.group(1);
        final styleBody = match.group(2);
        if (className != null && styleBody != null) {
          cssMap[className] = styleBody.trim();
        }
      }
    }
    return cssMap;
  }

  /// Merge inline styles with CSS class styles.
  /// Inline styles take precedence over class styles.
  String mergeStyles(String? inlineStyle, Iterable<String> classes) {
    var combined = inlineStyle ?? '';
    if (classes.isNotEmpty) {
      for (var cls in classes) {
        if (cssMap.containsKey(cls)) {
          combined = '$combined;${cssMap[cls]}';
        }
      }
    }
    return combined;
  }
}
