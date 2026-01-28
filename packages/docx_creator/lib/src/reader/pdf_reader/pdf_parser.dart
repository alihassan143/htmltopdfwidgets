import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pdf_encryption.dart';
import 'pdf_types.dart';

/// Low-level PDF parser for reading PDF structure.
///
/// Handles PDF header, xref tables/streams, trailer, and object parsing.
class PdfParser {
  final Uint8List data;
  final String content;

  // PDF structure
  final Map<int, PdfObject> objects = {};
  final Map<String, int> namedObjects = {};
  int rootRef = 0;
  int pagesRef = 0;
  String version = '1.4';

  // Parsing warnings
  final List<String> warnings = [];

  PdfEncryption? encryption;

  PdfParser(this.data) : content = String.fromCharCodes(data);

  void setEncryption(PdfEncryption encryption) {
    this.encryption = encryption;
  }

  /// Parses the PDF structure.
  void parse() {
    parseHeader();
    findXRef();
    parseCatalog();
  }

  // ... existing parseHeader, findXRef ...

  /// Decrypts a string if encryption is active.
  ///
  /// [text] should be the raw content bytes of the string object.
  /// If provided as String, assumes Latin1 (binary) mapping.
  String decryptString(String text, int objNum, int genNum) {
    if (encryption == null || !encryption!.isReady) return text;

    // Convert string to bytes (treating char codes as bytes)
    final bytes = Uint8List.fromList(text.codeUnits);

    final decrypted = encryption!.decryptData(bytes, objNum, genNum);

    // Convert back to string (raw) - callers will handle encoding (e.g. TextExtractor, Metadata)
    return String.fromCharCodes(decrypted);
  }

  /// Gets decompressed stream content with support for encryption and filters.
  String? getStreamContent(int objRef) {
    final obj = getObject(objRef);
    if (obj == null) return null;

    final streamStart = obj.content.indexOf('stream');
    final streamEnd = obj.content.lastIndexOf('endstream');
    if (streamStart == -1 || streamEnd == -1) return null;

    // Skip 'stream' and newline
    var dataStart = streamStart + 6;
    if (obj.content.codeUnitAt(dataStart) == 13) dataStart++; // \r
    if (obj.content.codeUnitAt(dataStart) == 10) dataStart++; // \n

    // Correctly handle stream end: look for newline before endstream
    var dataEnd = streamEnd;
    if (obj.content.codeUnitAt(dataEnd - 1) == 10) dataEnd--; // \n
    if (obj.content.codeUnitAt(dataEnd - 1) == 13) dataEnd--; // \r

    // Basic extraction

    // We need to parse valid stream length from dict for robustness
    final lengthMatch = RegExp(r'/Length\s+(\d+)').firstMatch(obj.content);
    int? length;
    if (lengthMatch != null) {
      length = int.parse(lengthMatch.group(1)!);
    } else {
      // Handle indirect length reference
      final lengthRefMatch =
          RegExp(r'/Length\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
      if (lengthRefMatch != null) {
        final lenObj = getObject(int.parse(lengthRefMatch.group(1)!));
        if (lenObj != null) {
          length = int.tryParse(lenObj.content.trim());
        }
      }
    }

    // Extract stream bytes from content string
    // Assuming content string faithfully represents bytes (Latin1)
    var streamBytes = obj.content.substring(dataStart, dataEnd).codeUnits;

    // If length is explicit and matches roughly, use it?
    // Sometimes stream scanning is inaccurate if 'endstream' appears in data.
    // Ideally we use length if available.
    if (length != null && length < streamBytes.length) {
      // Only truncate if we're sure.
      // streamBytes = streamBytes.sublist(0, length);
    }

    var bytes = Uint8List.fromList(streamBytes.map((e) => e & 0xFF).toList());

    if (encryption != null && encryption!.isReady) {
      int genNum = 0;
      bytes = encryption!.decryptData(bytes, objRef, genNum);
    }

    // 3. Apply Filters (Flate, etc.)
    final filters = _parseFilters(obj.content);
    final decodeParms = parseDecodeParms(obj.content);

    if (filters.isNotEmpty) {
      try {
        for (var i = filters.length - 1; i >= 0; i--) {
          final filter = filters[i];
          final parms = i < decodeParms.length ? decodeParms[i] : null;
          bytes = applyFilterWithParams(filter, bytes, parms);
        }
      } catch (e) {
        warnings.add('Could not decompress stream $objRef: $e');
      }
    }

    // 4. Convert to String (Latin1)
    final result = String.fromCharCodes(bytes);
    obj.stream = result;
    return result;
  }

  /// Validates and parses PDF header.
  void parseHeader() {
    if (data.length < 8) {
      throw PdfParseException('File too small to be a valid PDF');
    }

    final headerBytes = data.sublist(0, 20);
    final header = String.fromCharCodes(headerBytes);

    final match = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(header);
    if (match == null) {
      throw PdfParseException('Invalid PDF header: missing %PDF- signature');
    }
    version = match.group(1)!;
  }

  /// Finds and parses the cross-reference table.
  void findXRef() {
    final startxrefPos = content.lastIndexOf('startxref');
    if (startxrefPos == -1) {
      throw PdfParseException('Cannot find startxref marker');
    }

    final afterStartxref = content.substring(startxrefPos + 9).trim();
    final lines = afterStartxref.split(RegExp(r'[\r\n]+'));
    if (lines.isEmpty) {
      throw PdfParseException('Cannot read xref offset');
    }

    final xrefOffset = int.tryParse(lines.first.trim());
    if (xrefOffset == null || xrefOffset < 0 || xrefOffset >= data.length) {
      throw PdfParseException('Invalid xref offset: ${lines.first}');
    }

    final xrefContent = content.substring(xrefOffset);
    if (xrefContent.trimLeft().startsWith('xref')) {
      _parseXRefTable(xrefOffset);
    } else {
      _parseXRefStream(xrefOffset);
    }

    _parseTrailer();
  }

  /// Parses traditional xref table.
  void _parseXRefTable(int offset) {
    final tableContent = content.substring(offset);
    final lines = tableContent.split(RegExp(r'[\r\n]+'));

    var objNum = 0;
    var lineIdx = 1;

    while (lineIdx < lines.length) {
      final line = lines[lineIdx].trim();
      if (line.isEmpty) {
        lineIdx++;
        continue;
      }
      if (line.startsWith('trailer')) break;

      final rangeParts = line.split(RegExp(r'\s+'));
      if (rangeParts.length == 2) {
        final first = int.tryParse(rangeParts[0]);
        final count = int.tryParse(rangeParts[1]);
        if (first != null && count != null && count < 10000) {
          objNum = first;
          lineIdx++;
          continue;
        }
      }

      if (line.length >= 18) {
        final byteOffset = int.tryParse(line.substring(0, 10).trim());
        final inUse = line.length > 17 && line[17] == 'n';

        if (byteOffset != null &&
            inUse &&
            byteOffset > 0 &&
            byteOffset < data.length) {
          objects[objNum] = PdfObject(objNum, byteOffset);
        }
        objNum++;
      }
      lineIdx++;
    }
  }

  /// Parses xref stream (PDF 1.5+).
  void _parseXRefStream(int offset) {
    final obj = parseObjectAt(offset);
    if (obj == null) {
      warnings.add('Could not parse xref stream');
      _fallbackScanObjects();
      return;
    }

    // Get Root/Catalog from xref stream dictionary
    final rootMatch =
        RegExp(r'/Root\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
    if (rootMatch != null) {
      rootRef = int.parse(rootMatch.group(1)!);
    }

    // Parse W array
    final wMatch =
        RegExp(r'/W\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s*\]').firstMatch(obj.content);
    if (wMatch == null) {
      warnings.add('Invalid xref stream: missing /W array');
      _fallbackScanObjects();
      return;
    }

    final w1 = int.parse(wMatch.group(1)!);
    final w2 = int.parse(wMatch.group(2)!);
    final w3 = int.parse(wMatch.group(3)!);
    final entrySize = w1 + w2 + w3;

    if (entrySize == 0) {
      warnings.add('Invalid xref stream: zero entry size');
      _fallbackScanObjects();
      return;
    }

    // Parse Size
    final sizeMatch = RegExp(r'/Size\s+(\d+)').firstMatch(obj.content);
    final size = sizeMatch != null ? int.parse(sizeMatch.group(1)!) : 0;

    // Parse Index array (optional, defaults to [0 Size])
    List<int> index;
    final indexMatch = RegExp(r'/Index\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (indexMatch != null) {
      index = RegExp(r'\d+')
          .allMatches(indexMatch.group(1)!)
          .map((m) => int.parse(m.group(0)!))
          .toList();
    } else {
      index = [0, size];
    }

    // Get stream data
    final streamStart = obj.content.indexOf('stream');
    if (streamStart == -1) {
      warnings.add('No stream in xref stream object');
      _fallbackScanObjects();
      return;
    }

    var dataStart = streamStart + 6;
    if (dataStart < obj.content.length && obj.content[dataStart] == '\r') {
      dataStart++;
    }
    if (dataStart < obj.content.length && obj.content[dataStart] == '\n') {
      dataStart++;
    }

    // Get stream bytes
    final lengthMatch = RegExp(r'/Length\s+(\d+)').firstMatch(obj.content);
    if (lengthMatch == null) {
      _fallbackScanObjects();
      return;
    }

    final streamLength = int.parse(lengthMatch.group(1)!);
    final objStartIdx = content.indexOf(obj.content);
    if (objStartIdx == -1) {
      _fallbackScanObjects();
      return;
    }

    final absStart = objStartIdx + dataStart;
    if (absStart + streamLength > data.length) {
      _fallbackScanObjects();
      return;
    }

    var streamBytes = data.sublist(absStart, absStart + streamLength);

    // Decompress if needed
    final filters = _parseFilters(obj.content);
    final decodeParms = parseDecodeParms(obj.content);
    for (var i = filters.length - 1; i >= 0; i--) {
      try {
        final parms = i < decodeParms.length ? decodeParms[i] : null;
        streamBytes = applyFilterWithParams(filters[i], streamBytes, parms);
      } catch (e) {
        warnings.add('Failed to decompress xref stream: $e');
        _fallbackScanObjects();
        return;
      }
    }

    // Parse entries
    var byteIdx = 0;
    for (var i = 0; i < index.length; i += 2) {
      final firstObj = index[i];
      final count = index[i + 1];

      for (var j = 0; j < count; j++) {
        if (byteIdx + entrySize > streamBytes.length) break;

        // Read entry fields
        var type = 1; // Default type if w1 == 0
        if (w1 > 0) {
          type = _readInt(streamBytes, byteIdx, w1);
        }
        byteIdx += w1;

        final field2 = w2 > 0 ? _readInt(streamBytes, byteIdx, w2) : 0;
        byteIdx += w2;

        final field3 = w3 > 0 ? _readInt(streamBytes, byteIdx, w3) : 0;
        byteIdx += w3;

        final objNum = firstObj + j;

        if (type == 1 && field2 > 0 && field2 < data.length) {
          // Regular object
          objects[objNum] = PdfObject(objNum, field2);
        } else if (type == 2) {
          // Compressed object in object stream
          _objectStreamRefs[objNum] = (streamObjNum: field2, index: field3);
        }
      }
    }
  }

  /// Object stream references: objNum -> (streamObjNum, index within stream)
  final Map<int, ({int streamObjNum, int index})> _objectStreamRefs = {};

  /// Reads an integer from bytes (big-endian)
  int _readInt(Uint8List bytes, int offset, int length) {
    var value = 0;
    for (var i = 0; i < length && offset + i < bytes.length; i++) {
      value = (value << 8) | bytes[offset + i];
    }
    return value;
  }

  /// Fallback: scan document for objects when xref is broken
  void _fallbackScanObjects() {
    warnings.add('Using fallback object scanning');
    final objPattern = RegExp(r'(\d+)\s+\d+\s+obj');
    for (final match in objPattern.allMatches(content)) {
      final objNum = int.parse(match.group(1)!);
      if (!objects.containsKey(objNum)) {
        objects[objNum] = PdfObject(objNum, match.start);
      }
    }

    // Try to find Root from any trailer or xref stream
    final rootMatch = RegExp(r'/Root\s+(\d+)\s+\d+\s+R').firstMatch(content);
    if (rootMatch != null && rootRef == 0) {
      rootRef = int.parse(rootMatch.group(1)!);
    }
  }

  /// Parses trailer dictionary.
  void _parseTrailer() {
    final trailerPos = content.lastIndexOf('trailer');
    if (trailerPos == -1) return;

    final trailerEnd = content.indexOf('>>', trailerPos);
    if (trailerEnd == -1) return;

    final trailerStr = content.substring(trailerPos, trailerEnd + 2);

    final rootMatch = RegExp(r'/Root\s+(\d+)\s+\d+\s+R').firstMatch(trailerStr);
    if (rootMatch != null) {
      rootRef = int.parse(rootMatch.group(1)!);
    }

    final infoMatch = RegExp(r'/Info\s+(\d+)\s+\d+\s+R').firstMatch(trailerStr);
    if (infoMatch != null) {
      namedObjects['Info'] = int.parse(infoMatch.group(1)!);
    }
  }

  /// Parses the document catalog.
  void parseCatalog() {
    if (rootRef == 0) {
      warnings.add('No document catalog found');
      return;
    }

    final catalogObj = getObject(rootRef);
    if (catalogObj == null) {
      warnings.add('Cannot read document catalog');
      return;
    }

    final pagesMatch =
        RegExp(r'/Pages\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (pagesMatch != null) {
      pagesRef = int.parse(pagesMatch.group(1)!);
    } else {
      warnings.add('No Pages reference in catalog');
    }
  }

  /// Parses object at a given offset.
  PdfObject? parseObjectAt(int offset) {
    if (offset >= data.length) return null;

    final objContent = content.substring(offset);
    final endObj = objContent.indexOf('endobj');
    if (endObj == -1) return null;

    final objMatch = RegExp(r'(\d+)\s+\d+\s+obj').firstMatch(objContent);
    if (objMatch == null) return null;

    final objNum = int.parse(objMatch.group(1)!);
    final obj = PdfObject(objNum, offset);
    obj.content = objContent.substring(0, endObj);
    return obj;
  }

  /// Gets a PDF object by reference number.
  /// Supports both regular objects and objects stored in object streams.
  PdfObject? getObject(int objNum) {
    // Check for object stored in object stream
    if (_objectStreamRefs.containsKey(objNum)) {
      return _getObjectFromStream(objNum);
    }

    final obj = objects[objNum];
    if (obj == null) return null;

    if (obj.content.isEmpty) {
      try {
        final objContent = content.substring(obj.offset);
        final endObjPos = objContent.indexOf('endobj');
        if (endObjPos != -1) {
          obj.content = objContent.substring(0, endObjPos);
        }
      } catch (e) {
        warnings.add('Cannot read object $objNum: $e');
        return null;
      }
    }

    return obj;
  }

  /// Cache for parsed object streams
  final Map<int, Map<int, String>> _objectStreamCache = {};

  /// Gets an object from an object stream.
  PdfObject? _getObjectFromStream(int objNum) {
    final ref = _objectStreamRefs[objNum];
    if (ref == null) return null;

    final streamObjNum = ref.streamObjNum;
    // Note: ref.index is available but we use objNum for lookup instead

    // Check cache
    if (_objectStreamCache.containsKey(streamObjNum)) {
      final cached = _objectStreamCache[streamObjNum]!;
      if (cached.containsKey(objNum)) {
        final obj = PdfObject(objNum, 0);
        obj.content = cached[objNum]!;
        return obj;
      }
    }

    // Parse the object stream
    final streamObj = objects[streamObjNum];
    if (streamObj == null) return null;

    // Load content if needed
    if (streamObj.content.isEmpty) {
      try {
        final objContent = content.substring(streamObj.offset);
        final endObjPos = objContent.indexOf('endobj');
        if (endObjPos != -1) {
          streamObj.content = objContent.substring(0, endObjPos);
        }
      } catch (e) {
        warnings.add('Cannot read object stream $streamObjNum: $e');
        return null;
      }
    }

    // Check it's actually an object stream
    if (!streamObj.content.contains('/Type /ObjStm') &&
        !streamObj.content.contains('/Type/ObjStm')) {
      return null;
    }

    // Get N (number of objects) and First (offset to first object)
    final nMatch = RegExp(r'/N\s+(\d+)').firstMatch(streamObj.content);
    final firstMatch = RegExp(r'/First\s+(\d+)').firstMatch(streamObj.content);
    if (nMatch == null || firstMatch == null) return null;

    final n = int.parse(nMatch.group(1)!);
    final first = int.parse(firstMatch.group(1)!);

    // Get decompressed stream content
    final streamContent = getStreamContent(streamObjNum);
    if (streamContent == null) return null;

    // Parse the header (pairs of objNum + offset)
    if (first > streamContent.length) {
      warnings.add(
          'Invalid First offset in object stream: $first > ${streamContent.length}');
      return null;
    }
    final header = streamContent.substring(0, first).trim();
    final headerParts = header.split(RegExp(r'\s+'));

    final objOffsets = <int, int>{};
    for (var i = 0; i < headerParts.length - 1 && i < n * 2; i += 2) {
      final oNum = int.tryParse(headerParts[i]);
      final oOffset = int.tryParse(headerParts[i + 1]);
      if (oNum != null && oOffset != null) {
        objOffsets[oNum] = first + oOffset;
      }
    }

    // Cache the parsed objects
    _objectStreamCache[streamObjNum] = {};

    // Extract each object
    final objNums = objOffsets.keys.toList()
      ..sort((a, b) {
        return objOffsets[a]!.compareTo(objOffsets[b]!);
      });

    for (var i = 0; i < objNums.length; i++) {
      final oNum = objNums[i];
      final start = objOffsets[oNum]!;
      final end = i + 1 < objNums.length
          ? objOffsets[objNums[i + 1]]!
          : streamContent.length;

      if (start < streamContent.length && end <= streamContent.length) {
        _objectStreamCache[streamObjNum]![oNum] =
            streamContent.substring(start, end).trim();
      }
    }

    // Return requested object
    if (_objectStreamCache[streamObjNum]!.containsKey(objNum)) {
      final obj = PdfObject(objNum, 0);
      obj.content = _objectStreamCache[streamObjNum]![objNum]!;
      return obj;
    }

    return null;
  }

  /// Tokenizes a PDF content stream.
  List<String> tokenize(String stream) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inString = false;
    var inHex = false;
    var arrayDepth = 0;
    var parenDepth = 0;

    for (var i = 0; i < stream.length; i++) {
      final char = stream[i];

      if (inString) {
        buffer.write(char);
        if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          if (i > 0 && stream[i - 1] == '\\') {
            // Escaped paren, continue
          } else {
            parenDepth--;
            if (parenDepth == 0) {
              inString = false;
              tokens.add(buffer.toString());
              buffer.clear();
            }
          }
        }
        continue;
      }

      if (inHex) {
        if (char == '>') {
          inHex = false;
          buffer.write(char);
          tokens.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (char == '(') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        inString = true;
        parenDepth = 1;
        buffer.write(char);
      } else if (char == '[') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        arrayDepth++;
        buffer.write(char);
      } else if (char == ']') {
        buffer.write(char);
        arrayDepth--;
        if (arrayDepth == 0) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else if (char == '<') {
        if (i + 1 < stream.length && stream[i + 1] != '<') {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
          inHex = true;
          buffer.write(char);
        } else {
          buffer.write(char);
        }
      } else if (RegExp(r'\s').hasMatch(char)) {
        if (arrayDepth == 0 && buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        } else if (arrayDepth > 0) {
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Parses DecodeParms dictionary or array.
  List<Map<String, dynamic>?> parseDecodeParms(String content) {
    final result = <Map<String, dynamic>?>[];

    // Try array format: /DecodeParms [<<...>> <<...>>]
    final arrayMatch =
        RegExp(r'/DecodeParms\s*\[([^\]]+)\]').firstMatch(content);
    if (arrayMatch != null) {
      final arrayContent = arrayMatch.group(1)!;
      // Find all dictionaries
      final dictPattern = RegExp(r'<<([^>]*)>>');
      for (final dictMatch in dictPattern.allMatches(arrayContent)) {
        result.add(_parseParmDict(dictMatch.group(1)!));
      }
      // Handle null entries
      if (result.isEmpty) {
        result.add(null);
      }
      return result;
    }

    // Try single dictionary: /DecodeParms <<...>>
    final singleMatch =
        RegExp(r'/DecodeParms\s*<<([^>]*)>>').firstMatch(content);
    if (singleMatch != null) {
      result.add(_parseParmDict(singleMatch.group(1)!));
      return result;
    }

    return [null];
  }

  /// Parses a DecodeParms dictionary content.
  Map<String, dynamic> _parseParmDict(String dictContent) {
    final parms = <String, dynamic>{};

    // Parse Predictor
    final predictorMatch =
        RegExp(r'/Predictor\s+(\d+)').firstMatch(dictContent);
    if (predictorMatch != null) {
      parms['Predictor'] = int.parse(predictorMatch.group(1)!);
    }

    // Parse Columns
    final columnsMatch = RegExp(r'/Columns\s+(\d+)').firstMatch(dictContent);
    if (columnsMatch != null) {
      parms['Columns'] = int.parse(columnsMatch.group(1)!);
    }

    // Parse Colors (for images)
    final colorsMatch = RegExp(r'/Colors\s+(\d+)').firstMatch(dictContent);
    if (colorsMatch != null) {
      parms['Colors'] = int.parse(colorsMatch.group(1)!);
    }

    // Parse BitsPerComponent
    final bitsMatch =
        RegExp(r'/BitsPerComponent\s+(\d+)').firstMatch(dictContent);
    if (bitsMatch != null) {
      parms['BitsPerComponent'] = int.parse(bitsMatch.group(1)!);
    }

    // Parse EarlyChange (for LZW)
    final earlyMatch = RegExp(r'/EarlyChange\s+(\d+)').firstMatch(dictContent);
    if (earlyMatch != null) {
      parms['EarlyChange'] = int.parse(earlyMatch.group(1)!);
    }

    return parms;
  }

  /// Parses filter specification (single or array).
  List<String> _parseFilters(String content) {
    // Try array format first: /Filter [/Filter1 /Filter2]
    final arrayMatch = RegExp(r'/Filter\s*\[([^\]]+)\]').firstMatch(content);
    if (arrayMatch != null) {
      return RegExp(r'/(\w+)')
          .allMatches(arrayMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }

    // Single filter: /Filter /FlateDecode
    final singleMatch = RegExp(r'/Filter\s*/(\w+)').firstMatch(content);
    if (singleMatch != null) {
      return [singleMatch.group(1)!];
    }

    return [];
  }

  /// Applies a single filter to decompress data with parameters.
  Uint8List applyFilterWithParams(
      String filter, Uint8List data, Map<String, dynamic>? parms) {
    switch (filter) {
      case 'FlateDecode':
        try {
          var decoded = Uint8List.fromList(ZLibDecoder().decodeBytes(data));
          // Apply predictor if specified
          if (parms != null && parms.containsKey('Predictor')) {
            final predictor = parms['Predictor'] as int;
            if (predictor > 1) {
              decoded = applyPredictor(decoded, parms);
            }
          }
          return decoded;
        } catch (e) {
          warnings.add('FlateDecode failed: $e');
          return data;
        }

      case 'ASCII85Decode':
        return _decodeAscii85(data);

      case 'ASCIIHexDecode':
        return _decodeAsciiHex(data);

      case 'LZWDecode':
        try {
          var decoded = _decodeLZW(data);
          if (parms != null && parms.containsKey('Predictor')) {
            final predictor = parms['Predictor'] as int;
            if (predictor > 1) {
              decoded = applyPredictor(decoded, parms);
            }
          }
          return decoded;
        } catch (e) {
          warnings.add('LZWDecode failed: $e');
          return data;
        }

      case 'DCTDecode':
        // JPEG - pass through
        return data;

      case 'JPXDecode':
        // JPEG2000 - pass through
        return data;

      case 'RunLengthDecode':
        return _decodeRunLength(data);

      case 'CCITTFaxDecode':
        warnings.add('CCITTFaxDecode not yet supported');
        return data;

      case 'JBIG2Decode':
        warnings.add('JBIG2Decode not yet supported');
        return data;

      default:
        warnings.add('Unknown filter: $filter');
        return data;
    }
  }

  /// Applies predictor function to decoded data.
  /// Supports PNG predictors (10-15) and TIFF predictor (2).
  Uint8List applyPredictor(Uint8List data, Map<String, dynamic> parms) {
    final predictor = parms['Predictor'] as int? ?? 1;
    final columns = parms['Columns'] as int? ?? 1;
    final colors = parms['Colors'] as int? ?? 1;
    final bitsPerComponent = parms['BitsPerComponent'] as int? ?? 8;

    final bytesPerPixel = (colors * bitsPerComponent + 7) ~/ 8;
    final bytesPerRow = (columns * colors * bitsPerComponent + 7) ~/ 8;

    if (predictor == 2) {
      // TIFF Predictor
      return _applyTiffPredictor(data, bytesPerRow, bytesPerPixel);
    } else if (predictor >= 10 && predictor <= 15) {
      // PNG Predictors
      return _applyPngPredictor(data, bytesPerRow, bytesPerPixel);
    }

    return data;
  }

  /// Applies TIFF horizontal differencing predictor.
  Uint8List _applyTiffPredictor(
      Uint8List data, int bytesPerRow, int bytesPerPixel) {
    if (bytesPerRow <= 0) return data;

    final numRows = data.length ~/ bytesPerRow;
    final result = Uint8List(data.length);

    for (var row = 0; row < numRows; row++) {
      final rowStart = row * bytesPerRow;

      for (var i = 0; i < bytesPerRow; i++) {
        final idx = rowStart + i;
        if (idx >= data.length) break;

        if (i < bytesPerPixel) {
          result[idx] = data[idx];
        } else {
          result[idx] = (data[idx] + result[idx - bytesPerPixel]) & 0xFF;
        }
      }
    }

    return result;
  }

  /// Applies PNG filter predictor.
  Uint8List _applyPngPredictor(
      Uint8List data, int bytesPerRow, int bytesPerPixel) {
    // PNG format: each row starts with a filter type byte
    final rowWidth = bytesPerRow + 1; // +1 for filter byte
    if (rowWidth <= 1) return data;

    final numRows = data.length ~/ rowWidth;
    final result = Uint8List(numRows * bytesPerRow);
    var prevRow = Uint8List(bytesPerRow);

    for (var row = 0; row < numRows; row++) {
      final srcStart = row * rowWidth;
      if (srcStart >= data.length) break;

      final filterType = data[srcStart];
      final dstStart = row * bytesPerRow;

      for (var i = 0; i < bytesPerRow && srcStart + 1 + i < data.length; i++) {
        final raw = data[srcStart + 1 + i];
        final a = i >= bytesPerPixel
            ? result[dstStart + i - bytesPerPixel]
            : 0; // Left
        final b = prevRow[i]; // Above
        final c =
            i >= bytesPerPixel ? prevRow[i - bytesPerPixel] : 0; // Upper-left

        int decoded;
        switch (filterType) {
          case 0: // None
            decoded = raw;
            break;
          case 1: // Sub
            decoded = (raw + a) & 0xFF;
            break;
          case 2: // Up
            decoded = (raw + b) & 0xFF;
            break;
          case 3: // Average
            decoded = (raw + ((a + b) >> 1)) & 0xFF;
            break;
          case 4: // Paeth
            decoded = (raw + _paethPredictor(a, b, c)) & 0xFF;
            break;
          default:
            decoded = raw;
        }

        result[dstStart + i] = decoded;
      }

      // Copy current row to prevRow for next iteration
      for (var i = 0; i < bytesPerRow; i++) {
        prevRow[i] = result[dstStart + i];
      }
    }

    return result;
  }

  /// PNG Paeth predictor function.
  int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();

    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  /// Decodes RunLength-encoded data.
  Uint8List _decodeRunLength(Uint8List data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      final length = data[i++];

      if (length == 128) {
        // EOD marker
        break;
      } else if (length < 128) {
        // Copy next length+1 bytes literally
        final count = length + 1;
        for (var j = 0; j < count && i < data.length; j++) {
          result.add(data[i++]);
        }
      } else {
        // Repeat next byte 257-length times
        final count = 257 - length;
        if (i < data.length) {
          final byte = data[i++];
          for (var j = 0; j < count; j++) {
            result.add(byte);
          }
        }
      }
    }

    return Uint8List.fromList(result);
  }

  /// Decodes ASCII85-encoded data.
  Uint8List _decodeAscii85(Uint8List data) {
    final input = String.fromCharCodes(data)
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('<~', '')
        .replaceAll('~>', '');

    final result = <int>[];
    var i = 0;

    while (i < input.length) {
      if (input[i] == 'z') {
        result.addAll([0, 0, 0, 0]);
        i++;
        continue;
      }

      var tuple = 0;
      var count = 0;
      while (count < 5 && i < input.length) {
        final c = input.codeUnitAt(i) - 33;
        if (c >= 0 && c < 85) {
          tuple = tuple * 85 + c;
          count++;
        }
        i++;
      }

      // Pad if necessary
      for (var j = count; j < 5; j++) {
        tuple = tuple * 85 + 84;
      }

      final bytes = [
        (tuple >> 24) & 0xFF,
        (tuple >> 16) & 0xFF,
        (tuple >> 8) & 0xFF,
        tuple & 0xFF,
      ];

      result.addAll(bytes.take(count - 1));
    }

    return Uint8List.fromList(result);
  }

  /// Decodes ASCIIHex-encoded data.
  Uint8List _decodeAsciiHex(Uint8List data) {
    final hex = String.fromCharCodes(data).replaceAll(RegExp(r'\s|>'), '');
    final result = <int>[];

    for (var i = 0; i < hex.length; i += 2) {
      var chunk = hex.substring(i, i + 2 < hex.length ? i + 2 : hex.length);
      if (chunk.length == 1) chunk += '0';
      result.add(int.parse(chunk, radix: 16));
    }

    return Uint8List.fromList(result);
  }

  /// Decodes LZW-encoded data (used in older PDFs).
  Uint8List _decodeLZW(Uint8List input) {
    const clearCode = 256;
    const endCode = 257;
    const firstFreeCode = 258;

    final result = <int>[];
    var codeSize = 9;
    var code = 0;
    var bitsRemaining = 0;
    var bytePos = 0;

    // Initialize table
    var table = List<List<int>>.generate(4096, (i) => i < 256 ? [i] : [],
        growable: false);
    var nextCode = firstFreeCode;

    int readCode() {
      while (bitsRemaining < codeSize) {
        if (bytePos >= input.length) return endCode;
        code = (code << 8) | input[bytePos++];
        bitsRemaining += 8;
      }
      bitsRemaining -= codeSize;
      return (code >> bitsRemaining) & ((1 << codeSize) - 1);
    }

    var prevSeq = <int>[];

    while (true) {
      final c = readCode();
      if (c == endCode) break;

      if (c == clearCode) {
        // Reset
        codeSize = 9;
        nextCode = firstFreeCode;
        table = List<List<int>>.generate(4096, (i) => i < 256 ? [i] : [],
            growable: false);
        prevSeq = [];
        continue;
      }

      List<int> seq;
      if (c < nextCode) {
        seq = table[c];
      } else if (c == nextCode && prevSeq.isNotEmpty) {
        seq = [...prevSeq, prevSeq.first];
      } else {
        // Invalid code - try to recover
        break;
      }

      result.addAll(seq);

      if (prevSeq.isNotEmpty && nextCode < 4096) {
        table[nextCode++] = [...prevSeq, seq.first];
        if (nextCode >= (1 << codeSize) && codeSize < 12) {
          codeSize++;
        }
      }

      prevSeq = seq;
    }

    return Uint8List.fromList(result);
  }

  /// Counts total pages.
  int countPages() {
    if (pagesRef == 0) return 0;
    final pagesObj = getObject(pagesRef);
    if (pagesObj == null) return 0;

    final countMatch = RegExp(r'/Count\s+(\d+)').firstMatch(pagesObj.content);
    return countMatch != null ? int.tryParse(countMatch.group(1)!) ?? 0 : 0;
  }
}

/// PDF parsing exception.
class PdfParseException implements Exception {
  final String message;
  PdfParseException(this.message);

  @override
  String toString() => 'PdfParseException: $message';
}
