import '../ast/docx_block.dart';
import '../ast/docx_image.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../ast/docx_section.dart';
import '../ast/docx_table.dart';
import '../core/enums.dart';

/// Fluent builder for creating DOCX documents.
///
/// ## Simple API Example
/// ```dart
/// final doc = Docx()
///   .h1('Title')
///   .p('Some text with **bold** and *italic*.')
///   .bullet(['Item 1', 'Item 2', 'Item 3'])
///   .table([['A', 'B'], ['1', '2']])
///   .build();
///
/// await doc.save('output.docx');
/// ```
class DocxDocumentBuilder {
  final List<DocxNode> _elements = [];
  DocxSectionDef? _currentSection;

  /// Sets section properties (headers, footers, page layout, background).
  DocxDocumentBuilder section({
    DocxPageOrientation orientation = DocxPageOrientation.portrait,
    DocxPageSize pageSize = DocxPageSize.letter,
    DocxHeader? header,
    DocxFooter? footer,
    DocxColor? backgroundColor,
  }) {
    _currentSection = DocxSectionDef(
      orientation: orientation,
      pageSize: pageSize,
      header: header,
      footer: footer,
      backgroundColor: backgroundColor,
    );
    return this;
  }

  // ============================================================
  // SIMPLE API (Short method names)
  // ============================================================

  /// Adds a heading level 1.
  DocxDocumentBuilder h1(String text) => heading1(text);

  /// Adds a heading level 2.
  DocxDocumentBuilder h2(String text) => heading2(text);

  /// Adds a heading level 3.
  DocxDocumentBuilder h3(String text) => heading3(text);

  /// Adds a paragraph with plain text.
  DocxDocumentBuilder p(String text, {DocxAlign align = DocxAlign.left}) {
    _elements.add(DocxParagraph.text(text, align: align));
    return this;
  }

  /// Adds a bulleted list.
  DocxDocumentBuilder bullet(List<String> items) {
    _elements.add(DocxList.bullet(items));
    return this;
  }

  /// Adds a numbered list.
  DocxDocumentBuilder numbered(List<String> items) {
    _elements.add(DocxList.numbered(items));
    return this;
  }

  /// Adds a table from 2D data.
  DocxDocumentBuilder table(
    List<List<String>> data, {
    bool hasHeader = true,
    DocxTableStyle style = const DocxTableStyle(),
  }) {
    _elements.add(DocxTable.fromData(data, hasHeader: hasHeader, style: style));
    return this;
  }

  /// Adds a page break.
  DocxDocumentBuilder pageBreak() {
    _elements.add(DocxParagraph(pageBreakBefore: true, children: []));
    return this;
  }

  /// Adds a horizontal rule / divider.
  DocxDocumentBuilder hr() {
    _elements.add(DocxParagraph(borderBottom: DocxBorder.single, children: []));
    return this;
  }

  /// Adds a divider (alias for hr).
  DocxDocumentBuilder divider() => hr();

  /// Adds a blockquote.
  DocxDocumentBuilder quote(String text) {
    _elements.add(DocxParagraph.quote(text));
    return this;
  }

  /// Adds a code block.
  DocxDocumentBuilder code(String code) {
    _elements.add(DocxParagraph.code(code));
    return this;
  }

  // ============================================================
  // FULL API (Descriptive method names)
  // ============================================================

  /// Adds a paragraph element.
  DocxDocumentBuilder paragraph(DocxParagraph paragraph) {
    _elements.add(paragraph);
    return this;
  }

  /// Adds simple text as a paragraph.
  DocxDocumentBuilder text(String content, {DocxAlign align = DocxAlign.left}) {
    _elements.add(DocxParagraph.text(content, align: align));
    return this;
  }

  /// Adds a heading level 1.
  DocxDocumentBuilder heading1(String text) {
    _elements.add(DocxParagraph.heading1(text));
    return this;
  }

  /// Adds a heading level 2.
  DocxDocumentBuilder heading2(String text) {
    _elements.add(DocxParagraph.heading2(text));
    return this;
  }

  /// Adds a heading level 3.
  DocxDocumentBuilder heading3(String text) {
    _elements.add(DocxParagraph.heading3(text));
    return this;
  }

  /// Adds a heading at specified level.
  DocxDocumentBuilder heading(DocxHeadingLevel level, String text) {
    _elements.add(DocxParagraph.heading(level, text));
    return this;
  }

  /// Adds a custom table.
  DocxDocumentBuilder addTable(DocxTable table) {
    _elements.add(table);
    return this;
  }

  /// Adds a custom list.
  DocxDocumentBuilder addList(DocxList list) {
    _elements.add(list);
    return this;
  }

  /// Adds an image.
  DocxDocumentBuilder image(DocxImage image) {
    _elements.add(image);
    return this;
  }

  /// Adds any DocxNode element.
  DocxDocumentBuilder add(DocxNode node) {
    _elements.add(node);
    return this;
  }

  /// Builds the final document.
  DocxBuiltDocument build() {
    return DocxBuiltDocument(
      elements: List.unmodifiable(_elements),
      section: _currentSection,
    );
  }
}

/// A built document ready for export.
class DocxBuiltDocument {
  final List<DocxNode> elements;
  final DocxSectionDef? section;

  const DocxBuiltDocument({required this.elements, this.section});
}

/// Shorthand alias for [DocxDocumentBuilder].
///
/// ```dart
/// final doc = Docx().h1('Title').p('Content').build();
/// ```
DocxDocumentBuilder docx() => DocxDocumentBuilder();
