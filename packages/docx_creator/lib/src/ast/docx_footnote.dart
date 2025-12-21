import 'package:xml/xml.dart';

import 'docx_node.dart';

/// A footnote reference in inline text.
///
/// This represents the superscript number/symbol in the main text
/// that references a footnote at the bottom of the page.
class DocxFootnoteRef extends DocxInline {
  /// The footnote ID (matches the footnote in footnotes.xml).
  final int footnoteId;

  const DocxFootnoteRef({required this.footnoteId, super.id});

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitText(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:rPr', nest: () {
        builder.element('w:rStyle', nest: () {
          builder.attribute('w:val', 'FootnoteReference');
        });
      });
      builder.element('w:footnoteReference', nest: () {
        builder.attribute('w:id', footnoteId.toString());
      });
    });
  }
}

/// An endnote reference in inline text.
///
/// This represents the superscript number/symbol in the main text
/// that references an endnote at the end of the document.
class DocxEndnoteRef extends DocxInline {
  /// The endnote ID (matches the endnote in endnotes.xml).
  final int endnoteId;

  const DocxEndnoteRef({required this.endnoteId, super.id});

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitText(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:rPr', nest: () {
        builder.element('w:rStyle', nest: () {
          builder.attribute('w:val', 'EndnoteReference');
        });
      });
      builder.element('w:endnoteReference', nest: () {
        builder.attribute('w:id', endnoteId.toString());
      });
    });
  }
}

/// A footnote definition.
///
/// Contains the actual footnote content that appears at the bottom of the page.
class DocxFootnote extends DocxNode {
  /// Unique ID for this footnote.
  final int footnoteId;

  /// The content of the footnote (paragraphs, etc.).
  final List<DocxBlock> content;

  const DocxFootnote({
    required this.footnoteId,
    required this.content,
    super.id,
  });

  DocxFootnote copyWith({
    int? footnoteId,
    List<DocxBlock>? content,
  }) {
    return DocxFootnote(
      footnoteId: footnoteId ?? this.footnoteId,
      content: content ?? this.content,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    // Visit each block in the footnote
    for (var block in content) {
      block.accept(visitor);
    }
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:footnote', nest: () {
      builder.attribute('w:id', footnoteId.toString());
      for (var block in content) {
        block.buildXml(builder);
      }
    });
  }
}

/// An endnote definition.
///
/// Contains the actual endnote content that appears at the end of the document.
class DocxEndnote extends DocxNode {
  /// Unique ID for this endnote.
  final int endnoteId;

  /// The content of the endnote (paragraphs, etc.).
  final List<DocxBlock> content;

  const DocxEndnote({
    required this.endnoteId,
    required this.content,
    super.id,
  });

  DocxEndnote copyWith({
    int? endnoteId,
    List<DocxBlock>? content,
  }) {
    return DocxEndnote(
      endnoteId: endnoteId ?? this.endnoteId,
      content: content ?? this.content,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    // Visit each block in the endnote
    for (var block in content) {
      block.accept(visitor);
    }
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:endnote', nest: () {
      builder.attribute('w:id', endnoteId.toString());
      for (var block in content) {
        block.buildXml(builder);
      }
    });
  }
}
