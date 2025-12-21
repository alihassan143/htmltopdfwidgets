/// Represents a relationship entry from .rels files.
class DocxRelationship {
  final String id;
  final String type;
  final String target;

  const DocxRelationship({
    required this.id,
    required this.type,
    required this.target,
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

  bool get isImage => type == typeImage;
  bool get isHyperlink => type == typeHyperlink;
  bool get isHeader => type == typeHeader;
  bool get isFooter => type == typeFooter;
}
