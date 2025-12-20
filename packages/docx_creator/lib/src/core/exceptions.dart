/// Custom exceptions for `docx_ai_creator`.
///
/// Provides clear, actionable error messages for common failure scenarios.
library;

// ============================================================
// BASE EXCEPTION
// ============================================================

/// Base exception for all docx_ai_creator errors.
abstract class DocxException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional context about where the error occurred.
  final String? context;

  const DocxException(this.message, {this.context});

  @override
  String toString() {
    if (context != null) {
      return '$runtimeType: $message\nContext: $context';
    }
    return '$runtimeType: $message';
  }
}

// ============================================================
// PARSER EXCEPTIONS
// ============================================================

/// Thrown when parsing HTML, Markdown, or JSON fails.
///
/// ```dart
/// try {
///   final doc = DocxParser.fromHtml('<invalid>');
/// } on DocxParserException catch (e) {
///   print('Parsing failed: ${e.message}');
///   print('At: ${e.context}');
/// }
/// ```
class DocxParserException extends DocxException {
  /// The source format being parsed (e.g., "HTML", "Markdown", "JSON").
  final String sourceFormat;

  /// Line number where the error occurred, if available.
  final int? line;

  /// Column number where the error occurred, if available.
  final int? column;

  const DocxParserException(
    super.message, {
    required this.sourceFormat,
    this.line,
    this.column,
    super.context,
  });

  @override
  String toString() {
    final location =
        line != null ? ' at line $line${column != null ? ':$column' : ''}' : '';
    return 'DocxParserException ($sourceFormat$location): $message'
        '${context != null ? '\nContext: $context' : ''}';
  }
}

// ============================================================
// EXPORT EXCEPTIONS
// ============================================================

/// Thrown when document export fails.
///
/// ```dart
/// try {
///   await exporter.export(doc, 'output.docx');
/// } on DocxExportException catch (e) {
///   print('Export failed: ${e.message}');
/// }
/// ```
class DocxExportException extends DocxException {
  /// The target format (e.g., "DOCX", "HTML", "PDF").
  final String targetFormat;

  const DocxExportException(
    super.message, {
    required this.targetFormat,
    super.context,
  });

  @override
  String toString() {
    return 'DocxExportException ($targetFormat): $message'
        '${context != null ? '\nContext: $context' : ''}';
  }
}

// ============================================================
// VALIDATION EXCEPTIONS
// ============================================================

/// Thrown when document structure is invalid.
///
/// For example, a table with no rows, or an image with no data.
class DocxValidationException extends DocxException {
  /// The element type that failed validation.
  final String elementType;

  const DocxValidationException(
    super.message, {
    required this.elementType,
    super.context,
  });

  @override
  String toString() {
    return 'DocxValidationException ($elementType): $message'
        '${context != null ? '\nContext: $context' : ''}';
  }
}

// ============================================================
// IO EXCEPTIONS
// ============================================================

/// Thrown when file operations fail.
class DocxIOException extends DocxException {
  /// The file path involved, if any.
  final String? filePath;

  const DocxIOException(super.message, {this.filePath, super.context});

  @override
  String toString() {
    return 'DocxIOException: $message'
        '${filePath != null ? '\nFile: $filePath' : ''}'
        '${context != null ? '\nContext: $context' : ''}';
  }
}
