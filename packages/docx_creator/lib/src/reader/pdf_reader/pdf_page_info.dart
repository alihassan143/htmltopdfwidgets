import 'pdf_parser.dart';

/// Represents a rectangular box in PDF coordinates.
class PdfBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const PdfBox(this.x, this.y, this.width, this.height);

  /// Creates a box from a PDF array [x, y, x2, y2].
  factory PdfBox.fromPdfArray(List<num> array) {
    if (array.length < 4) return const PdfBox(0, 0, 0, 0);
    // PDF boxes are usually [llx, lly, urx, ury]
    final x1 = array[0].toDouble();
    final y1 = array[1].toDouble();
    final x2 = array[2].toDouble();
    final y2 = array[3].toDouble();
    return PdfBox(x1, y1, (x2 - x1).abs(), (y2 - y1).abs());
  }

  @override
  String toString() => '[$x, $y, $width, $height]';
}

/// Detailed information about a PDF page.
class PdfPageInfo {
  final int pageNumber;
  final double width; // MediaBox width
  final double height; // MediaBox height
  final int rotation; // /Rotate (multiples of 90)
  final PdfBox mediaBox;
  final PdfBox? cropBox;
  final PdfBox? trimBox;
  final PdfBox? artBox;
  final PdfBox? bleedBox;

  // Extracted simple properties
  final double userUnit; // PDF 1.6 optional UserUnit

  PdfPageInfo({
    required this.pageNumber,
    required this.mediaBox,
    this.cropBox,
    this.trimBox,
    this.artBox,
    this.bleedBox,
    this.rotation = 0,
    this.userUnit = 1.0,
  })  : width = mediaBox.width * userUnit,
        height = mediaBox.height * userUnit;

  @override
  String toString() {
    return 'Page $pageNumber (${width}x$height, rot=$rotation)';
  }
}

/// Extracts page information from a PDF document.
class PdfPageInfoExtractor {
  final PdfParser parser;

  PdfPageInfoExtractor(this.parser);

  /// Extracts info for all pages.
  List<PdfPageInfo> extractAll() {
    final count = parser.countPages();
    final infos = <PdfPageInfo>[];

    // Ideally we iterate page objects. Use simple iteration for now if parser supports it.
    // If parser doesn't expose page objects by index efficiently, we might need a different approach.
    // PdfParser currently has internal generic parsing.
    // We'll trust _extractPage implementation.

    for (var i = 1; i <= count; i++) {
      final info = extractPage(i);
      if (info != null) {
        infos.add(info);
      }
    }
    return infos;
  }

  /// Extracts info for a specific page (1-based index).
  PdfPageInfo? extractPage(int pageNumber) {
    // 1. Find the page object reference
    // This is tricky without a direct page tree traversal API in PdfParser as exposed currently.
    // However, PdfParser usually scans/indexes xrefs.
    // BUT we don't have a "getPageObject(i)" in the public API shown in previous turns.
    // Let's assume we can travel the page tree or simplisticly we rely on `parser.catalog` -> `Pages` -> ...
    // Since implementing full page tree walking here might be duplicate of what PdfReader might do internally,
    // but PdfReader uses a recursive _parsePages.

    // OPTION: We'll re-implement a robust page tree walker or if PdfParser has it.
    // Checking PdfParser capabilities... based on previous file views, it had `getObject`, `pagesRef`.
    // We will do a Quick Page Walk or Linear Scan if we know the page refs.
    // But wait, `pdf_reader.dart` actually implements `_parsePages` which traverses the tree!
    // It doesn't seem to store a "page index -> object ref" map persistently for public use.

    // To properly implement `extractPage`, we ideally need that map.
    // For now, let's implement a tree walker here or use a helper if we can.
    // Given the constraints and the fact I am adding this class, I should probably implement the traversal.

    // Using `pagesRef` from parser.
    final pagesRef = parser.pagesRef;
    if (pagesRef == 0) return null;

    final root = parser.getObject(pagesRef);
    if (root == null) return null;

    // We need to find the Nth page.
    return _findPageInTree(root.content, pageNumber, Counter(0));
  }

  PdfPageInfo? _findPageInTree(
      String content, int targetPage, Counter currentCount) {
    // Check type using Regex to distinguish /Page from /Pages
    // We check for /Type /Page followed by a delimiter or end of string
    final isPage = RegExp(r'/Type\s*/Page([\s/>]|$)').hasMatch(content);

    if (isPage) {
      // This is a page
      currentCount.val++;
      if (currentCount.val == targetPage) {
        return _parsePageInfo(content, targetPage);
      }
      return null;
    }

    // It is a Pages node (or root)
    // Get Kids
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(content);
    if (kidsMatch == null) return null;

    final kidsStr = kidsMatch.group(1)!;
    final kidRefs = RegExp(r'(\d+)\s+\d+\s+R')
        .allMatches(kidsStr)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    for (final ref in kidRefs) {
      final obj = parser.getObject(ref);
      if (obj == null) continue;

      // Before recurring, we can check /Count to skip branches!
      // A Pages node should have a /Count
      final countMatch = RegExp(r'/Count\s+(\d+)').firstMatch(obj.content);
      if (countMatch != null) {
        final nodeCount = int.parse(countMatch.group(1)!);
        // Optimization: if current + nodeCount < target, skip this branch
        if (currentCount.val + nodeCount < targetPage) {
          currentCount.val += nodeCount;
          continue;
        }
      }

      // If we are here, the target page is in this branch (or it's a leaf usage)
      final result = _findPageInTree(obj.content, targetPage, currentCount);
      if (result != null) return result;
    }

    return null;
  }

  PdfPageInfo _parsePageInfo(String content, int pageNumber) {
    // 1. MediaBox (Inheritable - but we only see this node. If missing, technically should check parent...
    //    For simple implementation assume it's on page or we take default letter)

    // We need to handle inheritance if MediaBox is missing.
    // This simple implementation might miss inherited attributes.
    // However, fixing the specific error is the priority.

    final mediaBox =
        _extractBox(content, 'MediaBox') ?? const PdfBox(0, 0, 612, 792);
    final cropBox = _extractBox(content, 'CropBox');
    final trimBox = _extractBox(content, 'TrimBox');
    final artBox = _extractBox(content, 'ArtBox');
    final bleedBox = _extractBox(content, 'BleedBox');

    // Rotation
    int rotation = 0;
    final rotMatch = RegExp(r'/Rotate\s+(\d+)').firstMatch(content);
    if (rotMatch != null) {
      rotation = int.parse(rotMatch.group(1)!);
    }

    // UserUnit
    double userUnit = 1.0;
    final unitMatch = RegExp(r'/UserUnit\s+([\d\.]+)').firstMatch(content);
    if (unitMatch != null) {
      userUnit = double.tryParse(unitMatch.group(1)!) ?? 1.0;
    }

    return PdfPageInfo(
      pageNumber: pageNumber,
      mediaBox: mediaBox,
      cropBox: cropBox,
      trimBox: trimBox,
      artBox: artBox,
      bleedBox: bleedBox,
      rotation: rotation,
      userUnit: userUnit,
    );
  }

  PdfBox? _extractBox(String content, String name) {
    final match = RegExp(r'/' +
            name +
            r'\s*\[\s*([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s*\]')
        .firstMatch(content);
    if (match != null) {
      final nums = [
        double.tryParse(match.group(1)!) ?? 0,
        double.tryParse(match.group(2)!) ?? 0,
        double.tryParse(match.group(3)!) ?? 0,
        double.tryParse(match.group(4)!) ?? 0,
      ];
      return PdfBox.fromPdfArray(nums);
    }
    return null;
  }
}

class Counter {
  int val;
  Counter(this.val);
}
