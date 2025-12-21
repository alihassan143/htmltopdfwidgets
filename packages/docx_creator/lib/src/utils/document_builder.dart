import '../ast/docx_block.dart';
import '../ast/docx_inline.dart';
import '../ast/docx_node.dart';
import '../core/enums.dart';

/// Common Element Builder for normalizing AST creation from various parsers (HTML/Markdown).
class DocumentBuilder {
  DocumentBuilder._();

  /// Builds a block element based on tag name.
  static DocxNode? buildBlockElement({
    required String tag,
    required List<DocxNode> children,
    Map<String, String>? attributes,
    String? textContent,
  }) {
    switch (tag.toLowerCase()) {
      case 'h1':
        return _buildHeading('Heading1', children, textContent);
      case 'h2':
        return _buildHeading('Heading2', children, textContent);
      case 'h3':
        return _buildHeading('Heading3', children, textContent);
      case 'h4':
        return _buildHeading('Heading4', children, textContent);
      case 'h5':
        return _buildHeading('Heading5', children, textContent);
      case 'h6':
        return _buildHeading('Heading6', children, textContent);

      case 'p':
      case 'div':
        return DocxParagraph(
          children: children.whereType<DocxInline>().toList(),
        );

      case 'blockquote':
        return DocxParagraph(
          styleId: 'Quote',
          indentLeft: 720,
          children: children.isNotEmpty
              ? children.whereType<DocxInline>().toList()
              : [DocxText.italic(textContent ?? '')],
        );

      case 'pre':
        return DocxParagraph.code(textContent ?? '');

      case 'hr':
        return DocxParagraph(borderBottom: DocxBorder.single, children: []);
    }
    return null;
  }

  static DocxParagraph _buildHeading(
      String styleId, List<DocxNode> children, String? textContent) {
    if (children.isNotEmpty) {
      return DocxParagraph(
        styleId: styleId,
        children: children.whereType<DocxInline>().toList(),
      );
    }
    return DocxParagraph(
      styleId: styleId,
      children: [DocxText(textContent ?? '')],
    );
  }

  /// Builds a checkbox (Common logic for input type=checkbox and [ ]/[x])
  static DocxCheckbox buildCheckbox({
    bool isChecked = false,
    double? fontSize,
    DocxFontWeight fontWeight = DocxFontWeight.normal,
    DocxFontStyle fontStyle = DocxFontStyle.normal,
    DocxColor? color,
  }) {
    return DocxCheckbox(
      isChecked: isChecked,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
    );
  }

  /// Builds an image element
  // Logic for images is often parser-specific regarding fetching,
  // but builder can standarize the Node creation if needed.
}
