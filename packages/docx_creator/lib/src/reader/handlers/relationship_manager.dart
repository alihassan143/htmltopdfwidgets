import 'package:xml/xml.dart';

import '../models/docx_relationship.dart';
import '../reader_context.dart';

/// Manages document relationships and content types.
class RelationshipManager {
  final ReaderContext context;

  RelationshipManager(this.context);

  /// Load content types from [Content_Types].xml.
  void loadContentTypes() {
    final file = context.readContent('[Content_Types].xml');
    if (file == null) return;

    try {
      final xml = XmlDocument.parse(file);
      for (var override in xml.findAllElements('Override')) {
        final partName = override.getAttribute('PartName');
        final contentType = override.getAttribute('ContentType');
        if (partName != null && contentType != null) {
          context.contentTypes[partName] = contentType;
        }
      }
    } catch (_) {}
  }

  /// Load document relationships from word/_rels/document.xml.rels.
  void loadDocumentRelationships() {
    final file = context.readContent('word/_rels/document.xml.rels');
    if (file == null) return;

    try {
      final xml = XmlDocument.parse(file);
      for (var rel in xml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final type = rel.getAttribute('Type');
        final target = rel.getAttribute('Target');
        if (id != null && type != null && target != null) {
          context.relationships[id] = DocxRelationship(
            id: id,
            type: type,
            target: target,
          );
        }
      }
    } catch (_) {}
  }

  /// Get a relationship by ID.
  DocxRelationship? get(String rId) => context.relationships[rId];

  /// Check if a relationship is an image.
  bool isImage(String rId) => context.relationships[rId]?.isImage ?? false;

  /// Check if a relationship is a hyperlink.
  bool isHyperlink(String rId) =>
      context.relationships[rId]?.isHyperlink ?? false;
}
