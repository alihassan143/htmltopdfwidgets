import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Low-level PDF 1.4/A document writer with compression support.
///
/// Handles object creation, cross-reference table, and final PDF assembly.
class PdfDocumentWriter {
  final List<_PdfObject> _objects = [];
  final List<int> _pageObjectIds = [];
  int _nextId = 1;

  // Font object IDs (assigned during initialization)
  late final int _catalogId;
  late final int _pagesId;
  late final int _fontHelveticaId;
  late final int _fontHelveticaBoldId;
  late final int _fontHelveticaObliqueId;
  late final int _fontCourierId;
  late final int _infoId;

  PdfDocumentWriter() {
    _initializeStandardObjects();
  }

  void _initializeStandardObjects() {
    // Reserve IDs for standard objects
    _catalogId = _nextId++;
    _pagesId = _nextId++;
    _fontHelveticaId = _nextId++;
    _fontHelveticaBoldId = _nextId++;
    _fontHelveticaObliqueId = _nextId++;
    _fontCourierId = _nextId++;
    _infoId = _nextId++;
  }

  /// Adds a page with the given content stream.
  ///
  /// Returns the page object ID.
  int addPage({
    required String contentStream,
    required double width,
    required double height,
    Map<String, int>? xObjectIds,
    bool compress = true,
  }) {
    // Compress content stream with FlateDecode
    dynamic contentObjData;
    if (compress && contentStream.length > 100) {
      try {
        final compressed = zlib.encode(utf8.encode(contentStream));
        final dict =
            '<< /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n';
        final builder = BytesBuilder();
        builder.add(utf8.encode(dict));
        builder.add(compressed);
        builder.add(utf8.encode('\nendstream'));
        contentObjData = builder.toBytes();
      } catch (_) {
        contentObjData =
            '<< /Length ${contentStream.length} >>\nstream\n$contentStream\nendstream';
      }
    } else {
      contentObjData =
          '<< /Length ${contentStream.length} >>\nstream\n$contentStream\nendstream';
    }

    final contentId = _createObject(contentObjData);

    // Build resources dictionary
    final resourcesBuffer = StringBuffer('<<\n');

    // Fonts
    resourcesBuffer.writeln('/Font <<');
    resourcesBuffer.writeln('/F1 $_fontHelveticaId 0 R');
    resourcesBuffer.writeln('/F2 $_fontHelveticaBoldId 0 R');
    resourcesBuffer.writeln('/F3 $_fontHelveticaObliqueId 0 R');
    resourcesBuffer.writeln('/F4 $_fontCourierId 0 R');
    resourcesBuffer.writeln('>>');

    // XObjects (images)
    if (xObjectIds != null && xObjectIds.isNotEmpty) {
      resourcesBuffer.writeln('/XObject <<');
      xObjectIds.forEach((name, id) {
        resourcesBuffer.writeln('$name $id 0 R');
      });
      resourcesBuffer.writeln('>>');
    }

    resourcesBuffer.write('>>');

    // Create page object
    final pageId = _createObject(
      '<<\n'
      '/Type /Page\n'
      '/Parent $_pagesId 0 R\n'
      '/MediaBox [0 0 $width $height]\n'
      '/Contents $contentId 0 R\n'
      '/Resources ${resourcesBuffer.toString()}\n'
      '>>',
    );

    _pageObjectIds.add(pageId);
    return pageId;
  }

  /// Adds a link annotation to the current page.
  ///
  /// Returns the annotation object ID.
  int addLinkAnnotation({
    required double x,
    required double y,
    required double width,
    required double height,
    required String uri,
    required int pageId,
  }) {
    final annotId = _createObject(
      '<<\n'
      '/Type /Annot\n'
      '/Subtype /Link\n'
      '/Rect [$x $y ${x + width} ${y + height}]\n'
      '/Border [0 0 0]\n'
      '/A << /Type /Action /S /URI /URI ($uri) >>\n'
      '>>',
    );

    // Add annotation to page's Annots array
    _pageAnnotations[pageId] ??= [];
    _pageAnnotations[pageId]!.add(annotId);

    return annotId;
  }

  /// Map of page IDs to annotation object IDs
  final Map<int, List<int>> _pageAnnotations = {};

  /// Adds an image XObject.
  ///
  /// Returns the object ID for use in page resources.
  /// [filter] can be 'DCTDecode' for JPEG, 'FlateDecode' for compressed raw, or 'ASCIIHexDecode'.
  int addImage({
    required Uint8List bytes,
    required int width,
    required int height,
    String colorSpace = 'DeviceRGB',
    int bitsPerComponent = 8,
    String? filter,
  }) {
    // Detect JPEG (starts with 0xFFD8)
    final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

    if (isJpeg || filter == 'DCTDecode') {
      // JPEG - embed directly with DCTDecode
      return _createObject(
        '<<\n'
        '/Type /XObject\n'
        '/Subtype /Image\n'
        '/Width $width\n'
        '/Height $height\n'
        '/ColorSpace /$colorSpace\n'
        '/BitsPerComponent $bitsPerComponent\n'
        '/Filter /DCTDecode\n'
        '/Length ${bytes.length}\n'
        '>>\n'
        'stream\n'
        '${String.fromCharCodes(bytes)}\n'
        'endstream',
      );
    } else if (filter == 'FlateDecode' || bytes.length > 1000) {
      // Compress raw image data with FlateDecode
      try {
        final compressed = zlib.encode(bytes);
        final dict = '<<\n'
            '/Type /XObject\n'
            '/Subtype /Image\n'
            '/Width $width\n'
            '/Height $height\n'
            '/ColorSpace /$colorSpace\n'
            '/BitsPerComponent $bitsPerComponent\n'
            '/Filter /FlateDecode\n'
            '/Length ${compressed.length}\n'
            '>>\n'
            'stream\n';
        final builder = BytesBuilder();
        builder.add(utf8.encode(dict));
        builder.add(compressed);
        builder.add(utf8.encode('\nendstream'));
        return _createObject(builder.toBytes());
      } catch (_) {
        // Fall through to hex encoding
      }
    }

    // Fallback: ASCIIHex encoding
    final hexData =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

    return _createObject(
      '<<\n'
      '/Type /XObject\n'
      '/Subtype /Image\n'
      '/Width $width\n'
      '/Height $height\n'
      '/ColorSpace /$colorSpace\n'
      '/BitsPerComponent $bitsPerComponent\n'
      '/Filter /ASCIIHexDecode\n'
      '/Length ${hexData.length + 1}\n'
      '>>\n'
      'stream\n'
      '$hexData>\n'
      'endstream',
    );
  }

  /// Finalizes the PDF and returns the bytes.
  Uint8List save() {
    final buffer = BytesBuilder();
    final offsets = <int, int>{};
    var offset = 0;

    void write(String s) {
      final bytes = utf8.encode(s);
      buffer.add(bytes);
      offset += bytes.length;
    }

    // Header
    write('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

    // Write catalog
    offsets[_catalogId] = offset;
    write(
        '$_catalogId 0 obj\n<< /Type /Catalog /Pages $_pagesId 0 R >>\nendobj\n');

    // Write pages
    offsets[_pagesId] = offset;
    final kids = _pageObjectIds.map((id) => '$id 0 R').join(' ');
    write(
        '$_pagesId 0 obj\n<< /Type /Pages /Kids [$kids] /Count ${_pageObjectIds.length} >>\nendobj\n');

    // Write fonts with width arrays for accurate text measurement
    // Helvetica width array (characters 32-255)
    const helveticaWidths =
        '[278 278 355 556 556 889 667 191 333 333 389 584 278 333 278 278 '
        '556 556 556 556 556 556 556 556 556 556 278 278 584 584 584 556 '
        '1015 667 667 722 722 667 611 778 722 278 500 667 556 833 722 778 '
        '667 778 722 667 611 722 667 944 667 667 611 278 278 278 469 556 '
        '333 556 556 500 556 556 278 556 556 222 222 500 222 833 556 556 '
        '556 556 333 500 278 556 500 722 500 500 500 334 260 334 584 278]';

    offsets[_fontHelveticaId] = offset;
    write(
        '$_fontHelveticaId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
        '/Widths $helveticaWidths >>\nendobj\n');

    offsets[_fontHelveticaBoldId] = offset;
    write(
        '$_fontHelveticaBoldId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold '
        '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
        '/Widths $helveticaWidths >>\nendobj\n');

    offsets[_fontHelveticaObliqueId] = offset;
    write(
        '$_fontHelveticaObliqueId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique '
        '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
        '/Widths $helveticaWidths >>\nendobj\n');

    offsets[_fontCourierId] = offset;
    write(
        '$_fontCourierId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier '
        '/Encoding /WinAnsiEncoding >>\nendobj\n');

    // Write info
    offsets[_infoId] = offset;
    final now = DateTime.now();
    final dateStr =
        'D:${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    write(
        '$_infoId 0 obj\n<< /Creator (docx_creator) /Producer (Dart PdfExporter) /CreationDate ($dateStr) >>\nendobj\n');

    // Write dynamic objects
    for (final obj in _objects) {
      offsets[obj.id] = offset;
      write('${obj.id} 0 obj\n');
      if (obj.content is String) {
        write('${obj.content as String}\nendobj\n');
      } else if (obj.content is List<int>) {
        final data = obj.content as List<int>;
        buffer.add(data);
        offset += data.length;
        write('\nendobj\n');
      }
    }

    // XRef table
    final startXref = offset;
    final maxId = _objects.isEmpty ? _infoId : _objects.last.id;
    write('xref\n');
    write('0 ${maxId + 1}\n');
    write('0000000000 65535 f \n');

    for (var i = 1; i <= maxId; i++) {
      if (offsets.containsKey(i)) {
        write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
      } else {
        write('0000000000 65535 f \n');
      }
    }

    // Trailer
    write(
        'trailer\n<< /Size ${maxId + 1} /Root $_catalogId 0 R /Info $_infoId 0 R >>\n');
    write('startxref\n$startXref\n%%EOF\n');

    return buffer.toBytes();
  }

  int _createObject(dynamic content) {
    final id = _nextId++;
    _objects.add(_PdfObject(id, content));
    return id;
  }
}

class _PdfObject {
  final int id;
  final dynamic content;
  _PdfObject(this.id, this.content);
}
