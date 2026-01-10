import 'pdf_parser.dart';

/// Represents a PDF document outline (bookmark) item.
class PdfOutlineItem {
  /// Display title of the outline item.
  final String title;

  /// Target page number (0-indexed), if resolved.
  final int? pageNumber;

  /// Named destination reference.
  final String? namedDestination;

  /// Explicit destination array.
  final List<dynamic>? destination;

  /// Child outline items.
  final List<PdfOutlineItem> children;

  /// Whether this item is expanded by default.
  final bool isOpen;

  /// Color of the outline item (RGB, if specified).
  final List<double>? color;

  /// Text style flags (bit 0 = italic, bit 1 = bold).
  final int? flags;

  PdfOutlineItem({
    required this.title,
    this.pageNumber,
    this.namedDestination,
    this.destination,
    this.children = const [],
    this.isOpen = true,
    this.color,
    this.flags,
  });

  /// Whether the title should be displayed in italic.
  bool get isItalic => (flags ?? 0) & 1 != 0;

  /// Whether the title should be displayed in bold.
  bool get isBold => (flags ?? 0) & 2 != 0;

  @override
  String toString() => 'PdfOutlineItem($title, page: $pageNumber)';

  /// Flattens the outline hierarchy to a list.
  List<PdfOutlineItem> flatten() {
    final result = <PdfOutlineItem>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }
}

/// Extracts document outline/bookmarks from a PDF.
class PdfOutlineExtractor {
  final PdfParser _parser;
  final Map<int, int> _pageRefToNumber = {};

  PdfOutlineExtractor(this._parser);

  /// Extracts the document outline.
  /// Returns empty list if no outline exists.
  List<PdfOutlineItem> extract() {
    // Build page reference to page number mapping
    _buildPageMapping();

    // Get Outlines reference from catalog
    final catalogObj = _parser.getObject(_parser.rootRef);
    if (catalogObj == null) return [];

    final outlinesMatch =
        RegExp(r'/Outlines\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (outlinesMatch == null) return [];

    final outlinesRef = int.parse(outlinesMatch.group(1)!);
    final outlinesObj = _parser.getObject(outlinesRef);
    if (outlinesObj == null) return [];

    // Get First child
    final firstMatch =
        RegExp(r'/First\s+(\d+)\s+\d+\s+R').firstMatch(outlinesObj.content);
    if (firstMatch == null) return [];

    final firstRef = int.parse(firstMatch.group(1)!);
    return _parseOutlineLevel(firstRef);
  }

  /// Builds mapping from page object references to page numbers.
  void _buildPageMapping() {
    final pagesObj = _parser.getObject(_parser.pagesRef);
    if (pagesObj == null) return;

    _extractPageRefs(pagesObj.content, 0);
  }

  /// Recursively extracts page references.
  int _extractPageRefs(String content, int currentPage) {
    var page = currentPage;

    // Find Kids array
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(content);
    if (kidsMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final ref in refs) {
        final objRef = int.parse(ref.group(1)!);
        final obj = _parser.getObject(objRef);
        if (obj == null) continue;

        if (obj.content.contains('/Type /Page') ||
            obj.content.contains('/Type/Page')) {
          _pageRefToNumber[objRef] = page++;
        } else if (obj.content.contains('/Type /Pages') ||
            obj.content.contains('/Type/Pages')) {
          page = _extractPageRefs(obj.content, page);
        }
      }
    }

    return page;
  }

  /// Parses a level of outline items.
  List<PdfOutlineItem> _parseOutlineLevel(int firstRef) {
    final items = <PdfOutlineItem>[];
    var currentRef = firstRef;
    final visited = <int>{};

    while (currentRef > 0 && !visited.contains(currentRef)) {
      visited.add(currentRef);

      final obj = _parser.getObject(currentRef);
      if (obj == null) break;

      final item = _parseOutlineItem(obj.content);
      if (item != null) {
        items.add(item);
      }

      // Get Next sibling
      final nextMatch =
          RegExp(r'/Next\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
      if (nextMatch != null) {
        currentRef = int.parse(nextMatch.group(1)!);
      } else {
        break;
      }
    }

    return items;
  }

  /// Parses a single outline item.
  PdfOutlineItem? _parseOutlineItem(String content) {
    // Extract title
    final title = _extractTitle(content);
    if (title == null) return null;

    // Extract destination
    int? pageNumber;
    String? namedDest;
    List<dynamic>? destination;

    // Try /Dest first
    final destMatch = RegExp(r'/Dest\s*(\[[^\]]+\]|/\w+)').firstMatch(content);
    if (destMatch != null) {
      final destValue = destMatch.group(1)!;
      if (destValue.startsWith('[')) {
        destination = _parseDestArray(destValue);
        pageNumber = _resolvePageFromDest(destination);
      } else {
        namedDest = destValue.substring(1); // Remove leading /
      }
    }

    // Try /A (action) dictionary
    if (pageNumber == null) {
      final actionMatch = RegExp(r'/A\s+(\d+)\s+\d+\s+R').firstMatch(content);
      if (actionMatch != null) {
        final actionRef = int.parse(actionMatch.group(1)!);
        final actionObj = _parser.getObject(actionRef);
        if (actionObj != null) {
          final gotoDestMatch =
              RegExp(r'/D\s*(\[[^\]]+\]|/\w+)').firstMatch(actionObj.content);
          if (gotoDestMatch != null) {
            final destValue = gotoDestMatch.group(1)!;
            if (destValue.startsWith('[')) {
              destination = _parseDestArray(destValue);
              pageNumber = _resolvePageFromDest(destination);
            } else {
              namedDest = destValue.substring(1);
            }
          }
        }
      }
    }

    // Parse children
    List<PdfOutlineItem> children = [];
    final firstMatch = RegExp(r'/First\s+(\d+)\s+\d+\s+R').firstMatch(content);
    if (firstMatch != null) {
      final firstChildRef = int.parse(firstMatch.group(1)!);
      children = _parseOutlineLevel(firstChildRef);
    }

    // Parse open/closed state
    final countMatch = RegExp(r'/Count\s+(-?\d+)').firstMatch(content);
    final isOpen = countMatch == null || int.parse(countMatch.group(1)!) >= 0;

    // Parse color
    List<double>? color;
    final colorMatch = RegExp(r'/C\s*\[\s*([^\]]+)\]').firstMatch(content);
    if (colorMatch != null) {
      color = RegExp(r'[\d.]+')
          .allMatches(colorMatch.group(1)!)
          .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
          .toList();
    }

    // Parse flags
    int? flags;
    final flagsMatch = RegExp(r'/F\s+(\d+)').firstMatch(content);
    if (flagsMatch != null) {
      flags = int.parse(flagsMatch.group(1)!);
    }

    return PdfOutlineItem(
      title: title,
      pageNumber: pageNumber,
      namedDestination: namedDest,
      destination: destination,
      children: children,
      isOpen: isOpen,
      color: color,
      flags: flags,
    );
  }

  /// Extracts title string from outline item.
  String? _extractTitle(String content) {
    // Try literal string: /Title (text)
    final literalMatch = RegExp(r'/Title\s*\(([^)]*)\)').firstMatch(content);
    if (literalMatch != null) {
      return _decodeLiteralString(literalMatch.group(1)!);
    }

    // Try hex string: /Title <hex>
    final hexMatch = RegExp(r'/Title\s*<([^>]*)>').firstMatch(content);
    if (hexMatch != null) {
      return _decodeHexString(hexMatch.group(1)!);
    }

    return null;
  }

  /// Parses destination array.
  List<dynamic> _parseDestArray(String arrayStr) {
    final result = <dynamic>[];
    final clean = arrayStr.substring(1, arrayStr.length - 1).trim();

    // Extract page reference
    final pageRefMatch = RegExp(r'(\d+)\s+\d+\s+R').firstMatch(clean);
    if (pageRefMatch != null) {
      result.add(int.parse(pageRefMatch.group(1)!));
    }

    // Extract fit type
    final fitMatch = RegExp(r'/(\w+)').firstMatch(clean);
    if (fitMatch != null) {
      result.add(fitMatch.group(1)!);
    }

    // Extract numeric parameters
    final numbers = RegExp(r'(?<!\d)\d+\.?\d*(?!\s*\d*\s*R)')
        .allMatches(clean)
        .skip(pageRefMatch != null ? 1 : 0)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .toList();
    result.addAll(numbers);

    return result;
  }

  /// Resolves page number from destination.
  int? _resolvePageFromDest(List<dynamic>? dest) {
    if (dest == null || dest.isEmpty) return null;
    if (dest.first is int) {
      return _pageRefToNumber[dest.first];
    }
    return null;
  }

  /// Decodes literal string with escape sequences.
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

    // Check for UTF-16BE BOM
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

/// Named destinations in a PDF document.
class PdfNamedDestinations {
  final Map<String, List<dynamic>> _destinations = {};

  PdfNamedDestinations._();

  /// Extracts named destinations from a PDF.
  static PdfNamedDestinations extract(PdfParser parser) {
    final result = PdfNamedDestinations._();

    // Get Names dictionary from catalog
    final catalogObj = parser.getObject(parser.rootRef);
    if (catalogObj == null) return result;

    final namesMatch =
        RegExp(r'/Names\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (namesMatch == null) return result;

    final namesRef = int.parse(namesMatch.group(1)!);
    final namesObj = parser.getObject(namesRef);
    if (namesObj == null) return result;

    // Get Dests entry
    final destsMatch =
        RegExp(r'/Dests\s+(\d+)\s+\d+\s+R').firstMatch(namesObj.content);
    if (destsMatch != null) {
      final destsRef = int.parse(destsMatch.group(1)!);
      result._parseNameTree(parser, destsRef);
    }

    return result;
  }

  /// Parses a name tree.
  void _parseNameTree(PdfParser parser, int nodeRef) {
    final obj = parser.getObject(nodeRef);
    if (obj == null) return;

    // Check for Names array (leaf node)
    final namesMatch = RegExp(r'/Names\s*\[([^\]]*)\]').firstMatch(obj.content);
    if (namesMatch != null) {
      _parseNamesArray(namesMatch.group(1)!);
    }

    // Check for Kids array (intermediate node)
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (kidsMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final ref in refs) {
        _parseNameTree(parser, int.parse(ref.group(1)!));
      }
    }
  }

  /// Parses Names array content.
  void _parseNamesArray(String content) {
    // Format: (name1) [dest1] (name2) [dest2] ...
    final pattern = RegExp(r'\(([^)]+)\)\s*\[([^\]]+)\]');
    for (final match in pattern.allMatches(content)) {
      final name = match.group(1)!;
      final destArray = '[${match.group(2)!}]';
      _destinations[name] = _parseDestArray(destArray);
    }
  }

  /// Parses destination array.
  List<dynamic> _parseDestArray(String arrayStr) {
    final result = <dynamic>[];
    final clean = arrayStr.substring(1, arrayStr.length - 1).trim();

    final pageRefMatch = RegExp(r'(\d+)\s+\d+\s+R').firstMatch(clean);
    if (pageRefMatch != null) {
      result.add(int.parse(pageRefMatch.group(1)!));
    }

    final fitMatch = RegExp(r'/(\w+)').firstMatch(clean);
    if (fitMatch != null) {
      result.add(fitMatch.group(1)!);
    }

    return result;
  }

  /// Gets a named destination by name.
  List<dynamic>? getDestination(String name) => _destinations[name];

  /// All destination names.
  Iterable<String> get names => _destinations.keys;

  /// Number of named destinations.
  int get length => _destinations.length;
}
