import 'dart:io';
import 'dart:typed_data';

import 'pdf_parser.dart';
import 'pdf_types.dart';

/// Extracts images from PDF pages.
class PdfImageExtractor {
  late PdfParser parser;
  final List<String> warnings = [];

  PdfImageExtractor(this.parser);

  /// Creates extractor for late parser initialization
  PdfImageExtractor.create();

  /// Extracts XObject references from page resources.
  Map<String, PdfXObjectInfo> extractXObjects(String content, int pageRef) {
    final xObjects = <String, PdfXObjectInfo>{};

    final resourcesContent = _getResourcesContent(content);
    if (resourcesContent == null) return xObjects;

    // Find XObject dictionary
    final xobjDictMatch = RegExp(r'/XObject\s*<<([^>]+(?:>>|>(?!>)))')
        .firstMatch(resourcesContent);
    if (xobjDictMatch != null) {
      _parseXObjectDict(xobjDictMatch.group(1)!, xObjects);
    } else {
      // Check for XObject reference
      final xobjRefMatch =
          RegExp(r'/XObject\s+(\d+)\s+\d+\s+R').firstMatch(resourcesContent);
      if (xobjRefMatch != null) {
        final xobjDictObj = parser.getObject(int.parse(xobjRefMatch.group(1)!));
        if (xobjDictObj != null) {
          _parseXObjectDict(xobjDictObj.content, xObjects);
        }
      }
    }

    return xObjects;
  }

  String? _getResourcesContent(String content) {
    // Check for reference first
    final refMatch =
        RegExp(r'/Resources\s+(\d+)\s+\d+\s+R').firstMatch(content);
    if (refMatch != null) {
      final resourcesObj = parser.getObject(int.parse(refMatch.group(1)!));
      return resourcesObj?.content;
    }

    // Direct dictionary
    final resTag = '/Resources';
    final resIndex = content.indexOf(resTag);
    if (resIndex == -1) return null;

    final openIndex = content.indexOf('<<', resIndex);
    if (openIndex == -1) return null;

    var depth = 1;
    var current = openIndex + 2;
    while (depth > 0 && current < content.length) {
      if (content.startsWith('<<', current)) {
        depth++;
        current += 2;
      } else if (content.startsWith('>>', current)) {
        depth--;
        if (depth == 0) break;
        current += 2;
      } else {
        current++;
      }
    }

    return content.substring(openIndex + 2, current);
  }

  void _parseXObjectDict(
      String dictContent, Map<String, PdfXObjectInfo> xObjects) {
    final refs = RegExp(r'/(\w+)\s+(\d+)\s+\d+\s+R').allMatches(dictContent);

    for (final match in refs) {
      final name = match.group(1)!;
      final objRef = int.parse(match.group(2)!);

      final obj = parser.getObject(objRef);
      if (obj == null) continue;

      // Check if this is an Image XObject
      if (!obj.content.contains('/Subtype /Image') &&
          !obj.content.contains('/Subtype/Image')) {
        continue;
      }

      // Extract image properties
      final widthMatch = RegExp(r'/Width\s+(\d+)').firstMatch(obj.content);
      final heightMatch = RegExp(r'/Height\s+(\d+)').firstMatch(obj.content);
      final bitsMatch =
          RegExp(r'/BitsPerComponent\s+(\d+)').firstMatch(obj.content);
      final colorSpaceMatch =
          RegExp(r'/ColorSpace\s*/(\w+)').firstMatch(obj.content);

      final imgWidth =
          widthMatch != null ? int.parse(widthMatch.group(1)!) : 100;
      final imgHeight =
          heightMatch != null ? int.parse(heightMatch.group(1)!) : 100;
      final bitsPerComponent =
          bitsMatch != null ? int.parse(bitsMatch.group(1)!) : 8;

      var colorSpace = 'DeviceRGB';
      // Check for indexed color space: [/Indexed /DeviceRGB 255 <...>]
      final indexedMatch =
          RegExp(r'/ColorSpace\s*\[\s*/Indexed\s+/(\w+)\s+(\d+)\s+')
              .firstMatch(obj.content);
      if (indexedMatch != null) {
        colorSpace = 'Indexed';
        // Note: Palette extraction would go here
      } else if (colorSpaceMatch != null) {
        colorSpace = colorSpaceMatch.group(1)!;
      }

      // Parse filters
      final filters = _parseFilters(obj.content);
      final filter = filters.isNotEmpty ? filters.first : 'Unknown';

      // Get image stream data
      Uint8List? imageBytes;
      final streamStart = obj.content.indexOf('stream');
      if (streamStart != -1) {
        imageBytes = _extractImageBytes(obj, objRef, filters);
      }

      xObjects[name] = PdfXObjectInfo(
        name: name,
        objRef: objRef,
        width: imgWidth,
        height: imgHeight,
        filter: filter,
        bytes: imageBytes,
        subtype: '/Image',
        colorSpace: colorSpace,
        bitsPerComponent: bitsPerComponent,
      );
    }
  }

  List<String> _parseFilters(String content) {
    // Array format: /Filter [/Filter1 /Filter2]
    final arrayMatch = RegExp(r'/Filter\s*\[([^\]]+)\]').firstMatch(content);
    if (arrayMatch != null) {
      return RegExp(r'/(\w+)')
          .allMatches(arrayMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }

    // Single filter: /Filter /DCTDecode
    final singleMatch = RegExp(r'/Filter\s*/(\w+)').firstMatch(content);
    if (singleMatch != null) {
      return [singleMatch.group(1)!];
    }

    return [];
  }

  Uint8List? _extractImageBytes(
      PdfObject obj, int objRef, List<String> filters) {
    try {
      final objOffset = parser.objects[objRef]?.offset ?? 0;
      final objContent = parser.content.substring(objOffset);
      final objStreamStart = objContent.indexOf('stream');
      if (objStreamStart == -1) return null;

      var absStart = objOffset + objStreamStart + 6;
      // Skip newlines after 'stream'
      while (absStart < parser.data.length &&
          (parser.data[absStart] == 13 || parser.data[absStart] == 10)) {
        absStart++;
      }

      // Find length
      final lengthMatch = RegExp(r'/Length\s+(\d+)').firstMatch(obj.content);
      int streamLength;

      if (lengthMatch != null) {
        streamLength = int.parse(lengthMatch.group(1)!);
      } else {
        // Try to find endstream
        final endstreamPos = objContent.indexOf('endstream', objStreamStart);
        if (endstreamPos == -1) return null;
        streamLength = endstreamPos - objStreamStart - 6;
        // Adjust for newlines
        while (streamLength > 0 &&
            (objContent.codeUnitAt(objStreamStart + 6 + streamLength - 1) ==
                    13 ||
                objContent.codeUnitAt(objStreamStart + 6 + streamLength - 1) ==
                    10)) {
          streamLength--;
        }
      }

      if (absStart + streamLength > parser.data.length) {
        streamLength = parser.data.length - absStart;
      }

      var imageBytes = parser.data.sublist(absStart, absStart + streamLength);

      // Parse decode params
      final decodeParms = parser.parseDecodeParms(obj.content);

      // Apply filters to decode (but keep DCTDecode as is - it's JPEG)
      for (var i = filters.length - 1; i >= 0; i--) {
        final filter = filters[i];
        if (filter == 'DCTDecode' || filter == 'JPXDecode') {
          // JPEG/JPEG2000 - keep as is
          continue;
        }

        final parms = i < decodeParms.length ? decodeParms[i] : null;
        imageBytes = parser.applyFilterWithParams(filter, imageBytes, parms);
      }

      return imageBytes;
    } catch (e) {
      warnings.add('Could not extract image: $e');
      return null;
    }
  }

  /// Encodes raw RGB data as PNG format.
  /// Returns the PNG bytes or null if encoding fails.
  Uint8List? encodeRgbToPng(Uint8List rgbData, int width, int height,
      {String colorSpace = 'DeviceRGB', int bitsPerComponent = 8}) {
    try {
      // Determine bytes per pixel based on color space
      int bytesPerPixel;
      int colorType;
      switch (colorSpace) {
        case 'DeviceGray':
          bytesPerPixel = 1;
          colorType = 0; // Grayscale
          break;
        case 'DeviceRGB':
          bytesPerPixel = 3;
          colorType = 2; // RGB
          break;
        case 'DeviceCMYK':
          // Convert CMYK to RGB first (simplified)
          bytesPerPixel = 4;
          colorType = 2; // Will be converted to RGB
          break;
        default:
          bytesPerPixel = 3;
          colorType = 2;
      }

      final expectedSize = width * height * bytesPerPixel;
      if (rgbData.length < expectedSize) {
        warnings.add('Image data too small: ${rgbData.length} < $expectedSize');
        return null;
      }

      // Build PNG file
      final png = BytesBuilder();

      // PNG signature
      png.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      // IHDR chunk
      final ihdr = BytesBuilder();
      ihdr.add(_int32BE(width));
      ihdr.add(_int32BE(height));
      ihdr.addByte(8); // bit depth
      ihdr.addByte(colorType == 0 ? 0 : 2); // color type (0=gray, 2=RGB)
      ihdr.addByte(0); // compression
      ihdr.addByte(0); // filter
      ihdr.addByte(0); // interlace
      _writeChunk(png, 'IHDR', ihdr.toBytes());

      // IDAT chunk - compress raw data with filter byte per row
      final rawRows = BytesBuilder();
      final rowBytes = width * (colorType == 0 ? 1 : 3);

      for (var y = 0; y < height; y++) {
        rawRows.addByte(0); // No filter
        final rowStart = y * rowBytes;
        if (rowStart + rowBytes <= rgbData.length) {
          rawRows.add(rgbData.sublist(rowStart, rowStart + rowBytes));
        } else {
          // Pad with zeros if data is short
          final available = rgbData.length - rowStart;
          if (available > 0) {
            rawRows.add(rgbData.sublist(rowStart));
          }
          rawRows.add(List.filled(rowBytes - available.clamp(0, rowBytes), 0));
        }
      }

      final compressed = zlib.encode(rawRows.toBytes());
      _writeChunk(png, 'IDAT', Uint8List.fromList(compressed));

      // IEND chunk
      _writeChunk(png, 'IEND', Uint8List(0));

      return png.toBytes();
    } catch (e) {
      warnings.add('PNG encoding failed: $e');
      return null;
    }
  }

  List<int> _int32BE(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  void _writeChunk(BytesBuilder png, String type, Uint8List data) {
    png.add(_int32BE(data.length));
    final typeBytes = type.codeUnits;
    png.add(typeBytes);
    png.add(data);

    // CRC32 of type + data
    final crcData = [...typeBytes, ...data];
    final crc = _crc32(crcData);
    png.add(_int32BE(crc));
  }

  int _crc32(List<int> data) {
    // CRC32 lookup table
    const table = [
      0x00000000,
      0x77073096,
      0xee0e612c,
      0x990951ba,
      0x076dc419,
      0x706af48f,
      0xe963a535,
      0x9e6495a3,
      0x0edb8832,
      0x79dcb8a4,
      0xe0d5e91e,
      0x97d2d988,
      0x09b64c2b,
      0x7eb17cbd,
      0xe7b82d07,
      0x90bf1d91,
      0x1db71064,
      0x6ab020f2,
      0xf3b97148,
      0x84be41de,
      0x1adad47d,
      0x6ddde4eb,
      0xf4d4b551,
      0x83d385c7,
      0x136c9856,
      0x646ba8c0,
      0xfd62f97a,
      0x8a65c9ec,
      0x14015c4f,
      0x63066cd9,
      0xfa0f3d63,
      0x8d080df5,
      0x3b6e20c8,
      0x4c69105e,
      0xd56041e4,
      0xa2677172,
      0x3c03e4d1,
      0x4b04d447,
      0xd20d85fd,
      0xa50ab56b,
      0x35b5a8fa,
      0x42b2986c,
      0xdbbbc9d6,
      0xacbcf940,
      0x32d86ce3,
      0x45df5c75,
      0xdcd60dcf,
      0xabd13d59,
      0x26d930ac,
      0x51de003a,
      0xc8d75180,
      0xbfd06116,
      0x21b4f4b5,
      0x56b3c423,
      0xcfba9599,
      0xb8bda50f,
      0x2802b89e,
      0x5f058808,
      0xc60cd9b2,
      0xb10be924,
      0x2f6f7c87,
      0x58684c11,
      0xc1611dab,
      0xb6662d3d,
      0x76dc4190,
      0x01db7106,
      0x98d220bc,
      0xefd5102a,
      0x71b18589,
      0x06b6b51f,
      0x9fbfe4a5,
      0xe8b8d433,
      0x7807c9a2,
      0x0f00f934,
      0x9609a88e,
      0xe10e9818,
      0x7f6a0dbb,
      0x086d3d2d,
      0x91646c97,
      0xe6635c01,
      0x6b6b51f4,
      0x1c6c6162,
      0x856530d8,
      0xf262004e,
      0x6c0695ed,
      0x1b01a57b,
      0x8208f4c1,
      0xf50fc457,
      0x65b0d9c6,
      0x12b7e950,
      0x8bbeb8ea,
      0xfcb9887c,
      0x62dd1ddf,
      0x15da2d49,
      0x8cd37cf3,
      0xfbd44c65,
      0x4db26158,
      0x3ab551ce,
      0xa3bc0074,
      0xd4bb30e2,
      0x4adfa541,
      0x3dd895d7,
      0xa4d1c46d,
      0xd3d6f4fb,
      0x4369e96a,
      0x346ed9fc,
      0xad678846,
      0xda60b8d0,
      0x44042d73,
      0x33031de5,
      0xaa0a4c5f,
      0xdd0d7d43,
      0x5005713c,
      0x270241aa,
      0xbe0b1010,
      0xc90c2086,
      0x5768b525,
      0x206f85b3,
      0xb966d409,
      0xce61e49f,
      0x5edef90e,
      0x29d9c998,
      0xb0d09822,
      0xc7d7a8b4,
      0x59b33d17,
      0x2eb40d81,
      0xb7bd5c3b,
      0xc0ba6cad,
      0xedb88320,
      0x9abfb3b6,
      0x03b6e20c,
      0x74b1d29a,
      0xead54739,
      0x9dd277af,
      0x04db2615,
      0x73dc1683,
      0xe3630b12,
      0x94643b84,
      0x0d6d6a3e,
      0x7a6a5aa8,
      0xe40ecf0b,
      0x9309ff9d,
      0x0a00ae27,
      0x7d079eb1,
      0xf00f9344,
      0x8708a3df,
      0x1e01f268,
      0x6906c2fe,
      0xf762575d,
      0x806567cb,
      0x196c3671,
      0x6e6b06e7,
      0xfed41b76,
      0x89d32be0,
      0x10da7a5a,
      0x67dd4acc,
      0xf9b9df6f,
      0x8ebeeff9,
      0x17b7be43,
      0x60b08ed5,
      0xd6d6a3e8,
      0xa1d1937e,
      0x38d8c2c4,
      0x4fdff252,
      0xd1bb67f1,
      0xa6bc5767,
      0x3fb506dd,
      0x48b2364b,
      0xd80d2bda,
      0xaf0a1b4c,
      0x36034af6,
      0x41047a60,
      0xdf60efc3,
      0xa867df55,
      0x316e8eef,
      0x4669be79,
      0xcb61b38c,
      0xbc66831a,
      0x256fd2a0,
      0x5268e236,
      0xcc0c7795,
      0xbb0b4703,
      0x220216b9,
      0x5505262f,
      0xc5ba3bbe,
      0xb2bd0b28,
      0x2bb45a92,
      0x5cb36a04,
      0xc2d7ffa7,
      0xb5d0cf31,
      0x2cd99e8b,
      0x5bdeae1d,
      0x9b64c2b0,
      0xec63f226,
      0x756aa39c,
      0x026d930a,
      0x9c0906a9,
      0xeb0e363f,
      0x72076785,
      0x05005713,
      0x95bf4a82,
      0xe2b87a14,
      0x7bb12bae,
      0x0cb61b38,
      0x92d28e9b,
      0xe5d5be0d,
      0x7cdcefb7,
      0x0bdbdf21,
      0x86d3d2d4,
      0xf1d4e242,
      0x68ddb3f8,
      0x1fda836e,
      0x81be16cd,
      0xf6b9265b,
      0x6fb077e1,
      0x18b74777,
      0x88085ae6,
      0xff0f6a70,
      0x66063bca,
      0x11010b5c,
      0x8f659eff,
      0xf862ae69,
      0x616bffd3,
      0x166ccf45,
      0xa00ae278,
      0xd70dd2ee,
      0x4e048354,
      0x3903b3c2,
      0xa7672661,
      0xd06016f7,
      0x4969474d,
      0x3e6e77db,
      0xaed16a4a,
      0xd9d65adc,
      0x40df0b66,
      0x37d83bf0,
      0xa9bcae53,
      0xdebb9ec5,
      0x47b2cf7f,
      0x30b5ffe9,
      0xbdbdf21c,
      0xcabac28a,
      0x53b39330,
      0x24b4a3a6,
      0xbad03605,
      0xcdd706b3,
      0x54de5729,
      0x23d967bf,
      0xb3667a2e,
      0xc4614ab8,
      0x5d681b02,
      0x2a6f2b94,
      0xb40bbe37,
      0xc30c8ea1,
      0x5a05df1b,
      0x2d02ef8d,
    ];

    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Gets image file extension from filter.
  String getImageExtension(String filter) {
    switch (filter) {
      case 'DCTDecode':
        return 'jpeg';
      case 'JPXDecode':
        return 'jp2';
      case 'JBIG2Decode':
        return 'jbig2';
      case 'CCITTFaxDecode':
        return 'tiff';
      default:
        return 'png';
    }
  }
}
