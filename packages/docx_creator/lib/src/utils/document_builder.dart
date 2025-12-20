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
        return DocxParagraph.heading1(textContent ?? '');
      case 'h2':
        return DocxParagraph.heading2(textContent ?? '');
      case 'h3':
        return DocxParagraph.heading3(textContent ?? '');
      case 'h4':
        return DocxParagraph.heading4(textContent ?? '');
      case 'h5':
        return DocxParagraph.heading5(textContent ?? '');
      case 'h6':
        return DocxParagraph.heading6(textContent ?? '');

      case 'p':
      case 'div':
        return DocxParagraph(
          children: children.whereType<DocxInline>().toList(),
        );

      case 'blockquote':
        return DocxParagraph.quote(textContent ?? '');

      case 'pre':
        return DocxParagraph.code(textContent ?? '');

      case 'hr':
        return DocxParagraph(borderBottom: DocxBorder.single, children: []);
    }
    return null;
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
