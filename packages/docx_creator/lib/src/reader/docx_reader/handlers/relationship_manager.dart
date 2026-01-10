import 'package:xml/xml.dart';

import '../models/docx_relationship.dart';
import '../reader_context/reader_context.dart';

/// Manages document relationships and content types.
///
/// Relationships in DOCX link document parts to external resources like
/// images, hyperlinks, headers, footers, and styles. This manager provides
/// methods to load, query, and validate these relationships.
class RelationshipManager {
  final ReaderContext context;

  /// Tracks all relationship IDs that have been referenced during parsing.
  final Set<String> _referencedIds = {};

  RelationshipManager(this.context);

  /// Load content types from [Content_Types].xml.
  void loadContentTypes() {
    final file = context.readContent('[Content_Types].xml');
    if (file == null) return;

    try {
      final xml = XmlDocument.parse(file);
      // Load Default extensions
      for (var def in xml.findAllElements('Default')) {
        final ext = def.getAttribute('Extension');
        final contentType = def.getAttribute('ContentType');
        if (ext != null && contentType != null) {
          context.contentTypes['.$ext'] = contentType;
        }
      }
      // Load Override parts
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
        final targetMode = rel.getAttribute('TargetMode');
        if (id != null && type != null && target != null) {
          context.relationships[id] = DocxRelationship(
            id: id,
            type: type,
            target: target,
            targetMode: targetMode,
          );
        }
      }
    } catch (_) {}
  }

  /// Load relationships from a specific .rels file.
  ///
  /// Used for loading header, footer, or other part-specific relationships.
  Map<String, DocxRelationship> loadRelationshipsFrom(String relsPath) {
    final rels = <String, DocxRelationship>{};
    final file = context.readContent(relsPath);
    if (file == null) return rels;

    try {
      final xml = XmlDocument.parse(file);
      for (var rel in xml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final type = rel.getAttribute('Type');
        final target = rel.getAttribute('Target');
        final targetMode = rel.getAttribute('TargetMode');
        if (id != null && type != null && target != null) {
          rels[id] = DocxRelationship(
            id: id,
            type: type,
            target: target,
            targetMode: targetMode,
          );
        }
      }
    } catch (_) {}

    return rels;
  }

  /// Get a relationship by ID and mark it as referenced.
  DocxRelationship? get(String rId) {
    _referencedIds.add(rId);
    return context.relationships[rId];
  }

  /// Get a relationship by ID without marking it as referenced.
  DocxRelationship? peek(String rId) => context.relationships[rId];

  /// Check if a relationship is an image.
  bool isImage(String rId) => context.relationships[rId]?.isImage ?? false;

  /// Check if a relationship is a hyperlink.
  bool isHyperlink(String rId) =>
      context.relationships[rId]?.isHyperlink ?? false;

  /// Check if a relationship is external (e.g., a URL).
  bool isExternal(String rId) =>
      context.relationships[rId]?.targetMode == 'External';

  /// Resolves the full archive path for a relationship target.
  ///
  /// Handles both absolute paths (starting with /) and relative paths.
  String? resolveTarget(String rId) {
    final rel = context.relationships[rId];
    if (rel == null) return null;

    // External targets are not archive paths
    if (rel.targetMode == 'External') return rel.target;

    String target = rel.target;
    if (target.startsWith('/')) {
      // Absolute path - remove leading slash
      return target.substring(1);
    } else {
      // Relative to word/ directory
      return 'word/$target';
    }
  }

  /// Validates that all referenced relationship IDs exist.
  ///
  /// Returns a list of missing relationship IDs, or empty if all are valid.
  List<String> validateReferences() {
    final missing = <String>[];
    for (var rId in _referencedIds) {
      if (!context.relationships.containsKey(rId)) {
        missing.add(rId);
      }
    }
    return missing;
  }

  /// Validates the provided set of relationship IDs.
  ///
  /// Returns a list of IDs that don't exist in the relationships map.
  List<String> validateIds(Set<String> ids) {
    return ids.where((id) => !context.relationships.containsKey(id)).toList();
  }

  /// Gets all relationships of a specific type.
  ///
  /// Common types:
  /// - `http://schemas.openxmlformats.org/officeDocument/2006/relationships/image`
  /// - `http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink`
  /// - `http://schemas.openxmlformats.org/officeDocument/2006/relationships/header`
  /// - `http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer`
  List<DocxRelationship> getByType(String type) {
    return context.relationships.values
        .where((rel) => rel.type == type || rel.type.endsWith('/$type'))
        .toList();
  }

  /// Gets all image relationships.
  List<DocxRelationship> get images => getByType('image');

  /// Gets all hyperlink relationships.
  List<DocxRelationship> get hyperlinks => getByType('hyperlink');

  /// Gets all header relationships.
  List<DocxRelationship> get headers => getByType('header');

  /// Gets all footer relationships.
  List<DocxRelationship> get footers => getByType('footer');

  /// Gets the total count of relationships.
  int get count => context.relationships.length;

  /// Gets all relationship IDs.
  Iterable<String> get allIds => context.relationships.keys;

  /// Clears the referenced IDs tracking.
  void clearReferencedIds() => _referencedIds.clear();
}
