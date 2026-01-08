import 'dart:typed_data';

/// Parses TrueType font files to extract metrics for PDF embedding.
///
/// Reads essential tables: head, hhea, hmtx, cmap, post, OS/2
class TtfParser {
  final Uint8List data;
  late ByteData _bytes;

  // Font metrics (in font units, typically 1000 or 2048 units per em)
  int unitsPerEm = 1000;
  int ascent = 0;
  int descent = 0;
  int capHeight = 0;
  int lineGap = 0;
  List<int> bbox = [0, 0, 0, 0]; // xMin, yMin, xMax, yMax
  double italicAngle = 0;
  bool isFixedPitch = false;
  int flags = 0;

  // Glyph metrics
  int numGlyphs = 0;
  final Map<int, int> _glyphWidths = {}; // glyphId -> advanceWidth
  final Map<int, int> _unicodeToGlyph = {}; // Unicode -> glyphId

  // Table directory
  final Map<String, _TableEntry> _tables = {};

  TtfParser(this.data) {
    _bytes = ByteData.sublistView(data);
  }

  /// Parses the TTF file and extracts all required metrics.
  void parse() {
    _readTableDirectory();
    _parseHeadTable();
    _parseHheaTable();
    _parseMaxpTable();
    _parseCmapTable();
    _parseHmtxTable();
    _parsePostTable();
    _parseOs2Table();
    _calculateFlags();
  }

  /// Gets the advance width for a Unicode code point.
  int getCharWidth(int unicode) {
    final glyphId = _unicodeToGlyph[unicode] ?? 0;
    return _glyphWidths[glyphId] ?? _glyphWidths[0] ?? 500;
  }

  /// Gets widths array for PDF (scaled to 1000 units).
  List<int> getWidthsArray(int firstChar, int lastChar) {
    final scale = 1000.0 / unitsPerEm;
    final widths = <int>[];
    for (var i = firstChar; i <= lastChar; i++) {
      final w = getCharWidth(i);
      widths.add((w * scale).round());
    }
    return widths;
  }

  /// Gets font bounding box scaled to 1000 units.
  List<int> getScaledBbox() {
    final scale = 1000.0 / unitsPerEm;
    return [
      (bbox[0] * scale).round(),
      (bbox[1] * scale).round(),
      (bbox[2] * scale).round(),
      (bbox[3] * scale).round(),
    ];
  }

  /// Gets ascent scaled to 1000 units.
  int getScaledAscent() => (ascent * 1000.0 / unitsPerEm).round();

  /// Gets descent scaled to 1000 units.
  int getScaledDescent() => (descent * 1000.0 / unitsPerEm).round();

  /// Gets capHeight scaled to 1000 units.
  int getScaledCapHeight() => (capHeight * 1000.0 / unitsPerEm).round();

  // --- Table Directory ---

  void _readTableDirectory() {
    // Offset table
    // final sfntVersion = _bytes.getUint32(0);
    final numTables = _bytes.getUint16(4);

    // Read table records
    var offset = 12;
    for (var i = 0; i < numTables; i++) {
      final tag = String.fromCharCodes([
        _bytes.getUint8(offset),
        _bytes.getUint8(offset + 1),
        _bytes.getUint8(offset + 2),
        _bytes.getUint8(offset + 3),
      ]);
      final tableOffset = _bytes.getUint32(offset + 8);
      final tableLength = _bytes.getUint32(offset + 12);
      _tables[tag] = _TableEntry(tableOffset, tableLength);
      offset += 16;
    }
  }

  // --- head table ---

  void _parseHeadTable() {
    final entry = _tables['head'];
    if (entry == null) return;

    final o = entry.offset;
    unitsPerEm = _bytes.getUint16(o + 18);
    bbox = [
      _bytes.getInt16(o + 36), // xMin
      _bytes.getInt16(o + 38), // yMin
      _bytes.getInt16(o + 40), // xMax
      _bytes.getInt16(o + 42), // yMax
    ];
  }

  // --- hhea table ---

  void _parseHheaTable() {
    final entry = _tables['hhea'];
    if (entry == null) return;

    final o = entry.offset;
    ascent = _bytes.getInt16(o + 4);
    descent = _bytes.getInt16(o + 6);
    lineGap = _bytes.getInt16(o + 8);
  }

  // --- maxp table ---

  void _parseMaxpTable() {
    final entry = _tables['maxp'];
    if (entry == null) return;

    numGlyphs = _bytes.getUint16(entry.offset + 4);
  }

  // --- cmap table (Unicode mapping) ---

  void _parseCmapTable() {
    final entry = _tables['cmap'];
    if (entry == null) return;

    final o = entry.offset;
    final numSubtables = _bytes.getUint16(o + 2);

    // Find a Unicode subtable (platformID 0 or 3)
    var subtableOffset = 0;
    for (var i = 0; i < numSubtables; i++) {
      final platformId = _bytes.getUint16(o + 4 + i * 8);
      final encodingId = _bytes.getUint16(o + 4 + i * 8 + 2);
      final offset = _bytes.getUint32(o + 4 + i * 8 + 4);

      // Prefer Windows Unicode BMP (3, 1) or Unicode (0, 3)
      if ((platformId == 3 && encodingId == 1) ||
          (platformId == 0 && encodingId == 3)) {
        subtableOffset = o + offset;
        break;
      }
      // Fallback to any Unicode table
      if (platformId == 0 || platformId == 3) {
        subtableOffset = o + offset;
      }
    }

    if (subtableOffset == 0) return;

    final format = _bytes.getUint16(subtableOffset);

    if (format == 4) {
      _parseCmapFormat4(subtableOffset);
    } else if (format == 12) {
      _parseCmapFormat12(subtableOffset);
    }
  }

  void _parseCmapFormat4(int offset) {
    final segCount = _bytes.getUint16(offset + 6) ~/ 2;
    final endCodeOffset = offset + 14;
    final startCodeOffset = endCodeOffset + segCount * 2 + 2;
    final idDeltaOffset = startCodeOffset + segCount * 2;
    final idRangeOffset = idDeltaOffset + segCount * 2;

    for (var i = 0; i < segCount; i++) {
      final endCode = _bytes.getUint16(endCodeOffset + i * 2);
      final startCode = _bytes.getUint16(startCodeOffset + i * 2);
      final idDelta = _bytes.getInt16(idDeltaOffset + i * 2);
      final idRangeOffsetValue = _bytes.getUint16(idRangeOffset + i * 2);

      if (startCode == 0xFFFF) break;

      for (var c = startCode; c <= endCode; c++) {
        int glyphId;
        if (idRangeOffsetValue == 0) {
          glyphId = (c + idDelta) & 0xFFFF;
        } else {
          final glyphOffset =
              idRangeOffset + i * 2 + idRangeOffsetValue + (c - startCode) * 2;
          glyphId = _bytes.getUint16(glyphOffset);
          if (glyphId != 0) {
            glyphId = (glyphId + idDelta) & 0xFFFF;
          }
        }
        _unicodeToGlyph[c] = glyphId;
      }
    }
  }

  void _parseCmapFormat12(int offset) {
    final numGroups = _bytes.getUint32(offset + 12);

    for (var i = 0; i < numGroups; i++) {
      final groupOffset = offset + 16 + i * 12;
      final startCode = _bytes.getUint32(groupOffset);
      final endCode = _bytes.getUint32(groupOffset + 4);
      final startGlyph = _bytes.getUint32(groupOffset + 8);

      for (var c = startCode; c <= endCode; c++) {
        _unicodeToGlyph[c] = startGlyph + (c - startCode);
      }
    }
  }

  // --- hmtx table (glyph widths) ---

  void _parseHmtxTable() {
    final entry = _tables['hmtx'];
    final hheaEntry = _tables['hhea'];
    if (entry == null || hheaEntry == null) return;

    final numOfLongHorMetrics = _bytes.getUint16(hheaEntry.offset + 34);
    final o = entry.offset;

    // Read longHorMetric array
    var lastWidth = 0;
    for (var i = 0; i < numOfLongHorMetrics; i++) {
      final advanceWidth = _bytes.getUint16(o + i * 4);
      _glyphWidths[i] = advanceWidth;
      lastWidth = advanceWidth;
    }

    // Remaining glyphs use last advanceWidth
    for (var i = numOfLongHorMetrics; i < numGlyphs; i++) {
      _glyphWidths[i] = lastWidth;
    }
  }

  // --- post table ---

  void _parsePostTable() {
    final entry = _tables['post'];
    if (entry == null) return;

    final o = entry.offset;
    // Italic angle is Fixed 16.16
    italicAngle = _bytes.getInt32(o + 4) / 65536.0;
    isFixedPitch = _bytes.getUint32(o + 12) != 0;
  }

  // --- OS/2 table ---

  void _parseOs2Table() {
    final entry = _tables['OS/2'];
    if (entry == null) return;

    final o = entry.offset;
    // sCapHeight is at offset 88 (version 2+)
    if (entry.length >= 90) {
      capHeight = _bytes.getInt16(o + 88);
    }
    if (capHeight == 0) {
      // Fallback: estimate as 70% of ascent
      capHeight = (ascent * 0.7).round();
    }
  }

  // --- Font Flags ---

  void _calculateFlags() {
    // PDF font flags
    flags = 0;
    if (isFixedPitch) flags |= 1; // FixedPitch
    flags |= 32; // Nonsymbolic (assuming Latin font)
    if (italicAngle != 0) flags |= 64; // Italic
  }

  /// Generates a ToUnicode CMap for text extraction.
  String generateToUnicodeCMap() {
    final sb = StringBuffer();
    sb.writeln('/CIDInit /ProcSet findresource begin');
    sb.writeln('12 dict begin');
    sb.writeln('begincmap');
    sb.writeln('/CIDSystemInfo <<');
    sb.writeln('/Registry (Adobe)');
    sb.writeln('/Ordering (UCS)');
    sb.writeln('/Supplement 0');
    sb.writeln('>> def');
    sb.writeln('/CMapName /Adobe-Identity-UCS def');
    sb.writeln('/CMapType 2 def');
    sb.writeln('1 begincodespacerange');
    sb.writeln('<0000> <FFFF>');
    sb.writeln('endcodespacerange');

    // Generate char mappings in batches of 100
    final entries = _unicodeToGlyph.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var i = 0;
    while (i < entries.length) {
      final batchSize = (entries.length - i).clamp(0, 100);
      sb.writeln('$batchSize beginbfchar');
      for (var j = 0; j < batchSize; j++) {
        final e = entries[i + j];
        final hex = e.key.toRadixString(16).padLeft(4, '0').toUpperCase();
        sb.writeln('<$hex> <$hex>');
      }
      sb.writeln('endbfchar');
      i += batchSize;
    }

    sb.writeln('endcmap');
    sb.writeln('CMapName currentdict /CMap defineresource pop');
    sb.writeln('end');
    sb.writeln('end');
    return sb.toString();
  }
}

class _TableEntry {
  final int offset;
  final int length;
  _TableEntry(this.offset, this.length);
}
