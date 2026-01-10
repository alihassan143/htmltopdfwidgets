import 'pdf_parser.dart';

/// Represents the logical structure hierarchy of a PDF (Tagged PDF).
class PdfStructureTree {
  final PdfParser _parser;
  final int rootRef;

  PdfStructureTree(this._parser, this.rootRef);

  /// Checks if the structure tree is valid/populated.
  bool get hasStructure {
    final obj = _parser.getObject(rootRef);
    return obj != null;
  }

  /// Returns the RoleMap if present (maps custom tags to standard tags).
  Map<String, String> get roleMap {
    final obj = _parser.getObject(rootRef);
    if (obj == null) return {};

    final mapRegex = RegExp(r'/RoleMap\s*<<([^>]+)>>', dotAll: true);
    final match = mapRegex.firstMatch(obj.content);
    if (match == null) return {};

    final content = match.group(1)!;
    final map = <String, String>{};

    // Basic parsing of name pairs /Custom /Standard
    final pairs =
        RegExp(r'/([^\s/()<>\[\]]+)\s+/([^\s/()<>\[\]]+)').allMatches(content);
    for (final m in pairs) {
      map['/${m.group(1)!}'] = '/${m.group(2)!}';
    }

    return map;
  }
}
