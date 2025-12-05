import 'css_style.dart';

class RenderNode {
  final String tagName;
  final CSSStyle style;
  final String? text;
  final Map<String, String> attributes;
  final List<RenderNode> children;

  RenderNode({
    required this.tagName,
    required this.style,
    this.text,
    this.attributes = const {},
    List<RenderNode>? children,
  }) : children = children ?? [];

  Display get display {
    if (style.display != null) return style.display!;
    return _getDefaultDisplay(tagName);
  }

  static Display _getDefaultDisplay(String tagName) {
    const blockTags = {
      'div',
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'ul',
      'ol',
      'li',
      'blockquote',
      'table',
      'tr',
      'header',
      'footer',
      'section',
      'article'
    };
    if (blockTags.contains(tagName.toLowerCase())) {
      return Display.block;
    }
    return Display.inline;
  }

  @override
  String toString() {
    return 'RenderNode(tag: $tagName, display: $display, text: $text, children: ${children.length})';
  }
}
