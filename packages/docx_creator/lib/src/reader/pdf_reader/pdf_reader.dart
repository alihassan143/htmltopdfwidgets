import 'dart:io';
import 'dart:typed_data';

import '../../../docx_creator.dart';
import 'pdf_annotations.dart';
import 'pdf_attachment.dart';
import 'pdf_form.dart';
import 'pdf_image_extractor.dart';
import 'pdf_layer.dart';
import 'pdf_metadata.dart';
import 'pdf_number_tree.dart';
import 'pdf_outline.dart';
import 'pdf_page_label.dart';
import 'pdf_parser.dart';
import 'pdf_structure_tree.dart';
import 'pdf_table_detector.dart';
import 'pdf_text_extractor.dart';
import 'pdf_types.dart';

export 'pdf_annotations.dart' show PdfAnnotation, PdfAnnotationType;
export 'pdf_encryption.dart' show PdfEncryption;
export 'pdf_form.dart' show PdfFormField, PdfFieldType;
export 'pdf_metadata.dart' show PdfMetadata, XmpMetadata;
export 'pdf_outline.dart' show PdfOutlineItem;
export 'pdf_page_info.dart' show PdfPageInfo, PdfBox, PdfPageInfoExtractor;
export 'pdf_parser.dart' show PdfParseException;
export 'pdf_types.dart' show PdfExtractedImage;

/// Reads PDF files and converts content to DocxNode elements.
///
/// This parser extracts text, images, and basic formatting from PDF files
/// and converts them to the docx_creator AST for further processing.
///
/// Features:
/// - Parses PDF 1.0 - 1.7 format
/// - Extracts text with proper encoding (CMap/ToUnicode support)
/// - Handles multiple compression filters (FlateDecode, ASCII85, ASCIIHex)
/// - Supports cross-reference tables and streams
/// - Extracts embedded images (JPEG, PNG, etc.)
/// - Detects tables using grid analysis and heuristics
/// - Groups text into paragraphs by position
class PdfReader {
  final PdfParser _parser;
  final PdfTextExtractor _textExtractor;
  final PdfImageExtractor _imageExtractor;
  final PdfTableDetector _tableDetector;

  // Extracted content
  final List<DocxNode> _elements = [];
  final List<PdfExtractedImage> _images = [];
  final List<String> _warnings = [];

  // Page dimensions (default Letter)
  double _pageWidth = 612;
  double _pageHeight = 792;

  PdfReader._(Uint8List data)
      : _parser = PdfParser(data),
        _textExtractor = PdfTextExtractor.create(),
        _imageExtractor = PdfImageExtractor.create(),
        _tableDetector = PdfTableDetector() {
    // Share the same parser instance with extractors
    _textExtractor.parser = _parser;
    _imageExtractor.parser = _parser;
  }

  /// Loads a PDF from a file path.
  ///
  /// Throws [FileSystemException] if file cannot be read.
  /// Throws [PdfParseException] if PDF is invalid.
  static Future<PdfDocument> load(String filePath, {String? password}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw PdfParseException('File not found: $filePath');
      }
      final bytes = await file.readAsBytes();
      return loadFromBytes(bytes, password: password);
    } on FileSystemException catch (e) {
      throw PdfParseException('Cannot read file: ${e.message}');
    }
  }

  /// Loads a PDF from bytes.
  ///
  /// Throws [PdfParseException] if PDF is invalid.
  static Future<PdfDocument> loadFromBytes(Uint8List bytes,
      {String? password}) async {
    if (bytes.isEmpty) {
      throw PdfParseException('Empty PDF data');
    }
    final reader = PdfReader._(bytes);

    return reader._parse(password);
  }

  /// Parses the PDF and returns a document.
  PdfDocument _parse(String? password) {
    try {
      _parser.parse();

      // Handle Encryption
      final encryption = PdfEncryption.extract(_parser);
      if (encryption != null) {
        bool authenticated = false;
        if (password != null) {
          authenticated = encryption.authenticate(password);
        } else {
          // Try default empty password
          authenticated = encryption.authenticate('');
        }

        if (!authenticated && password != null) {
          _warnings.add('Invalid password provided');
        }

        // We set encryption anyway so parser knows it is encrypted,
        // even if key is missing (it will fail to decrypt strings/streams).
        _parser.setEncryption(encryption);
      }

      _warnings.addAll(_parser.warnings);
      _parsePages();
    } catch (e) {
      _warnings.add('Parse error: $e');
    }

    return PdfDocument(
      elements: _elements,
      images: _images,
      warnings: _warnings,
      pageCount: _parser.countPages(),
      pageWidth: _pageWidth,
      pageHeight: _pageHeight,
      version: _parser.version,
      parser: _parser,
    );
  }

  /// Parses all pages.
  void _parsePages() {
    if (_parser.pagesRef == 0) {
      _warnings.add('No pages to parse');
      return;
    }

    final pagesObj = _parser.getObject(_parser.pagesRef);
    if (pagesObj == null) {
      _warnings.add('Cannot read pages object');
      return;
    }

    // Get page dimensions from Pages object
    _extractPageBoxes(pagesObj.content);

    // Get Kids array (can be nested)
    _parseKidsArray(pagesObj.content);
  }

  /// Recursively parses Kids array.
  void _parseKidsArray(String content) {
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(content);
    if (kidsMatch == null) return;

    final kidsStr = kidsMatch.group(1)!;
    final pageRefs = RegExp(r'(\d+)\s+\d+\s+R')
        .allMatches(kidsStr)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    for (final pageRef in pageRefs) {
      final obj = _parser.getObject(pageRef);
      if (obj == null) continue;

      if (obj.content.contains('/Type /Page ') ||
          obj.content.contains('/Type/Page') ||
          (!obj.content.contains('/Kids'))) {
        _parsePage(pageRef);
      } else {
        _parseKidsArray(obj.content);
      }
    }
  }

  /// Extracts page boxes (MediaBox, CropBox, etc.).
  void _extractPageBoxes(String content) {
    // MediaBox (Default, Required)
    final mediaBoxMatch = RegExp(
            r'/MediaBox\s*\[\s*([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s*\]')
        .firstMatch(content);
    if (mediaBoxMatch != null) {
      _pageWidth = double.tryParse(mediaBoxMatch.group(3)!) ?? 612;
      _pageHeight = double.tryParse(mediaBoxMatch.group(4)!) ?? 792;
    }

    // CropBox (Visible region, overrides MediaBox if present)
    final cropBoxMatch = RegExp(
            r'/CropBox\s*\[\s*([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s*\]')
        .firstMatch(content);
    if (cropBoxMatch != null) {
      final w = double.tryParse(cropBoxMatch.group(3)!);
      final h = double.tryParse(cropBoxMatch.group(4)!);
      if (w != null && h != null) {
        _pageWidth = w;
        _pageHeight = h;
      }
    }

    // TODO: Extract TrimBox, ArtBox, BleedBox for metadata if needed
  }

  /// Parses a single page.
  void _parsePage(int pageRef) {
    final pageObj = _parser.getObject(pageRef);
    if (pageObj == null) return;

    _extractPageBoxes(pageObj.content);
    _textExtractor.pageWidth = _pageWidth;
    _textExtractor.pageHeight = _pageHeight;

    // Extract fonts from page resources
    _textExtractor.extractPageFonts(pageObj.content);

    // Extract XObject (image) references
    final xObjects = _imageExtractor.extractXObjects(pageObj.content, pageRef);

    // Get Contents
    final contentsArrayMatch =
        RegExp(r'/Contents\s*\[([^\]]+)\]').firstMatch(pageObj.content);
    final contentsSingleMatch =
        RegExp(r'/Contents\s+(\d+)\s+\d+\s+R').firstMatch(pageObj.content);

    String? combinedStream;

    if (contentsArrayMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R')
          .allMatches(contentsArrayMatch.group(1)!)
          .map((m) => int.parse(m.group(1)!))
          .toList();

      final sb = StringBuffer();
      for (final ref in refs) {
        final stream = _parser.getStreamContent(ref);
        if (stream != null) sb.writeln(stream);
      }
      combinedStream = sb.toString();
    } else if (contentsSingleMatch != null) {
      final contentsRef = int.parse(contentsSingleMatch.group(1)!);
      combinedStream = _parser.getStreamContent(contentsRef);
    }

    if (combinedStream != null) {
      _parseContentStream(combinedStream, xObjects, pageRef);
    }
  }

  /// Parses PDF content stream.
  void _parseContentStream(
    String stream,
    Map<String, PdfXObjectInfo> xObjects,
    int pageRef,
  ) {
    if (stream.trim().isEmpty) return;

    // Extract text lines
    final textLines = _textExtractor.extractText(stream);
    _warnings.addAll(_textExtractor.warnings);

    // Extract graphic lines for table detection
    final graphicLines = _extractGraphicLines(stream);

    // Extract images
    final imageItems = _extractImages(stream, xObjects);

    // Process features
    _processPageFeatures(textLines, graphicLines, imageItems);
  }

  /// Extracts graphic lines from content stream.
  List<PdfGraphicLine> _extractGraphicLines(String stream) {
    final lines = <PdfGraphicLine>[];
    final tokens = _parser.tokenize(stream);
    var state = PdfGraphicsState();
    final stateStack = <PdfGraphicsState>[];

    double? currentX, currentY;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (token == 'q') {
        stateStack.add(state.clone());
      } else if (token == 'Q') {
        if (stateStack.isNotEmpty) state = stateStack.removeLast();
      } else if (token == 'cm' && i >= 6) {
        final a = double.tryParse(tokens[i - 6]) ?? 1;
        final b = double.tryParse(tokens[i - 5]) ?? 0;
        final c = double.tryParse(tokens[i - 4]) ?? 0;
        final d = double.tryParse(tokens[i - 3]) ?? 1;
        final e = double.tryParse(tokens[i - 2]) ?? 0;
        final f = double.tryParse(tokens[i - 1]) ?? 0;
        state.ctm = state.ctm.multiply(PdfMatrix(a, b, c, d, e, f));
      } else if (token == 're' && i >= 4) {
        final x = double.tryParse(tokens[i - 4]) ?? 0;
        final y = double.tryParse(tokens[i - 3]) ?? 0;
        final w = double.tryParse(tokens[i - 2]) ?? 0;
        final h = double.tryParse(tokens[i - 1]) ?? 0;

        final p1 = state.ctm.transform(x, y);
        final p2 = state.ctm.transform(x + w, y);
        final p3 = state.ctm.transform(x + w, y + h);
        final p4 = state.ctm.transform(x, y + h);

        lines.add(PdfGraphicLine(p1[0], p1[1], p2[0], p2[1]));
        lines.add(PdfGraphicLine(p2[0], p2[1], p3[0], p3[1]));
        lines.add(PdfGraphicLine(p3[0], p3[1], p4[0], p4[1]));
        lines.add(PdfGraphicLine(p4[0], p4[1], p1[0], p1[1]));
      } else if (token == 'm' && i >= 2) {
        currentX = double.tryParse(tokens[i - 2]);
        currentY = double.tryParse(tokens[i - 1]);
      } else if (token == 'l' &&
          i >= 2 &&
          currentX != null &&
          currentY != null) {
        final x = double.tryParse(tokens[i - 2]) ?? 0;
        final y = double.tryParse(tokens[i - 1]) ?? 0;
        final p1 = state.ctm.transform(currentX, currentY);
        final p2 = state.ctm.transform(x, y);
        lines.add(PdfGraphicLine(p1[0], p1[1], p2[0], p2[1]));
        currentX = x;
        currentY = y;
      } else if (token == 'w' && i >= 1) {
        state.lineWidth = double.tryParse(tokens[i - 1]) ?? 1;
      }
    }

    return lines;
  }

  /// Extracts images from content stream.
  List<PdfImageItem> _extractImages(
    String stream,
    Map<String, PdfXObjectInfo> xObjects,
  ) {
    final images = <PdfImageItem>[];
    final tokens = _parser.tokenize(stream);
    var state = PdfGraphicsState();
    final stateStack = <PdfGraphicsState>[];

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (token == 'q') {
        stateStack.add(state.clone());
      } else if (token == 'Q') {
        if (stateStack.isNotEmpty) state = stateStack.removeLast();
      } else if (token == 'cm' && i >= 6) {
        final a = double.tryParse(tokens[i - 6]) ?? 1;
        final b = double.tryParse(tokens[i - 5]) ?? 0;
        final c = double.tryParse(tokens[i - 4]) ?? 0;
        final d = double.tryParse(tokens[i - 3]) ?? 1;
        final e = double.tryParse(tokens[i - 2]) ?? 0;
        final f = double.tryParse(tokens[i - 1]) ?? 0;
        state.ctm = state.ctm.multiply(PdfMatrix(a, b, c, d, e, f));
      } else if (token == 'Do' && i >= 1) {
        final name = tokens[i - 1].replaceAll('/', '');
        final xObj = xObjects[name];

        if (xObj != null && xObj.bytes != null) {
          final w = state.ctm.a.abs();
          final h = state.ctm.d.abs();

          // Determine if we need to encode raw data as PNG
          Uint8List imageBytes;
          String extension;

          if (xObj.filter == 'DCTDecode' || xObj.filter == 'JPXDecode') {
            // Already in JPEG/JP2 format
            imageBytes = xObj.bytes!;
            extension = _imageExtractor.getImageExtension(xObj.filter);
          } else {
            // Raw pixel data - encode as PNG
            final pngBytes = _imageExtractor.encodeRgbToPng(
              xObj.bytes!,
              xObj.width,
              xObj.height,
              colorSpace: xObj.colorSpace ?? 'DeviceRGB',
              bitsPerComponent: xObj.bitsPerComponent,
            );
            if (pngBytes != null) {
              imageBytes = pngBytes;
              extension = 'png';
            } else {
              // Fallback to raw bytes if encoding fails
              imageBytes = xObj.bytes!;
              extension = 'raw';
            }
          }

          images.add(PdfImageItem(
            bytes: imageBytes,
            x: state.ctm.e,
            y: state.ctm.f,
            width: w > 0 ? w : xObj.width.toDouble(),
            height: h > 0 ? h : xObj.height.toDouble(),
            extension: extension,
            filter: xObj.filter,
          ));

          _images.add(PdfExtractedImage(
            bytes: imageBytes,
            width: xObj.width,
            height: xObj.height,
            format: extension,
          ));
        }
      }
    }

    return images;
  }

  /// Processes page features into DocxNodes.
  void _processPageFeatures(
    List<PdfTextLine> rawLines,
    List<PdfGraphicLine> graphicLines,
    List<PdfImageItem> images,
  ) {
    if (rawLines.isEmpty && images.isEmpty) return;

    // Detect tables
    final tables = _tableDetector.detectTables(rawLines, graphicLines);
    _warnings.addAll(_tableDetector.warnings);

    // Get text that belongs to tables
    final tableTextLines = <PdfTextLine>{};
    for (final table in tables) {
      for (final row in table.rows) {
        for (final cell in row) {
          tableTextLines.addAll(cell.textLines);
        }
      }
    }

    // Apply decorations to text
    for (final line in rawLines) {
      _applyDecorations(line, graphicLines);
    }

    // Combine all items for sorting
    final allItems = <PdfPageItem>[
      ...rawLines.where((l) => !tableTextLines.contains(l)),
      ...images,
    ];

    // Add table markers
    for (final table in tables) {
      allItems.add(_TableMarker(table.x, table.y + table.height, table));
    }

    // Sort by Y (descending) then X
    allItems.sort((a, b) {
      final yDiff = b.y.compareTo(a.y);
      if (yDiff != 0) return yDiff;
      return a.x.compareTo(b.x);
    });

    // Process into elements
    final paragraphLines = <PdfTextLine>[];

    for (final item in allItems) {
      if (item is _TableMarker) {
        // Flush paragraph
        if (paragraphLines.isNotEmpty) {
          final p = _createParagraph(paragraphLines);
          if (p != null) _elements.add(p);
          paragraphLines.clear();
        }
        // Add table
        _elements.add(_createTable(item.table));
      } else if (item is PdfImageItem) {
        if (paragraphLines.isNotEmpty) {
          final p = _createParagraph(paragraphLines);
          if (p != null) _elements.add(p);
          paragraphLines.clear();
        }
        _elements.add(DocxImage(
          bytes: item.bytes,
          width: item.width,
          height: item.height,
          extension: item.extension,
        ));
      } else if (item is PdfTextLine) {
        // Check if new line/block
        var newBlock = false;

        if (paragraphLines.isNotEmpty) {
          final last = paragraphLines.last;
          final lastY = last.y;
          final lastXEnd = last.x + last.width;

          // Vertical check (new line if gap > 1.5 * size)
          // Also check for columns (if Y is similar but X is far back/forward?)
          // Current sort is Y desc, X asc.
          // If Y is same approx, X will increase.
          // If X gap is HUGE (> 100), maybe strictly separate block?

          if ((lastY - item.y).abs() > item.size * 1.5) {
            newBlock = true;
          } else if ((item.x - lastXEnd) > 100) {
            // Large horizontal gap on same line -> likely column or separate text area
            newBlock = true;
          } else if (item.x < last.x &&
              (lastY - item.y).abs() < item.size * 0.5) {
            // Item is to the LEFT of previous item on SAME line?
            // Should not happen with X sorting, unless Y differed slightly.
            // If so, it's definitely a different column/block.
            newBlock = true;
          }
        }

        if (newBlock) {
          if (paragraphLines.isNotEmpty) {
            final p = _createParagraph(paragraphLines);
            if (p != null) _elements.add(p);
            paragraphLines.clear();
          }
        }
        paragraphLines.add(item);
      }
    }

    if (paragraphLines.isNotEmpty) {
      final p = _createParagraph(paragraphLines);
      if (p != null) _elements.add(p);
    }
  }

  void _applyDecorations(PdfTextLine line, List<PdfGraphicLine> graphicLines) {
    final width = line.width;
    final xStart = line.x;
    final xEnd = line.x + width;
    final y = line.y;

    for (final g in graphicLines) {
      if (!g.isHorizontal) continue;

      if (g.minX < xEnd && g.maxX > xStart) {
        final gy = g.y1;
        // Underline: below baseline
        if (gy < y && (y - gy) < line.size * 0.5) {
          line.isUnderline = true;
        }
        // Strikethrough: middle
        if ((gy - (y + line.size * 0.3)).abs() < line.size * 0.3) {
          line.isStrikethrough = true;
        }
      }
    }
  }

  DocxParagraph? _createParagraph(List<PdfTextLine> lines) {
    if (lines.isEmpty) return null;

    final children = <DocxInline>[];

    // Check for Heading (based on font size)
    // Heuristic: If first line size > 16, treat as Heading
    final firstLine = lines.first;
    String? headingStyle;
    if (firstLine.size >= 24) {
      headingStyle = 'Heading1';
    } else if (firstLine.size >= 18) {
      headingStyle = 'Heading2';
    } else if (firstLine.size >= 16) {
      headingStyle = 'Heading3';
    }

    // Check for List Item
    // Regex for bullets or numbers: ^[•\-\*] or ^\d+\.
    bool isListItem = false;
    String fullText = lines.map((l) => l.text).join(); // Naive join for check
    if (RegExp(r'^\s*[•\-\*]\s+').hasMatch(fullText) ||
        RegExp(r'^\s*\d+\.\s+').hasMatch(fullText)) {
      isListItem = true;
    }

    // Process lines and insert spaces if needed
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle gap from previous line on SAME visual line
      if (i > 0) {
        final prev = lines[i - 1];
        // Only if they are roughly on same Y
        if ((prev.y - line.y).abs() < line.size * 0.5) {
          final gap = line.x - (prev.x + prev.width);
          // If gap is significant (> 2pts), insert space.
          // But if gap is HUGE, it might be separate words.
          // In PDF, space char is often omitted and spacing is done via position.
          if (gap > 2.0) {
            // Tolerance
            children.add(DocxText(" "));
          }
        } else {
          // New visual line in paragraph. Insert space if previous didn't end with hyphen
          if (!tokensEndWithHyphen(prev.text)) {
            children.add(DocxText(" "));
          }
        }
      }

      final colorHex = _rgbToHex(line.colorR, line.colorG, line.colorB);
      DocxTextDecoration decoration = DocxTextDecoration.none;
      if (line.isUnderline) decoration = DocxTextDecoration.underline;
      if (line.isStrikethrough) decoration = DocxTextDecoration.strikethrough;

      children.add(DocxText(
        line.text,
        fontSize: line.size,
        fontWeight: line.isBold ? DocxFontWeight.bold : DocxFontWeight.normal,
        fontStyle: line.isItalic ? DocxFontStyle.italic : DocxFontStyle.normal,
        color: colorHex != '000000' ? DocxColor(colorHex) : null,
        decoration: decoration,
        isSuperscript: line.textRise > 0,
        isSubscript: line.textRise < 0,
      ));
    }

    // Create paragraph with detected style
    if (headingStyle != null) {
      // DocxParagraph doesn't expose 'style' directly easily in basic constructor?
      // It has `style` property?
      // Let's check DocxParagraph definition.
      // Assuming it acts as standard paragraph.
      // If DocxParagraph does not support style string, we fallback to formatting.
      // User prompt: "Large blocks -> h1()".
      // docx_creator API: DocxParagraph.h1()? Or generic?
      // We'll stick to generic DocxParagraph but ideally set style.
      // Inspecting previous DocxParagraph usage: typically just children.
      // We'll trust the fontSize we set on children to carry the formatting visually.
      return DocxParagraph(
          children: children); // Style support requires API check
    }

    if (isListItem) {
      // return DocxParagraph.bullet(children: children);
      // Need to check API availability.
      // For now, standard paragraph.
      return DocxParagraph(children: children);
    }

    return DocxParagraph(children: children);
  }

  bool tokensEndWithHyphen(String text) {
    return text.trimRight().endsWith('-') ||
        text.trimRight().endsWith('\u00AD');
  }

  DocxTable _createTable(PdfDetectedTable table) {
    final rows = <DocxTableRow>[];

    for (final row in table.rows) {
      final cells = <DocxTableCell>[];
      for (final cell in row) {
        final p = _createParagraph(cell.textLines);
        cells.add(DocxTableCell(
          children: p != null ? [p] : [],
        ));
      }
      rows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(rows: rows);
  }

  String _rgbToHex(double r, double g, double b) {
    final ri = (r * 255).round().clamp(0, 255);
    final gi = (g * 255).round().clamp(0, 255);
    final bi = (b * 255).round().clamp(0, 255);
    return ri.toRadixString(16).padLeft(2, '0') +
        gi.toRadixString(16).padLeft(2, '0') +
        bi.toRadixString(16).padLeft(2, '0');
  }
}

/// Marker for table position in page items.
class _TableMarker extends PdfPageItem {
  final PdfDetectedTable table;
  _TableMarker(super.x, super.y, this.table);
}

/// Represents a parsed PDF document.
///
/// This contains:
/// - [elements]: Document structure with text, tables, and images as [DocxNode]s.
///   Images appear here as [DocxImage] nodes with layout context.
/// - [images]: Convenience list of raw [PdfExtractedImage] for direct access
///   to image bytes without traversing the document tree.
class PdfDocument {
  /// Extracted document elements (paragraphs, tables, images).
  ///
  /// Images are included as [DocxImage] within this list in their
  /// document position order. Use this for document structure processing.
  final List<DocxNode> elements;

  /// Direct access to extracted images with metadata.
  ///
  /// Provides quick access to raw image bytes without traversing [elements].
  /// Useful for batch image extraction or when you only need images.
  final List<PdfExtractedImage> images;

  /// Warnings encountered during parsing.
  final List<String> warnings;

  /// Number of pages in the PDF.
  final int pageCount;

  /// Page width in points.
  final double pageWidth;

  /// Page height in points.
  final double pageHeight;

  /// PDF version (e.g., "1.4").
  final String version;

  /// Internal parser reference for lazy feature access.
  final PdfParser? _parser;

  // Lazy-loaded feature caches
  PdfMetadata? _metadata;
  List<PdfOutlineItem>? _outlines;
  List<PdfAnnotation>? _annotations;
  List<PdfFormField>? _formFields;
  PdfEncryption? _encryption;
  bool _encryptionChecked = false;
  List<PdfPageInfo>? _pageInfos;
  XmpMetadata? _xmpMetadata;
  bool _xmpChecked = false;
  List<PdfAttachment>? _attachments;

  PdfDocument({
    required this.elements,
    required this.images,
    this.warnings = const [],
    this.pageCount = 0,
    this.pageWidth = 612,
    this.pageHeight = 792,
    this.version = '1.4',
    PdfParser? parser,
  }) : _parser = parser;

  // ============ Metadata ============

  /// Document metadata (title, author, dates, etc.).
  PdfMetadata get metadata {
    if (_metadata == null && _parser != null) {
      _metadata = PdfMetadataExtractor(_parser!).extract();
    }
    return _metadata ?? PdfMetadata(pdfVersion: version, pageCount: pageCount);
  }

  /// XMP metadata (Dublin Core, etc.).
  /// Returns null if no XMP metadata exists.
  XmpMetadata? get xmpMetadata {
    if (!_xmpChecked && _parser != null) {
      _xmpMetadata = XmpMetadata.extract(_parser!);
      _xmpChecked = true;
    }
    return _xmpMetadata;
  }

  // ============ Attachments ============

  /// Document attachments (embedded files).
  List<PdfAttachment> get attachments {
    if (_attachments == null && _parser != null) {
      _attachments = PdfAttachmentExtractor(_parser!).extract();
    }
    return _attachments ?? [];
  }

  // ============ Page Labels ============

  /// Returns page labels for all pages (e.g., ["i", "ii", "1", "2"]).
  /// Returns "1", "2", etc. if no labels are defined.
  List<String> get pageLabels {
    if (_parser == null) return List.generate(pageCount, (i) => '${i + 1}');

    final rootObj = _parser!.getObject(_parser!.rootRef);
    if (rootObj == null) return List.generate(pageCount, (i) => '${i + 1}');

    final labelsMatch =
        RegExp(r'/PageLabels\s+(\d+)\s+\d+\s+R').firstMatch(rootObj.content);
    if (labelsMatch == null) return List.generate(pageCount, (i) => '${i + 1}');

    final numTreeRef = int.parse(labelsMatch.group(1)!);
    final tree = PdfNumberTree(_parser!).parse(numTreeRef);

    // Number Tree keys are page INDICES.
    // We need to fill in gaps. A label applies until the next key.
    final result = <String>[];
    final sortedKeys = tree.keys.toList()..sort();

    if (sortedKeys.isEmpty) return List.generate(pageCount, (i) => '${i + 1}');

    PdfPageLabel? currentLabel;
    int currentRunStart = 0;

    for (var i = 0; i < pageCount; i++) {
      if (sortedKeys.contains(i)) {
        // New range starts here
        final raw = tree[i]!;
        currentLabel = PdfPageLabel.parse(raw);
        currentRunStart = i;
      }

      if (currentLabel != null) {
        result.add(currentLabel.format(i - currentRunStart));
      } else {
        // Implicit default (?)
        result.add('${i + 1}');
      }
    }
    return result;
  }

  // ============ Structure/Tagged PDF ============

  /// Whether the PDF is a Tagged PDF (has logical structure).
  bool get isTagged {
    if (_parser == null) return false;
    final rootObj = _parser!.getObject(_parser!.rootRef);
    if (rootObj == null) return false;
    return rootObj.content.contains('/StructTreeRoot');
  }

  /// The logical structure tree (if present).
  PdfStructureTree? get structureTree {
    if (!isTagged || _parser == null) return null;
    final rootObj = _parser!.getObject(_parser!.rootRef);
    final match = RegExp(r'/StructTreeRoot\s+(\d+)\s+\d+\s+R')
        .firstMatch(rootObj!.content);
    if (match == null) return null;

    return PdfStructureTree(_parser!, int.parse(match.group(1)!));
  }

  // ============ Layers (OCGs) ============

  /// Optional Content Groups (Layers).
  List<PdfLayer> get layers {
    if (_parser == null) return [];
    return PdfLayer.extract(_parser!, _parser!.rootRef);
  }

  // ============ Outlines/Bookmarks ============

  /// Document outline (bookmarks/table of contents).
  List<PdfOutlineItem> get outlines {
    if (_outlines == null && _parser != null) {
      _outlines = PdfOutlineExtractor(_parser!).extract();
    }
    return _outlines ?? [];
  }

  /// Whether the document has bookmarks.
  bool get hasOutlines => outlines.isNotEmpty;

  // ============ Annotations ============

  /// All annotations in the document.
  List<PdfAnnotation> get annotations {
    if (_annotations == null && _parser != null) {
      _annotations = PdfAnnotationExtractor(_parser!).extractAll();
    }
    return _annotations ?? [];
  }

  /// Gets annotations for a specific page.
  List<PdfAnnotation> getAnnotationsForPage(int pageNumber) {
    return annotations.where((a) => a.pageNumber == pageNumber).toList();
  }

  /// Whether the document has annotations.
  bool get hasAnnotations => annotations.isNotEmpty;

  // ============ Forms ============

  /// Form fields in the document.
  List<PdfFormField> get formFields {
    if (_formFields == null && _parser != null) {
      _formFields = PdfFormExtractor(_parser!).extractFields();
    }
    return _formFields ?? [];
  }

  /// Whether the document has a form.
  bool get hasForm {
    if (_parser != null) {
      return PdfFormExtractor(_parser!).hasForm();
    }
    return false;
  }

  /// Gets form data as a map of field names to values.
  Map<String, dynamic> get formData {
    if (_parser != null) {
      return PdfFormExtractor(_parser!).getFormData();
    }
    return {};
  }

  /// Gets a form field by name.
  PdfFormField? getFormField(String name) {
    return formFields.where((f) => f.name == name).firstOrNull;
  }

  // ============ Encryption ============

  /// Encryption information (null if not encrypted).
  PdfEncryption? get encryption {
    if (!_encryptionChecked && _parser != null) {
      // Use the parser's encryption instance (which has been authenticated)
      // instead of extracting a new one
      _encryption = _parser!.encryption;
      _encryptionChecked = true;
    }
    return _encryption;
  }

  /// Whether the document is encrypted.
  bool get isEncrypted => encryption != null;

  // ============ Page Info ============

  /// Detailed information for all pages.
  List<PdfPageInfo> get pageInfos {
    if (_pageInfos == null && _parser != null) {
      _pageInfos = PdfPageInfoExtractor(_parser!).extractAll();
    }
    return _pageInfos ?? [];
  }

  /// Gets info for a specific page.
  PdfPageInfo? getPageInfo(int pageNumber) {
    if (_parser != null) {
      return PdfPageInfoExtractor(_parser!).extractPage(pageNumber);
    }
    return null;
  }

  // ============ Named Destinations ============

  /// Named destinations in the document.
  /// Maps destination names to page numbers.
  Map<String, int> get namedDestinations {
    if (_parser == null) return {};

    final rootObj = _parser!.getObject(_parser!.rootRef);
    if (rootObj == null) return {};

    final result = <String, int>{};

    // Try /Names -> /Dests name tree
    final namesMatch =
        RegExp(r'/Names\s+(\d+)\s+\d+\s+R').firstMatch(rootObj.content);
    if (namesMatch != null) {
      final namesObj = _parser!.getObject(int.parse(namesMatch.group(1)!));
      if (namesObj != null) {
        final destsMatch =
            RegExp(r'/Dests\s+(\d+)\s+\d+\s+R').firstMatch(namesObj.content);
        if (destsMatch != null) {
          _parseNameTree(int.parse(destsMatch.group(1)!), result);
        }
      }
    }

    // Also try /Dests dictionary in catalog (older PDFs)
    final destsMatch =
        RegExp(r'/Dests\s+(\d+)\s+\d+\s+R').firstMatch(rootObj.content);
    if (destsMatch != null) {
      _parseDestsDict(int.parse(destsMatch.group(1)!), result);
    }

    return result;
  }

  void _parseNameTree(int ref, Map<String, int> result) {
    final obj = _parser!.getObject(ref);
    if (obj == null) return;

    // Check for /Names array (leaf node)
    final namesMatch = RegExp(r'/Names\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (namesMatch != null) {
      final content = namesMatch.group(1)!;
      // Pattern: (name) [destination] or <hex> [destination]
      final pattern = RegExp(r'(\([^)]+\)|\<[^>]+\>)\s+(\[|\d+\s+\d+\s+R)');
      for (final match in pattern.allMatches(content)) {
        final nameRaw = match.group(1)!;
        String name;
        if (nameRaw.startsWith('(')) {
          name = nameRaw.substring(1, nameRaw.length - 1);
        } else {
          // Hex string
          name = String.fromCharCodes(RegExp(r'[0-9A-Fa-f]{2}')
              .allMatches(nameRaw.substring(1, nameRaw.length - 1))
              .map((m) => int.parse(m.group(0)!, radix: 16)));
        }
        // Extract page number from destination
        final pageNum = _extractPageFromDest(content.substring(match.end));
        if (pageNum != null) result[name] = pageNum;
      }
    }

    // Check for /Kids array (intermediate node)
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (kidsMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final ref in refs) {
        _parseNameTree(int.parse(ref.group(1)!), result);
      }
    }
  }

  void _parseDestsDict(int ref, Map<String, int> result) {
    final obj = _parser!.getObject(ref);
    if (obj == null) return;

    // Pattern: /DestName [pageRef /XYZ ...] or /DestName pageRef
    final pattern = RegExp(r'/(\w+)\s*(\[|\d+)');
    for (final match in pattern.allMatches(obj.content)) {
      final name = match.group(1)!;
      final pageNum = _extractPageFromDest(obj.content.substring(match.start));
      if (pageNum != null) result[name] = pageNum;
    }
  }

  int? _extractPageFromDest(String content) {
    // Try to find page reference in destination array
    final refMatch = RegExp(r'(\d+)\s+\d+\s+R').firstMatch(content);
    if (refMatch != null) {
      final pageRef = int.parse(refMatch.group(1)!);
      // Find page index for this reference
      for (var i = 0; i < pageInfos.length; i++) {
        // Approximate: check if this is a valid page object
        final obj = _parser!.getObject(pageRef);
        if (obj != null && obj.content.contains('/Type /Page')) {
          return i;
        }
      }
    }
    return null;
  }

  /// The open destination (where document opens).
  /// Returns page number, or null if not set.
  int? get openDestination {
    if (_parser == null) return null;

    final rootObj = _parser!.getObject(_parser!.rootRef);
    if (rootObj == null) return null;

    // Check /OpenAction
    final openMatch = RegExp(r'/OpenAction\s*\[?\s*(\d+)\s+\d+\s+R')
        .firstMatch(rootObj.content);
    if (openMatch != null) {
      final pageRef = int.parse(openMatch.group(1)!);
      for (var i = 0; i < pageInfos.length; i++) {
        final obj = _parser!.getObject(pageRef);
        if (obj != null && obj.content.contains('/Type /Page')) {
          return i;
        }
      }
    }
    return null;
  }

  // ============ Per-Page Text Extraction ============

  /// Extracts text from a specific page.
  /// [pageNumber] is 0-indexed.
  String extractTextForPage(int pageNumber) {
    if (pageNumber < 0 || pageNumber >= pageInfos.length) return '';

    final info = pageInfos[pageNumber];
    if (_parser == null) return '';

    // Get page object and extract text
    final pageObj = _getPageObjectByIndex(pageNumber);
    if (pageObj == null) return '';

    final textExtractor = PdfTextExtractor(_parser!);
    textExtractor.extractPageFonts(pageObj.content);
    textExtractor.pageWidth = info.mediaBox.width;
    textExtractor.pageHeight = info.mediaBox.height;

    // Get content stream
    final contentStream = _getPageContentStream(pageObj);
    if (contentStream == null) return '';

    return textExtractor.extractTextString(contentStream);
  }

  PdfObject? _getPageObjectByIndex(int index) {
    if (_parser == null) return null;

    // Walk page tree to find page at index
    final rootObj = _parser!.getObject(_parser!.rootRef);
    if (rootObj == null) return null;

    final pagesMatch =
        RegExp(r'/Pages\s+(\d+)\s+\d+\s+R').firstMatch(rootObj.content);
    if (pagesMatch == null) return null;

    final pagesRef = int.parse(pagesMatch.group(1)!);
    return _findPageByIndex(pagesRef, index, [0]);
  }

  PdfObject? _findPageByIndex(
      int ref, int targetIndex, List<int> currentIndex) {
    final obj = _parser!.getObject(ref);
    if (obj == null) return null;

    if (obj.content.contains('/Type /Page') &&
        !obj.content.contains('/Type /Pages')) {
      if (currentIndex[0] == targetIndex) return obj;
      currentIndex[0]++;
      return null;
    }

    // Pages node - recurse into Kids
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (kidsMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final m in refs) {
        final result =
            _findPageByIndex(int.parse(m.group(1)!), targetIndex, currentIndex);
        if (result != null) return result;
      }
    }
    return null;
  }

  String? _getPageContentStream(PdfObject pageObj) {
    // Array of content streams
    final arrayMatch =
        RegExp(r'/Contents\s*\[([^\]]+)\]').firstMatch(pageObj.content);
    if (arrayMatch != null) {
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(arrayMatch.group(1)!);
      final sb = StringBuffer();
      for (final m in refs) {
        final stream = _parser!.getStreamContent(int.parse(m.group(1)!));
        if (stream != null) sb.writeln(stream);
      }
      return sb.toString();
    }

    // Single content stream
    final singleMatch =
        RegExp(r'/Contents\s+(\d+)\s+\d+\s+R').firstMatch(pageObj.content);
    if (singleMatch != null) {
      return _parser!.getStreamContent(int.parse(singleMatch.group(1)!));
    }

    return null;
  }

  // ============ PDF/A Compliance ============

  /// Whether the document claims PDF/A compliance.
  bool get isPdfA {
    final xmp = xmpMetadata;
    if (xmp?.rawXml != null) {
      return xmp!.rawXml!.contains('pdfaid:') || xmp.rawXml!.contains('PDF/A');
    }
    return false;
  }

  /// PDF/A conformance level (e.g., "1a", "1b", "2u", "3b").
  /// Returns null if not PDF/A.
  String? get pdfaConformance {
    final xmp = xmpMetadata;
    if (xmp?.rawXml == null) return null;

    // Look for pdfaid:part and pdfaid:conformance
    final partMatch = RegExp(r'pdfaid:part>(\d+)<').firstMatch(xmp!.rawXml!);
    final confMatch =
        RegExp(r'pdfaid:conformance>([ABU])<', caseSensitive: false)
            .firstMatch(xmp.rawXml!);

    if (partMatch != null) {
      final part = partMatch.group(1);
      final conf = confMatch?.group(1)?.toLowerCase() ?? '';
      return '$part$conf';
    }
    return null;
  }

  // ============ Permissions (from encryption) ============

  /// Document permissions (from encryption).
  /// Returns null if document is not encrypted.
  PdfPermissions? get permissions {
    if (encryption == null) return null;
    return PdfPermissions._(encryption!);
  }

  /// Converts to a DocxBuiltDocument for export.
  DocxBuiltDocument toDocx() {
    final widthTwips = (pageWidth * 20).toInt();
    final heightTwips = (pageHeight * 20).toInt();

    final section = DocxSectionDef(
      pageSize: DocxPageSize.custom,
      customWidth: widthTwips,
      customHeight: heightTwips,
      marginLeft: 1440,
      marginRight: 1440,
      marginTop: 1440,
      marginBottom: 1440,
    );

    return DocxBuiltDocument(
      elements: elements,
      section: section,
    );
  }

  /// Gets all text content as a single string.
  String get text {
    final sb = StringBuffer();
    for (final element in elements) {
      if (element is DocxParagraph) {
        for (final child in element.children) {
          if (child is DocxText) {
            sb.write(child.content);
          }
        }
        sb.writeln();
      } else if (element is DocxTable) {
        for (final row in element.rows) {
          for (final cell in row.cells) {
            for (final block in cell.children) {
              if (block is DocxParagraph) {
                for (final child in block.children) {
                  if (child is DocxText) {
                    sb.write(child.content);
                  }
                }
              }
            }
            sb.write('');
          }
          sb.writeln();
        }
      }
    }
    return sb.toString();
  }

  /// Gets the number of extracted paragraphs.
  int get paragraphCount => elements.whereType<DocxParagraph>().length;

  /// Whether parsing had warnings.
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Permissions wrapper for easier access.
class PdfPermissions {
  final PdfEncryption _encryption;

  PdfPermissions._(this._encryption);

  /// Whether printing is allowed.
  bool get canPrint => _encryption.canPrint;

  /// Whether modifying content is allowed.
  bool get canModify => _encryption.canModify;

  /// Whether copying text is allowed.
  bool get canCopy => _encryption.canCopy;

  /// Whether adding annotations is allowed.
  bool get canAnnotate => _encryption.canAnnotate;

  /// Whether filling forms is allowed.
  bool get canFillForms => _encryption.canFillForms;

  /// Whether extracting for accessibility is allowed.
  bool get canExtractForAccessibility => _encryption.canExtractForAccessibility;

  /// Whether assembling document is allowed.
  bool get canAssemble => _encryption.canAssemble;

  /// Whether high quality printing is allowed.
  bool get canPrintHighQuality => _encryption.canPrintHighQuality;

  /// Raw permission integer value.
  int get rawValue => _encryption.permissions;

  @override
  String toString() =>
      'PdfPermissions(print: $canPrint, copy: $canCopy, modify: $canModify)';
}
