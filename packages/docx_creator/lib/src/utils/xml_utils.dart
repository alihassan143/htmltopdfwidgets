/// XML utility functions for DOCX generation.
///
/// Provides text escaping, validation, and other XML-related utilities
/// to ensure generated DOCX files are well-formed and compliant.
library;

/// Escapes text content for safe XML embedding.
///
/// This handles the five predefined XML entities:
/// - `&` → `&amp;`
/// - `<` → `&lt;`
/// - `>` → `&gt;`
/// - `"` → `&quot;`
/// - `'` → `&apos;`
///
/// Note: The `xml` package's [XmlBuilder.text()] already handles escaping,
/// so this function is primarily for cases where raw strings are constructed
/// manually or for validation purposes.
String escapeXmlText(String text) {
  // Use StringBuffer for efficiency with multiple replacements
  final buffer = StringBuffer();

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    switch (char) {
      case '&':
        buffer.write('&amp;');
      case '<':
        buffer.write('&lt;');
      case '>':
        buffer.write('&gt;');
      case '"':
        buffer.write('&quot;');
      case "'":
        buffer.write('&apos;');
      default:
        buffer.write(char);
    }
  }

  return buffer.toString();
}

/// Escapes text for use in XML attribute values.
///
/// In addition to basic XML escaping, this also handles:
/// - Newlines and tabs (which are not allowed in attribute values)
String escapeXmlAttribute(String text) {
  final buffer = StringBuffer();

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    switch (char) {
      case '&':
        buffer.write('&amp;');
      case '<':
        buffer.write('&lt;');
      case '>':
        buffer.write('&gt;');
      case '"':
        buffer.write('&quot;');
      case "'":
        buffer.write('&apos;');
      case '\n':
        buffer.write('&#10;');
      case '\r':
        buffer.write('&#13;');
      case '\t':
        buffer.write('&#9;');
      default:
        buffer.write(char);
    }
  }

  return buffer.toString();
}

/// Validates that a string is a valid XML NCName (non-colonized name).
///
/// NCNames are used for element/attribute names without namespace prefixes.
/// They must:
/// - Start with a letter or underscore
/// - Contain only letters, digits, hyphens, underscores, and periods
/// - Not contain colons
bool isValidNcName(String name) {
  if (name.isEmpty) return false;

  // First character must be letter or underscore
  final first = name.codeUnitAt(0);
  if (!_isNameStartChar(first)) return false;

  // Remaining characters
  for (var i = 1; i < name.length; i++) {
    if (!_isNameChar(name.codeUnitAt(i))) return false;
  }

  return true;
}

bool _isNameStartChar(int c) {
  return (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      c == 0x5F; // underscore
}

bool _isNameChar(int c) {
  return _isNameStartChar(c) ||
      (c >= 0x30 && c <= 0x39) || // 0-9
      c == 0x2D || // hyphen
      c == 0x2E; // period
}

/// Strips invalid XML characters from a string.
///
/// XML 1.0 only allows certain characters. This removes any characters
/// that would make the XML invalid.
String stripInvalidXmlChars(String text) {
  final buffer = StringBuffer();

  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (_isValidXmlChar(c)) {
      buffer.write(text[i]);
    }
  }

  return buffer.toString();
}

/// Checks if a Unicode code point is valid in XML 1.0.
bool _isValidXmlChar(int c) {
  return c == 0x09 || // tab
      c == 0x0A || // newline
      c == 0x0D || // carriage return
      (c >= 0x20 && c <= 0xD7FF) ||
      (c >= 0xE000 && c <= 0xFFFD) ||
      (c >= 0x10000 && c <= 0x10FFFF);
}

/// Generates a unique document property ID.
///
/// DOCX documents require unique IDs for various elements like images.
/// This generates IDs in a way that's compatible with Microsoft Word.
class DocxIdGenerator {
  int _nextId;

  DocxIdGenerator({int startFrom = 1}) : _nextId = startFrom;

  /// Gets the next unique ID.
  int nextId() => _nextId++;

  /// Gets the current ID without incrementing.
  int get currentId => _nextId;

  /// Resets the generator to a specific starting value.
  void reset({int startFrom = 1}) {
    _nextId = startFrom;
  }
}
