/// Automates the generation of [Content_Types].xml for DOCX archives.
///
/// Dynamically registers content types based on the actual content of the
/// document, ensuring all media and parts are properly declared.
class ContentTypesGenerator {
  /// Default extension content types.
  static const Map<String, String> defaultExtensions = {
    'rels': 'application/vnd.openxmlformats-package.relationships+xml',
    'xml': 'application/xml',
    'png': 'image/png',
    'jpeg': 'image/jpeg',
    'jpg': 'image/jpeg',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'tiff': 'image/tiff',
    'tif': 'image/tiff',
    'odttf': 'application/vnd.openxmlformats-package.obfuscated-font',
    'ttf': 'application/x-font-ttf',
    'otf': 'application/x-font-opentype',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'svg': 'image/svg+xml',
    'emf': 'image/x-emf',
    'wmf': 'image/x-wmf',
  };

  /// Standard part overrides.
  static const Map<String, String> standardOverrides = {
    '/word/document.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
    '/word/styles.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
    '/word/settings.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml',
    '/word/fontTable.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml',
    '/word/numbering.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml',
    '/word/webSettings.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.webSettings+xml',
    '/word/footnotes.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml',
    '/word/endnotes.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml',
    '/word/comments.xml':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml',
    '/docProps/core.xml':
        'application/vnd.openxmlformats-package.core-properties+xml',
    '/docProps/app.xml':
        'application/vnd.openxmlformats-officedocument.extended-properties+xml',
    '/docProps/custom.xml':
        'application/vnd.openxmlformats-officedocument.custom-properties+xml',
  };

  /// Dynamic content types map.
  final Map<String, String> _extensions = {};
  final Map<String, String> _overrides = {};

  ContentTypesGenerator() {
    _extensions.addAll(defaultExtensions);
    _overrides.addAll(standardOverrides);
  }

  /// Registers a file extension with its content type.
  void registerExtension(String extension, String contentType) {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    _extensions[ext.toLowerCase()] = contentType;
  }

  /// Registers a specific part path with its content type.
  void registerPart(String partPath, String contentType) {
    final path = partPath.startsWith('/') ? partPath : '/$partPath';
    _overrides[path] = contentType;
  }

  /// Registers a header part.
  void registerHeader(String partName) {
    registerPart(
      'word/$partName',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml',
    );
  }

  /// Registers a footer part.
  void registerFooter(String partName) {
    registerPart(
      'word/$partName',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml',
    );
  }

  /// Registers a chart part.
  void registerChart(String partName) {
    registerPart(
      'word/charts/$partName',
      'application/vnd.openxmlformats-officedocument.drawingml.chart+xml',
    );
  }

  /// Registers a diagram part.
  void registerDiagram(String partName, String diagramType) {
    final contentType = switch (diagramType) {
      'data' =>
        'application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml',
      'layout' =>
        'application/vnd.openxmlformats-officedocument.drawingml.diagramLayout+xml',
      'style' =>
        'application/vnd.openxmlformats-officedocument.drawingml.diagramStyle+xml',
      'colors' =>
        'application/vnd.openxmlformats-officedocument.drawingml.diagramColors+xml',
      _ =>
        'application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml',
    };
    registerPart('word/diagrams/$partName', contentType);
  }

  /// Auto-detects content type from file extension.
  String? getContentTypeForExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _extensions[ext];
  }

  /// Scans archive paths and registers any media files.
  void scanAndRegister(List<String> archivePaths) {
    for (var path in archivePaths) {
      // Auto-register media files
      if (path.startsWith('word/media/')) {
        final ext = path.split('.').last.toLowerCase();
        if (!_extensions.containsKey(ext)) {
          final contentType = _guessContentType(ext);
          if (contentType != null) {
            registerExtension(ext, contentType);
          }
        }
      }

      // Auto-register headers/footers
      if (path.startsWith('word/header') && path.endsWith('.xml')) {
        final name = path.split('/').last;
        registerHeader(name);
      }
      if (path.startsWith('word/footer') && path.endsWith('.xml')) {
        final name = path.split('/').last;
        registerFooter(name);
      }
    }
  }

  String? _guessContentType(String ext) {
    // Common image types
    if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'tif', 'svg', 'webp']
        .contains(ext)) {
      return 'image/$ext';
    }
    // Font types
    if (['ttf', 'otf', 'woff', 'woff2'].contains(ext)) {
      return 'font/$ext';
    }
    return null;
  }

  /// Generates the [Content_Types].xml content.
  String generate() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');

    // Write Default elements (extensions)
    for (var entry in _extensions.entries) {
      buffer.writeln(
          '  <Default Extension="${entry.key}" ContentType="${entry.value}"/>');
    }

    // Write Override elements (specific parts)
    for (var entry in _overrides.entries) {
      buffer.writeln(
          '  <Override PartName="${entry.key}" ContentType="${entry.value}"/>');
    }

    buffer.writeln('</Types>');
    return buffer.toString();
  }

  /// Gets all registered extensions.
  Map<String, String> get extensions => Map.unmodifiable(_extensions);

  /// Gets all registered overrides.
  Map<String, String> get overrides => Map.unmodifiable(_overrides);
}
