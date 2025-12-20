import 'package:xml/xml.dart';

import 'docx_node.dart';

/// Represents raw XML content that should be preserved as-is.
///
/// This is used to support "round-tripping" of DOCX files where we encounter
/// features or tags that [docx_creator] explicitly doesn't support yet (like charts,
/// smart art, equations, etc.).
///
/// Instead of discarding them, we store the raw XML and write it back out
/// untouched during export.
class DocxRawXml extends DocxBlock {
  /// The raw XML string content.
  final String content;

  const DocxRawXml(this.content, {super.id});

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitRawXml(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    // Parse the raw XML content specifically handling fragments or full elements
    try {
      // We parse as a fragment because it might be a list of nodes or a single node
      final fragment = XmlDocumentFragment.parse(content);
      for (var node in fragment.children) {
        _writeXmlNode(builder, node);
      }
    } catch (e) {
      // If parsing fails, we could try to write as text (ignoring structure)
      // or rethrow. For now, let's treat it as a comment to preserve data but indicate error
      builder.comment('Failed to parse raw XML: $e');
    }
  }

  void _writeXmlNode(XmlBuilder builder, XmlNode node) {
    if (node is XmlElement) {
      builder.element(node.name.qualified, nest: () {
        for (var attr in node.attributes) {
          builder.attribute(attr.name.qualified, attr.value);
        }
        for (var child in node.children) {
          _writeXmlNode(builder, child);
        }
      });
    } else if (node is XmlText) {
      builder.text(node.value);
    } else if (node is XmlCDATA) {
      builder.cdata(node.value);
    } else if (node is XmlComment) {
      builder.comment(node.value);
    }
    // We ignore other types like ProcessingInstruction for now if not critical
  }
}

/// Represents raw inline XML content that should be preserved as-is.
class DocxRawInline extends DocxInline {
  /// The raw XML string content.
  final String content;

  const DocxRawInline(this.content, {super.id});

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitRawInline(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    // Reuse logic from DocxRawXml
    const DocxRawXml(
      '',
    )._writeXmlNode(builder, XmlDocumentFragment.parse(content));
  }
}
