import 'pdf_parser.dart';

/// Represents a value in a PDF Number Tree.
/// Use generic T to allow specialized parsing of values.
class PdfNumberTree {
  final PdfParser _parser;

  PdfNumberTree(this._parser);

  /// Parses a Number Tree and returns a map of index to raw value string.
  /// The value string could be an indirect ref "10 0 R" or a direct dict "<< ... >>".
  Map<int, String> parse(int rootRef) {
    final result = <int, String>{};
    _parseNode(rootRef, result);
    return result;
  }

  void _parseNode(int ref, Map<int, String> result) {
    final obj = _parser.getObject(ref);
    if (obj == null) return;

    // Kids (Intermediate)
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (kidsMatch != null) {
      final kidsContent = kidsMatch.group(1)!;
      final kidRefs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsContent);
      for (final kid in kidRefs) {
        _parseNode(int.parse(kid.group(1)!), result);
      }
      return;
    }

    // Nums (Leaf)
    // Format: [ key1 value1 key2 value2 ... ]
    // Values can be complex (dicts), so we need accurate tokenizing.
    final numsMatch =
        RegExp(r'/Nums\s*\[(.*?)\]', dotAll: true).firstMatch(obj.content);
    if (numsMatch != null) {
      final numsContent = numsMatch.group(1)!;
      _parseNumsArray(numsContent, result);
    }
  }

  void _parseNumsArray(String content, Map<int, String> result) {
    var i = 0;
    while (i < content.length) {
      // 1. Skip whitespace
      while (i < content.length && _isWhitespace(content.codeUnitAt(i))) {
        i++;
      }
      if (i >= content.length) break;

      // 2. Parse Key (Integer)
      final keyStart = i;
      while (i < content.length && _isDigit(content.codeUnitAt(i))) {
        i++;
      }
      final keyStr = content.substring(keyStart, i);
      final key = int.tryParse(keyStr);

      // 3. Skip whitespace
      while (i < content.length && _isWhitespace(content.codeUnitAt(i))) {
        i++;
      }

      // 4. Parse Value (Ref or Dict)
      if (i >= content.length || key == null) break;

      final valStart = i;
      String value;

      if (content.startsWith('<<', i)) {
        // Direct Dictionary
        value = _extractBalancedDict(content, i);
        i += value.length;
      } else {
        // Assume Indirect Ref (e.g., "12 0 R") or simple atomic value
        // Look ahead for "R"
        // Rough heuristic for now: read until next key (next number)
        // But keys are just numbers.
        // Better: ref is "digit digit R".
        final refMatch =
            RegExp(r'^\d+\s+\d+\s+R').firstMatch(content.substring(i));
        if (refMatch != null) {
          value = refMatch.group(0)!;
          i += value.length;
        } else {
          // Fallback: read token?
          // PageLabels usually are dicts. If it's something else, we might fail here.
          // Just advance past token.
          while (i < content.length && !_isWhitespace(content.codeUnitAt(i))) {
            i++;
          }
          value = content.substring(valStart, i);
        }
      }

      result[key] = value;
    }
  }

  String _extractBalancedDict(String s, int index) {
    // Basic balanced << >> extractor
    int depth = 0;
    int start = index;
    for (int i = index; i < s.length; i++) {
      if (s.startsWith('<<', i)) {
        depth++;
        i++; // skip one extra
      } else if (s.startsWith('>>', i)) {
        depth--;
        i++;
        if (depth == 0) {
          return s.substring(start, i + 1);
        }
      }
    }
    return s.substring(start); // Validation fail
  }

  bool _isWhitespace(int c) {
    return c == 32 ||
        c == 9 ||
        c == 10 ||
        c == 13 ||
        c == 12; // space, tab, cr, lf, ff
  }

  bool _isDigit(int c) {
    return c >= 48 && c <= 57;
  }
}
