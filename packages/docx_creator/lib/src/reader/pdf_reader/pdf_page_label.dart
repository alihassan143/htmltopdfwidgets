/// Represents a PDF Page Label.
///
/// See PDF 32000-1:2008 12.4.2 Page Labels.
class PdfPageLabel {
  final String style; // /D, /R, /r, /A, /a
  final String? prefix; // /P
  final int start; // /St (default 1)

  PdfPageLabel({
    this.style = '/D', // Decimal arabic default
    this.prefix,
    this.start = 1,
  });

  /// Parses a Page Label dictionary (e.g. `<< /S /r /P (App-) >>`)
  static PdfPageLabel parse(String content) {
    String style = '/D';
    String? prefix;
    int start = 1;

    final sMatch = RegExp(r'/S\s+(/[a-zA-Z]+)').firstMatch(content);
    if (sMatch != null) style = sMatch.group(1)!;

    final pMatch = RegExp(r'/P\s*\((.*?)\)').firstMatch(content);
    if (pMatch != null) prefix = pMatch.group(1)!;

    final stMatch = RegExp(r'/St\s+(\d+)').firstMatch(content);
    if (stMatch != null) start = int.parse(stMatch.group(1)!);

    return PdfPageLabel(style: style, prefix: prefix, start: start);
  }

  /// Formats the label for a specific page index (0-based) relative to the start of this range.
  String format(int relativeIndex) {
    final value = start + relativeIndex;
    final p = prefix ?? '';

    switch (style) {
      case '/R': // Uppercase Roman
        return '$p${_toRoman(value).toUpperCase()}';
      case '/r': // Lowercase Roman
        return '$p${_toRoman(value).toLowerCase()}';
      case '/A': // Uppercase Letters (A, B, ... AA, BB)
        return '$p${_toLetters(value).toUpperCase()}';
      case '/a': // Lowercase Letters
        return '$p${_toLetters(value).toLowerCase()}';
      case '/D': // Decimal
      default:
        return '$p$value';
    }
  }

  String _toRoman(int n) {
    if (n <= 0) return '';
    const rome = [
      MapEntry(1000, 'M'),
      MapEntry(900, 'CM'),
      MapEntry(500, 'D'),
      MapEntry(400, 'CD'),
      MapEntry(100, 'C'),
      MapEntry(90, 'XC'),
      MapEntry(50, 'L'),
      MapEntry(40, 'XL'),
      MapEntry(10, 'X'),
      MapEntry(9, 'IX'),
      MapEntry(5, 'V'),
      MapEntry(4, 'IV'),
      MapEntry(1, 'I'),
    ];
    var buffer = StringBuffer();
    var rem = n;
    for (var entry in rome) {
      while (rem >= entry.key) {
        buffer.write(entry.value);
        rem -= entry.key;
      }
    }
    return buffer.toString();
  }

  String _toLetters(int n) {
    if (n <= 0) return '';
    // A..Z, AA..ZZ
    // 1=A, 26=Z, 27=AA
    final sb = StringBuffer();
    // This is a naive implementation; PDF spec implies 'A', 'B'... 'AA', 'BB' (not base-26 'AB')
    // "A", "B", ... "Z", "AA", "BB"
    final index = (n - 1) % 26;
    final char = String.fromCharCode(65 + index);
    final count = ((n - 1) / 26).floor() + 1;
    for (var i = 0; i < count; i++) sb.write(char);
    return sb.toString();
  }
}
