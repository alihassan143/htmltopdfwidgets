import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models/docx_relationship.dart';
import 'models/docx_style.dart';
import 'models/docx_theme.dart';

/// Shared context for all reader components.
///
/// This object provides access to:
/// - The docx archive
/// - Parsed relationships and content types
/// - Resolved styles
/// - Numbering definitions
class ReaderContext {
  final Archive archive;

  /// Document relationships (rId -> relationship)
  final Map<String, DocxRelationship> relationships = {};

  /// Content types (partName -> contentType)
  final Map<String, String> contentTypes = {};

  /// Parsed styles (styleId -> DocxStyle)
  final Map<String, DocxStyle> styles = {};

  /// Raw numbering XML for list type detection
  String? numberingXml;

  /// Parsed numbering definitions (numId -> DocxNumberingDef)
  Map<int, DocxNumberingDef> parsedNumberings = {};

  /// Picture bullets (numPicBulletId -> relationship ID for image)
  final Map<int, String> pictureBullets = {};

  /// Relationships from numbering.xml.rels
  final Map<String, DocxRelationship> numberingRelationships = {};

  ReaderContext(this.archive);

  /// Read file content from the archive as a string.
  String? readContent(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return utf8.decode(file.content as List<int>);
  }

  /// Read file content from the archive as bytes.
  Uint8List? readBytes(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  /// Parse XML content from a path.
  XmlDocument? readXml(String path) {
    final content = readContent(path);
    if (content == null) return null;
    try {
      return XmlDocument.parse(content);
    } catch (_) {
      return null;
    }
  }

  /// Get a relationship by rId.
  DocxRelationship? getRelationship(String rId) => relationships[rId];

  /// Default paragraph style from docDefaults
  DocxStyle? defaultParagraphStyle;

  /// Default run style from docDefaults
  DocxStyle? defaultRunStyle;

  /// Resolve a style by ID, handling inheritance and defaults.
  DocxStyle resolveStyle(String? styleId) {
    if (styleId == null || !styles.containsKey(styleId)) {
      // Fallback to Normal if available, otherwise defaults
      if (styleId != 'Normal' && styles.containsKey('Normal')) {
        return styles['Normal']!;
      }
      return defaultParagraphStyle ?? DocxStyle.empty();
    }

    final style = styles[styleId]!;
    if (style.basedOn != null && style.basedOn != styleId) {
      final parent = resolveStyle(style.basedOn);
      return parent.merge(style);
    } else {
      // Root style - merge with defaults
      // Styles are either paragraph or character styles.
      // If it's a paragraph style, it should inherit from defaultParagraphStyle.
      // If content rely on this style, it needs the defaults.
      // Ideally, we distinguish style type, but DocxStyle often lacks type info in some contexts.
      // Usually named styles in styles.xml have type.

      // If this is a paragraph style (or unknown), merge on top of docDefaults
      if (style.type == 'paragraph' || style.type == null) {
        if (defaultParagraphStyle != null) {
          return defaultParagraphStyle!.merge(style);
        }
      }
      // Note: Character styles (type == 'character') merge with defaultParagraphFont...
      // strictly speaking, character styles are additive to the paragraph style they are applied to.
      // But if they have no basedOn, they start from "Default Paragraph Font" which is essentially empty or docDefaults.
    }
    return style;
  }
}
