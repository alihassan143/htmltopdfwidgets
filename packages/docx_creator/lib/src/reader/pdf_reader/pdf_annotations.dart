import 'pdf_parser.dart';

/// Types of PDF annotations.
enum PdfAnnotationType {
  text,
  link,
  freeText,
  line,
  square,
  circle,
  polygon,
  polyLine,
  highlight,
  underline,
  strikeOut,
  squiggly,
  stamp,
  caret,
  ink,
  popup,
  fileAttachment,
  sound,
  movie,
  widget,
  screen,
  printerMark,
  trapNet,
  watermark,
  threeDimensional,
  redact,
  unknown,
}

/// Represents a PDF annotation.
class PdfAnnotation {
  /// Type of annotation.
  final PdfAnnotationType type;

  /// Bounding rectangle (x, y, width, height).
  final double x;
  final double y;
  final double width;
  final double height;

  /// Text content/contents of the annotation.
  final String? contents;

  /// Author/title of the annotation.
  final String? author;

  /// Subject of the annotation.
  final String? subject;

  /// Modification date.
  final DateTime? modificationDate;

  /// Creation date.
  final DateTime? creationDate;

  /// Annotation color (RGB).
  final List<double>? color;

  /// Interior color for closed annotations.
  final List<double>? interiorColor;

  /// Border style.
  final PdfAnnotationBorder? border;

  /// Opacity (0.0 - 1.0).
  final double opacity;

  /// Link destination (for link annotations).
  final String? linkDestination;

  /// Link URI (for link annotations).
  final String? linkUri;

  /// Quadrilateral points for text markup annotations.
  final List<List<double>>? quadPoints;

  /// Page number this annotation is on.
  final int pageNumber;

  /// Raw annotation flags.
  final int flags;

  PdfAnnotation({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageNumber,
    this.contents,
    this.author,
    this.subject,
    this.modificationDate,
    this.creationDate,
    this.color,
    this.interiorColor,
    this.border,
    this.opacity = 1.0,
    this.linkDestination,
    this.linkUri,
    this.quadPoints,
    this.flags = 0,
  });

  /// Whether the annotation is invisible.
  bool get isInvisible => (flags & 1) != 0;

  /// Whether the annotation is hidden.
  bool get isHidden => (flags & 2) != 0;

  /// Whether the annotation should be printed.
  bool get isPrintable => (flags & 4) != 0;

  /// Whether zooming affects the annotation.
  bool get isNoZoom => (flags & 8) != 0;

  /// Whether rotation affects the annotation.
  bool get isNoRotate => (flags & 16) != 0;

  /// Whether the annotation can be viewed on screen.
  bool get isNoView => (flags & 32) != 0;

  /// Whether the annotation is read-only.
  bool get isReadOnly => (flags & 64) != 0;

  /// Whether the annotation is locked.
  bool get isLocked => (flags & 128) != 0;

  @override
  String toString() =>
      'PdfAnnotation($type, rect: ($x, $y, $width, $height), contents: $contents)';
}

/// Annotation border style.
class PdfAnnotationBorder {
  final double width;
  final String
      style; // S (solid), D (dashed), B (beveled), I (inset), U (underline)
  final List<double>? dashPattern;

  PdfAnnotationBorder({
    this.width = 1.0,
    this.style = 'S',
    this.dashPattern,
  });
}

/// Extracts annotations from PDF pages.
class PdfAnnotationExtractor {
  final PdfParser _parser;

  PdfAnnotationExtractor(this._parser);

  /// Extracts all annotations from all pages.
  List<PdfAnnotation> extractAll() {
    final annotations = <PdfAnnotation>[];
    final pageCount = _parser.countPages();

    for (var i = 0; i < pageCount; i++) {
      annotations.addAll(extractFromPage(i));
    }

    return annotations;
  }

  /// Extracts annotations from a specific page.
  List<PdfAnnotation> extractFromPage(int pageNumber) {
    final annotations = <PdfAnnotation>[];

    // Get page object
    final pageRef = _getPageRef(pageNumber);
    if (pageRef == null) return annotations;

    final pageObj = _parser.getObject(pageRef);
    if (pageObj == null) return annotations;

    // Get Annots array
    final annotsMatch =
        RegExp(r'/Annots\s*\[([^\]]*)\]').firstMatch(pageObj.content);
    if (annotsMatch == null) {
      // Try indirect reference
      final annotsRefMatch =
          RegExp(r'/Annots\s+(\d+)\s+\d+\s+R').firstMatch(pageObj.content);
      if (annotsRefMatch != null) {
        final annotsRef = int.parse(annotsRefMatch.group(1)!);
        final annotsObj = _parser.getObject(annotsRef);
        if (annotsObj != null) {
          final arrayMatch =
              RegExp(r'\[([^\]]*)\]').firstMatch(annotsObj.content);
          if (arrayMatch != null) {
            annotations
                .addAll(_parseAnnotsArray(arrayMatch.group(1)!, pageNumber));
          }
        }
      }
      return annotations;
    }

    annotations.addAll(_parseAnnotsArray(annotsMatch.group(1)!, pageNumber));
    return annotations;
  }

  /// Gets page reference by page number.
  int? _getPageRef(int pageNumber) {
    final pagesObj = _parser.getObject(_parser.pagesRef);
    if (pagesObj == null) return null;

    var currentPage = 0;
    return _findPageRef(pagesObj.content, pageNumber, currentPage).$1;
  }

  /// Recursively finds page reference.
  (int?, int) _findPageRef(String content, int targetPage, int currentPage) {
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(content);
    if (kidsMatch == null) return (null, currentPage);

    final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
    for (final ref in refs) {
      final objRef = int.parse(ref.group(1)!);
      final obj = _parser.getObject(objRef);
      if (obj == null) continue;

      if (obj.content.contains('/Type /Page') ||
          obj.content.contains('/Type/Page')) {
        if (currentPage == targetPage) {
          return (objRef, currentPage + 1);
        }
        currentPage++;
      } else if (obj.content.contains('/Type /Pages') ||
          obj.content.contains('/Type/Pages')) {
        final result = _findPageRef(obj.content, targetPage, currentPage);
        if (result.$1 != null) return result;
        currentPage = result.$2;
      }
    }

    return (null, currentPage);
  }

  /// Parses annotations array content.
  List<PdfAnnotation> _parseAnnotsArray(String arrayContent, int pageNumber) {
    final annotations = <PdfAnnotation>[];

    final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(arrayContent);
    for (final ref in refs) {
      final annotRef = int.parse(ref.group(1)!);
      final annotation = _parseAnnotation(annotRef, pageNumber);
      if (annotation != null) {
        annotations.add(annotation);
      }
    }

    return annotations;
  }

  /// Parses a single annotation.
  PdfAnnotation? _parseAnnotation(int annotRef, int pageNumber) {
    final obj = _parser.getObject(annotRef);
    if (obj == null) return null;

    final content = obj.content;

    // Parse type
    final type = _parseAnnotationType(content);

    // Parse rectangle
    final rect = _parseRect(content);
    if (rect == null) return null;

    // Parse contents
    String? contents;
    final contentsMatch =
        RegExp(r'/Contents\s*\(([^)]*)\)').firstMatch(content);
    if (contentsMatch != null) {
      contents = _decodeLiteralString(contentsMatch.group(1)!);
    } else {
      final hexContentsMatch =
          RegExp(r'/Contents\s*<([^>]*)>').firstMatch(content);
      if (hexContentsMatch != null) {
        contents = _decodeHexString(hexContentsMatch.group(1)!);
      }
    }

    // Parse author/title
    String? author;
    final tMatch = RegExp(r'/T\s*\(([^)]*)\)').firstMatch(content);
    if (tMatch != null) {
      author = _decodeLiteralString(tMatch.group(1)!);
    }

    // Parse subject
    String? subject;
    final subjMatch = RegExp(r'/Subj\s*\(([^)]*)\)').firstMatch(content);
    if (subjMatch != null) {
      subject = _decodeLiteralString(subjMatch.group(1)!);
    }

    // Parse color
    List<double>? color;
    final cMatch = RegExp(r'/C\s*\[\s*([^\]]+)\]').firstMatch(content);
    if (cMatch != null) {
      color = RegExp(r'[\d.]+')
          .allMatches(cMatch.group(1)!)
          .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
          .toList();
    }

    // Parse opacity
    double opacity = 1.0;
    final caMatch = RegExp(r'/CA\s+([\d.]+)').firstMatch(content);
    if (caMatch != null) {
      opacity = double.tryParse(caMatch.group(1)!) ?? 1.0;
    }

    // Parse flags
    int flags = 0;
    final fMatch = RegExp(r'/F\s+(\d+)').firstMatch(content);
    if (fMatch != null) {
      flags = int.tryParse(fMatch.group(1)!) ?? 0;
    }

    // Parse link destination
    String? linkUri;
    String? linkDestination;
    if (type == PdfAnnotationType.link) {
      final aMatch = RegExp(r'/A\s+(\d+)\s+\d+\s+R').firstMatch(content);
      if (aMatch != null) {
        final actionRef = int.parse(aMatch.group(1)!);
        final actionObj = _parser.getObject(actionRef);
        if (actionObj != null) {
          final uriMatch =
              RegExp(r'/URI\s*\(([^)]*)\)').firstMatch(actionObj.content);
          if (uriMatch != null) {
            linkUri = _decodeLiteralString(uriMatch.group(1)!);
          }
        }
      }

      final destMatch = RegExp(r'/Dest\s*\[([^\]]+)\]').firstMatch(content);
      if (destMatch != null) {
        linkDestination = destMatch.group(1);
      }
    }

    // Parse quad points for text markup
    List<List<double>>? quadPoints;
    if (type == PdfAnnotationType.highlight ||
        type == PdfAnnotationType.underline ||
        type == PdfAnnotationType.strikeOut) {
      final qpMatch = RegExp(r'/QuadPoints\s*\[([^\]]+)\]').firstMatch(content);
      if (qpMatch != null) {
        quadPoints = _parseQuadPoints(qpMatch.group(1)!);
      }
    }

    return PdfAnnotation(
      type: type,
      x: rect[0],
      y: rect[1],
      width: rect[2] - rect[0],
      height: rect[3] - rect[1],
      pageNumber: pageNumber,
      contents: contents,
      author: author,
      subject: subject,
      color: color,
      opacity: opacity,
      flags: flags,
      linkUri: linkUri,
      linkDestination: linkDestination,
      quadPoints: quadPoints,
    );
  }

  /// Parses annotation type.
  PdfAnnotationType _parseAnnotationType(String content) {
    final subtypeMatch = RegExp(r'/Subtype\s*/?(\w+)').firstMatch(content);
    if (subtypeMatch == null) return PdfAnnotationType.unknown;

    switch (subtypeMatch.group(1)!) {
      case 'Text':
        return PdfAnnotationType.text;
      case 'Link':
        return PdfAnnotationType.link;
      case 'FreeText':
        return PdfAnnotationType.freeText;
      case 'Line':
        return PdfAnnotationType.line;
      case 'Square':
        return PdfAnnotationType.square;
      case 'Circle':
        return PdfAnnotationType.circle;
      case 'Polygon':
        return PdfAnnotationType.polygon;
      case 'PolyLine':
        return PdfAnnotationType.polyLine;
      case 'Highlight':
        return PdfAnnotationType.highlight;
      case 'Underline':
        return PdfAnnotationType.underline;
      case 'StrikeOut':
        return PdfAnnotationType.strikeOut;
      case 'Squiggly':
        return PdfAnnotationType.squiggly;
      case 'Stamp':
        return PdfAnnotationType.stamp;
      case 'Caret':
        return PdfAnnotationType.caret;
      case 'Ink':
        return PdfAnnotationType.ink;
      case 'Popup':
        return PdfAnnotationType.popup;
      case 'FileAttachment':
        return PdfAnnotationType.fileAttachment;
      case 'Sound':
        return PdfAnnotationType.sound;
      case 'Movie':
        return PdfAnnotationType.movie;
      case 'Widget':
        return PdfAnnotationType.widget;
      case 'Screen':
        return PdfAnnotationType.screen;
      case 'PrinterMark':
        return PdfAnnotationType.printerMark;
      case 'TrapNet':
        return PdfAnnotationType.trapNet;
      case 'Watermark':
        return PdfAnnotationType.watermark;
      case '3D':
        return PdfAnnotationType.threeDimensional;
      case 'Redact':
        return PdfAnnotationType.redact;
      default:
        return PdfAnnotationType.unknown;
    }
  }

  /// Parses Rect array.
  List<double>? _parseRect(String content) {
    final rectMatch = RegExp(r'/Rect\s*\[\s*([^\]]+)\]').firstMatch(content);
    if (rectMatch == null) return null;

    final numbers = RegExp(r'-?[\d.]+')
        .allMatches(rectMatch.group(1)!)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .toList();

    return numbers.length >= 4 ? numbers.sublist(0, 4) : null;
  }

  /// Parses QuadPoints array.
  List<List<double>> _parseQuadPoints(String content) {
    final numbers = RegExp(r'-?[\d.]+')
        .allMatches(content)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .toList();

    final quads = <List<double>>[];
    for (var i = 0; i < numbers.length; i += 8) {
      if (i + 8 <= numbers.length) {
        quads.add(numbers.sublist(i, i + 8));
      }
    }
    return quads;
  }

  /// Decodes literal string.
  String _decodeLiteralString(String str) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < str.length) {
      if (str[i] == '\\' && i + 1 < str.length) {
        final next = str[i + 1];
        switch (next) {
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 't':
            buffer.write('\t');
            break;
          case '(':
          case ')':
          case '\\':
            buffer.write(next);
            break;
          default:
            buffer.write(next);
        }
        i += 2;
      } else {
        buffer.write(str[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// Decodes hex string.
  String _decodeHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.length >= 4 && clean.substring(0, 4).toUpperCase() == 'FEFF') {
      final buffer = StringBuffer();
      for (var i = 4; i < clean.length; i += 4) {
        if (i + 4 <= clean.length) {
          buffer.writeCharCode(int.parse(clean.substring(i, i + 4), radix: 16));
        }
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i += 2) {
      final end = i + 2 <= clean.length ? i + 2 : clean.length;
      var chunk = clean.substring(i, end);
      if (chunk.length == 1) chunk += '0';
      buffer.writeCharCode(int.parse(chunk, radix: 16));
    }
    return buffer.toString();
  }
}
