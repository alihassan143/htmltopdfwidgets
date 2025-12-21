import 'package:xml/xml.dart';

export 'docx_raw_xml.dart';

/// Abstract base class for all nodes in the document AST.
///
/// The AST (Abstract Syntax Tree) represents the document structure
/// in a format-agnostic way, allowing export to multiple formats
/// (DOCX, HTML, PDF, etc.).
///
/// ## Node Hierarchy
/// ```
/// DocxNode (base)
/// ├── DocxInline (inline content like text, images)
/// │   ├── DocxText
/// │   ├── DocxLineBreak
/// │   └── DocxInlineImage
/// ├── DocxBlock (block-level content)
/// │   ├── DocxParagraph
/// │   ├── DocxTable
/// │   ├── DocxImage
/// │   └── DocxList
/// └── DocxSection (page sections with headers/footers)
/// ```
abstract class DocxNode {
  /// Unique identifier for this node (for debugging/tracking).
  final String? id;

  const DocxNode({this.id});

  /// Accepts a visitor for traversing the AST.
  ///
  /// Implement the Visitor pattern for format-agnostic export.
  void accept(DocxVisitor visitor);

  /// Converts this node to its XML representation.
  ///
  /// Used by [DocxExporter] to generate OOXML content.
  void buildXml(XmlBuilder builder);
}

/// Visitor interface for traversing the document AST.
///
/// Implement this to create custom exporters or processors.
///
/// ```dart
/// class HtmlVisitor implements DocxVisitor {
///   final StringBuffer _buffer = StringBuffer();
///
///   @override
///   void visitText(DocxText text) {
///     _buffer.write('<span>${text.content}</span>');
///   }
///   // ... other visit methods
/// }
/// ```
abstract class DocxVisitor {
  void visitText(covariant DocxInline text);
  void visitParagraph(covariant DocxBlock paragraph);
  void visitTable(covariant DocxBlock table);
  void visitTableRow(covariant DocxNode row);
  void visitTableCell(covariant DocxNode cell);
  void visitImage(covariant DocxNode image);
  void visitSection(covariant DocxNode section);
  void visitHeader(covariant DocxNode header);
  void visitFooter(covariant DocxNode footer);
  void visitRawXml(covariant DocxNode rawXml);
  void visitRawInline(covariant DocxNode rawInline);
  void visitShape(covariant DocxInline shape);
  void visitShapeBlock(covariant DocxBlock shapeBlock);
}

/// Base class for inline elements (text, inline images, etc.).
///
/// Inline elements flow with the surrounding content and do not
/// start on a new line.
abstract class DocxInline extends DocxNode {
  const DocxInline({super.id});
}

/// Base class for block-level elements (paragraphs, tables, etc.).
///
/// Block elements start on a new line and take up the full width
/// of their container.
abstract class DocxBlock extends DocxNode {
  const DocxBlock({super.id});
}

/// Base class for section elements (page layout, headers, footers).
///
/// Sections define page properties like orientation, margins,
/// and recurring content (headers/footers).
abstract class DocxSection extends DocxNode {
  const DocxSection({super.id});
}
