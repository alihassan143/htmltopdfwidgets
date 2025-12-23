/// Represents a relationship entry from .rels files.
///
/// Relationships link document parts to external resources like images,
/// hyperlinks, headers, footers, and styles.
class DocxRelationship {
  final String id;
  final String type;
  final String target;

  /// Target mode: null for internal targets, 'External' for URLs/external resources.
  final String? targetMode;

  const DocxRelationship({
    required this.id,
    required this.type,
    required this.target,
    this.targetMode,
  });

  /// Common relationship types
  static const String typeImage =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';
  static const String typeHyperlink =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink';
  static const String typeHeader =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header';
  static const String typeFooter =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer';
  static const String typeStyles =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';
  static const String typeNumbering =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering';
  static const String typeFontTable =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable';
  static const String typeSettings =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings';

  bool get isImage => type == typeImage;
  bool get isHyperlink => type == typeHyperlink;
  bool get isHeader => type == typeHeader;
  bool get isFooter => type == typeFooter;

  /// Returns true if this is an external target (like a URL).
  bool get isExternal => targetMode == 'External';

  /// Returns true if this is an internal target (archive path).
  bool get isInternal => targetMode == null || targetMode != 'External';

  /// Returns the short type name (e.g., 'image', 'hyperlink').
  String get shortType {
    final parts = type.split('/');
    return parts.isNotEmpty ? parts.last : type;
  }
}
