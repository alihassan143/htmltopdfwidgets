import 'dart:typed_data';

import 'package:uuid/uuid.dart'; // Add

import '../../docx_creator.dart';
import '../core/font_manager.dart'; // Add

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
  final List<EmbeddedFont> _fonts = [];
  DocxSectionDef? _currentSection;

  /// Sets section properties (headers, footers, page layout, background).
  DocxDocumentBuilder section({
    DocxPageOrientation orientation = DocxPageOrientation.portrait,
    DocxPageSize pageSize = DocxPageSize.letter,
    DocxHeader? header,
    DocxFooter? footer,
    DocxColor? backgroundColor,
    DocxBackgroundImage? backgroundImage,
  }) {
    _currentSection = DocxSectionDef(
      orientation: orientation,
      pageSize: pageSize,
      header: header,
      footer: footer,
      backgroundColor: backgroundColor,
      backgroundImage: backgroundImage,
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
  DocxDocumentBuilder p(
    String text, {
    DocxAlign align = DocxAlign.left,
    DocxBorder? borderBottom,
  }) {
    _elements.add(DocxParagraph.text(
      text,
      align: align,
      borderBottom: borderBottom,
    ));
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

  /// Adds a section break, defining properties for the *preceding* section.
  ///
  /// ```dart
  /// .addParagraph('Page 1 Content (Portrait)')
  /// .addSectionBreak(DocxSectionDef(orientation: DocxPageOrientation.portrait))
  /// .addParagraph('Page 2 Content (Landscape)')
  /// ```
  DocxDocumentBuilder addSectionBreak(DocxSectionDef section) {
    _elements.add(DocxSectionBreakBlock(section));
    return this;
  }

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

  /// Adds a custom font to the document.
  DocxDocumentBuilder addFont(String familyName, Uint8List bytes) {
    // Check if duplicate?
    if (!_fonts.any((f) => f.familyName == familyName)) {
      _fonts.add(EmbeddedFont(
        familyName: familyName,
        bytes: bytes,
        obfuscationKey: const Uuid().v4(),
      ));
    }
    return this;
  }

  final List<DocxFootnote> _footnotes = [];
  final List<DocxEndnote> _endnotes = [];

  /// Adds a footnote to the document.
  ///
  /// You should reference this footnote in your text using [DocxFootnoteRef].
  DocxDocumentBuilder addFootnote(DocxFootnote note) {
    _footnotes.add(note);
    return this;
  }

  /// Adds an endnote to the document.
  ///
  /// You should reference this endnote in your text using [DocxEndnoteRef].
  DocxDocumentBuilder addEndnote(DocxEndnote note) {
    _endnotes.add(note);
    return this;
  }

  /// Builds the final document.
  DocxBuiltDocument build() {
    return DocxBuiltDocument(
      elements: List.unmodifiable(_elements),
      section: _currentSection,
      fonts: List.unmodifiable(_fonts),
      footnotes: _footnotes.isNotEmpty ? List.unmodifiable(_footnotes) : null,
      endnotes: _endnotes.isNotEmpty ? List.unmodifiable(_endnotes) : null,
    );
  }
}

/// A built document ready for export.
class DocxBuiltDocument {
  final List<DocxNode> elements;
  final DocxSectionDef? section;
  final List<EmbeddedFont> fonts;
  final List<DocxFootnote>? footnotes;
  final List<DocxEndnote>? endnotes;

  // Raw XML content preserved from original document (for round-tripping)
  final String? stylesXml;
  final String? numberingXml;
  final String? settingsXml;
  final String? fontTableXml;
  final String? themeXml;
  final String? contentTypesXml;
  final String? rootRelsXml;
  final String? headerBgXml;
  final String? headerBgRelsXml;
  final String? footnotesXml;
  final String? endnotesXml;

  /// Parsed theme information (styles, colors, fonts).
  ///
  /// This is populated when reading an existing document with [DocxReader].
  /// It provides access to theme colors, fonts, and named styles.
  final DocxTheme? theme;

  const DocxBuiltDocument({
    required this.elements,
    this.section,
    this.stylesXml,
    this.numberingXml,
    this.settingsXml,
    this.fontTableXml,
    this.themeXml,
    this.contentTypesXml,
    this.rootRelsXml,
    this.headerBgXml,
    this.headerBgRelsXml,
    this.footnotesXml,
    this.endnotesXml,
    this.fonts = const [],
    this.footnotes,
    this.endnotes,
    this.theme,
  });
}

/// Shorthand alias for [DocxDocumentBuilder].
///
/// ```dart
/// final doc = Docx().h1('Title').p('Content').build();
/// ```
DocxDocumentBuilder docx() => DocxDocumentBuilder();
