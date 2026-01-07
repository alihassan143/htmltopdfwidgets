import 'dart:convert';
import 'dart:typed_data';

/// Low-level PDF 1.4 document writer.
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
  }) {
    // Create content stream object
    final contentId = _createObject(
      '<< /Length ${contentStream.length} >>\nstream\n$contentStream\nendstream',
    );

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

  /// Adds an image XObject.
  ///
  /// Returns the object ID for use in page resources.
  int addImage({
    required Uint8List bytes,
    required int width,
    required int height,
    String colorSpace = 'DeviceRGB',
    int bitsPerComponent = 8,
  }) {
    // Use ASCII85 or Hex encoding for simplicity
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

    // Write fonts
    offsets[_fontHelveticaId] = offset;
    write(
        '$_fontHelveticaId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n');

    offsets[_fontHelveticaBoldId] = offset;
    write(
        '$_fontHelveticaBoldId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n');

    offsets[_fontHelveticaObliqueId] = offset;
    write(
        '$_fontHelveticaObliqueId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>\nendobj\n');

    offsets[_fontCourierId] = offset;
    write(
        '$_fontCourierId 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>\nendobj\n');

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
      write('${obj.id} 0 obj\n${obj.content}\nendobj\n');
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

  int _createObject(String content) {
    final id = _nextId++;
    _objects.add(_PdfObject(id, content));
    return id;
  }
}

class _PdfObject {
  final int id;
  final String content;
  _PdfObject(this.id, this.content);
}
