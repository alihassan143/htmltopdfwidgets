import 'pdf_parser.dart';

/// PDF document metadata.
///
/// Contains standard PDF info dictionary fields plus XMP metadata.
/// All fields are nullable as documents may not include them.
class PdfMetadata {
  /// Document title.
  final String? title;

  /// Document author.
  final String? author;

  /// Document subject/description.
  final String? subject;

  /// Application that created the original document.
  final String? creator;

  /// Application that produced the PDF.
  final String? producer;

  /// Keywords associated with the document.
  final String? keywords;

  /// Date the document was created.
  final DateTime? creationDate;

  /// Date the document was last modified.
  final DateTime? modificationDate;

  /// PDF version (e.g., "1.4", "1.7").
  final String pdfVersion;

  /// Custom metadata fields.
  final Map<String, String> custom;

  /// Whether the document is encrypted.
  final bool isEncrypted;

  /// Total page count.
  final int pageCount;

  PdfMetadata({
    this.title,
    this.author,
    this.subject,
    this.creator,
    this.producer,
    this.keywords,
    this.creationDate,
    this.modificationDate,
    required this.pdfVersion,
    this.custom = const {},
    this.isEncrypted = false,
    this.pageCount = 0,
  });

  @override
  String toString() {
    return 'PdfMetadata('
        'title: $title, '
        'author: $author, '
        'pages: $pageCount, '
        'version: $pdfVersion)';
  }
}

/// Extracts metadata from a PDF document.
class PdfMetadataExtractor {
  final PdfParser _parser;

  PdfMetadataExtractor(this._parser);

  /// Extracts all available metadata from the document.
  PdfMetadata extract() {
    final infoDict = _parseInfoDictionary();
    final isEncrypted = _checkEncryption();

    return PdfMetadata(
      title: infoDict['Title'],
      author: infoDict['Author'],
      subject: infoDict['Subject'],
      creator: infoDict['Creator'],
      producer: infoDict['Producer'],
      keywords: infoDict['Keywords'],
      creationDate: _parseDate(infoDict['CreationDate']),
      modificationDate: _parseDate(infoDict['ModDate']),
      pdfVersion: _parser.version,
      custom: _extractCustomFields(infoDict),
      isEncrypted: isEncrypted,
      pageCount: _parser.countPages(),
    );
  }

  /// Parses the /Info dictionary.
  Map<String, String> _parseInfoDictionary() {
    final result = <String, String>{};

    // Get Info object reference from trailer
    final infoRef = _parser.namedObjects['Info'];
    if (infoRef == null) {
      // Try to find Info in trailer content
      final trailerPos = _parser.content.lastIndexOf('trailer');
      if (trailerPos != -1) {
        final trailerEnd = _parser.content.indexOf('>>', trailerPos);
        if (trailerEnd != -1) {
          final trailerStr =
              _parser.content.substring(trailerPos, trailerEnd + 2);
          final infoMatch =
              RegExp(r'/Info\s+(\d+)\s+\d+\s+R').firstMatch(trailerStr);
          if (infoMatch != null) {
            final ref = int.tryParse(infoMatch.group(1)!);
            if (ref != null) {
              return _parseInfoObject(ref);
            }
          }
        }
      }
      return result;
    }

    return _parseInfoObject(infoRef);
  }

  /// Parses Info object content.
  Map<String, String> _parseInfoObject(int objRef) {
    final result = <String, String>{};
    final obj = _parser.getObject(objRef);
    if (obj == null) return result;

    // Standard fields
    final fields = [
      'Title',
      'Author',
      'Subject',
      'Keywords',
      'Creator',
      'Producer',
      'CreationDate',
      'ModDate',
    ];

    for (final field in fields) {
      final value = _extractStringValue(obj.content, field);
      if (value != null) {
        result[field] = value;
      }
    }

    // Extract any additional custom fields
    final customPattern = RegExp(r'/([A-Za-z]+)\s*(\([^)]*\)|<[^>]*>)');
    for (final match in customPattern.allMatches(obj.content)) {
      final key = match.group(1)!;
      if (!fields.contains(key) && !result.containsKey(key)) {
        final rawValue = match.group(2)!;
        result[key] = _decodeStringValue(rawValue);
      }
    }

    return result;
  }

  /// Extracts a string value for a given key.
  String? _extractStringValue(String content, String key) {
    // Try literal string: /Key (value)
    final literalPattern = RegExp('/$key\\s*\\(([^)]*)\\)');
    final literalMatch = literalPattern.firstMatch(content);
    if (literalMatch != null) {
      return _decodeLiteralString(literalMatch.group(1)!);
    }

    // Try hex string: /Key <hex>
    final hexPattern = RegExp('/$key\\s*<([^>]*)>');
    final hexMatch = hexPattern.firstMatch(content);
    if (hexMatch != null) {
      return _decodeHexString(hexMatch.group(1)!);
    }

    return null;
  }

  /// Decodes a raw string value (literal or hex).
  String _decodeStringValue(String raw) {
    if (raw.startsWith('(') && raw.endsWith(')')) {
      return _decodeLiteralString(raw.substring(1, raw.length - 1));
    } else if (raw.startsWith('<') && raw.endsWith('>')) {
      return _decodeHexString(raw.substring(1, raw.length - 1));
    }
    return raw;
  }

  /// Decodes a literal string, handling escape sequences.
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
          case 'b':
            buffer.write('\b');
            break;
          case 'f':
            buffer.write('\f');
            break;
          case '(':
          case ')':
          case '\\':
            buffer.write(next);
            break;
          default:
            // Octal escape
            if (next.codeUnitAt(0) >= 48 && next.codeUnitAt(0) <= 55) {
              var octal = next;
              var j = i + 2;
              while (j < str.length &&
                  j < i + 4 &&
                  str[j].codeUnitAt(0) >= 48 &&
                  str[j].codeUnitAt(0) <= 55) {
                octal += str[j];
                j++;
              }
              buffer.writeCharCode(int.parse(octal, radix: 8));
              i = j - 1;
            } else {
              buffer.write(next);
            }
        }
        i += 2;
      } else {
        buffer.write(str[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// Decodes a hex string.
  String _decodeHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');

    // Check for UTF-16BE BOM (FEFF)
    if (clean.length >= 4 && clean.substring(0, 4).toUpperCase() == 'FEFF') {
      return _decodeUtf16BE(clean.substring(4));
    }

    // PDFDocEncoding for non-BOM strings
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i += 2) {
      final end = i + 2 <= clean.length ? i + 2 : clean.length;
      var chunk = clean.substring(i, end);
      if (chunk.length == 1) chunk += '0';
      final code = int.parse(chunk, radix: 16);
      buffer.writeCharCode(_pdfDocEncodingToUnicode(code));
    }
    return buffer.toString();
  }

  /// Converts PDFDocEncoding to Unicode.
  /// PDFDocEncoding is identical to Latin-1 for 0-127 and 160-255,
  /// but has special mappings for 128-159 and 127.
  static int _pdfDocEncodingToUnicode(int code) {
    const map = <int, int>{
      0x80: 0x2022, // bullet
      0x81: 0x2020, // dagger
      0x82: 0x2021, // daggerdbl
      0x83: 0x2026, // ellipsis
      0x84: 0x2014, // emdash
      0x85: 0x2013, // endash
      0x86: 0x0192, // florin
      0x87: 0x2044, // fraction
      0x88: 0x2039, // guilsinglleft
      0x89: 0x203A, // guilsinglright
      0x8A: 0x2212, // minus
      0x8B: 0x2030, // perthousand
      0x8C: 0x201A, // quotesinglebase
      0x8D: 0x201C, // quotedblleft
      0x8E: 0x201D, // quotedblright
      0x8F: 0x2018, // quoteleft
      0x90: 0x2019, // quoteright
      0x91: 0x201E, // quotedblbase
      0x92: 0x2122, // trademark
      0x93: 0xFB01, // fi
      0x94: 0xFB02, // fl
      0x95: 0x0141, // Lslash
      0x96: 0x0152, // OE
      0x97: 0x0160, // Scaron
      0x98: 0x0178, // Ydieresis
      0x99: 0x017D, // Zcaron
      0x9A: 0x0131, // dotlessi
      0x9B: 0x0142, // lslash
      0x9C: 0x0153, // oe
      0x9D: 0x0161, // scaron
      0x9E: 0x017E, // zcaron
      0x9F: 0xFFFF, // undefined
      0xA0: 0x20AC, // Euro
      0xAD: 0x00AD, // soft hyphen
    };
    return map[code] ?? code;
  }

  /// Decodes UTF-16BE encoded hex string.
  String _decodeUtf16BE(String hex) {
    final buffer = StringBuffer();
    for (var i = 0; i < hex.length; i += 4) {
      if (i + 4 <= hex.length) {
        final charCode = int.parse(hex.substring(i, i + 4), radix: 16);
        buffer.writeCharCode(charCode);
      }
    }
    return buffer.toString();
  }

  /// Parses a PDF date string.
  /// Format: D:YYYYMMDDHHmmSSOHH'mm'
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    // Remove D: prefix
    var str = dateStr;
    if (str.startsWith('D:')) {
      str = str.substring(2);
    }

    // Parse components
    try {
      final year = int.parse(str.substring(0, 4));
      final month = str.length >= 6 ? int.parse(str.substring(4, 6)) : 1;
      final day = str.length >= 8 ? int.parse(str.substring(6, 8)) : 1;
      final hour = str.length >= 10 ? int.parse(str.substring(8, 10)) : 0;
      final minute = str.length >= 12 ? int.parse(str.substring(10, 12)) : 0;
      final second = str.length >= 14 ? int.parse(str.substring(12, 14)) : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }

  /// Extracts custom (non-standard) fields.
  Map<String, String> _extractCustomFields(Map<String, String> allFields) {
    final standardFields = {
      'Title',
      'Author',
      'Subject',
      'Keywords',
      'Creator',
      'Producer',
      'CreationDate',
      'ModDate',
    };

    return Map.fromEntries(
      allFields.entries.where((e) => !standardFields.contains(e.key)),
    );
  }

  /// Checks if document is encrypted.
  bool _checkEncryption() {
    // Look for /Encrypt in trailer
    final trailerPos = _parser.content.lastIndexOf('trailer');
    if (trailerPos != -1) {
      final trailerEnd = _parser.content.indexOf('>>', trailerPos);
      if (trailerEnd != -1) {
        final trailerStr =
            _parser.content.substring(trailerPos, trailerEnd + 2);
        return trailerStr.contains('/Encrypt');
      }
    }

    // Also check xref stream for /Encrypt
    return _parser.content.contains('/Encrypt');
  }
}

/// XMP (Extensible Metadata Platform) metadata.
///
/// Contains Dublin Core and other XMP fields.
class XmpMetadata {
  /// Dublin Core: Title
  final Map<String, String>? dcTitle;

  /// Dublin Core: Creator(s)
  final List<String>? dcCreator;

  /// Dublin Core: Description
  final Map<String, String>? dcDescription;

  /// Dublin Core: Subject/Keywords
  final List<String>? dcSubject;

  /// Dublin Core: Rights
  final String? dcRights;

  /// XMP: Create date
  final DateTime? xmpCreateDate;

  /// XMP: Modify date
  final DateTime? xmpModifyDate;

  /// XMP: Creator tool
  final String? xmpCreatorTool;

  /// PDF: Producer
  final String? pdfProducer;

  /// PDF: Keywords
  final String? pdfKeywords;

  /// Raw XMP XML content
  final String? rawXml;

  XmpMetadata({
    this.dcTitle,
    this.dcCreator,
    this.dcDescription,
    this.dcSubject,
    this.dcRights,
    this.xmpCreateDate,
    this.xmpModifyDate,
    this.xmpCreatorTool,
    this.pdfProducer,
    this.pdfKeywords,
    this.rawXml,
  });

  /// Extracts XMP metadata from PDF parser.
  static XmpMetadata? extract(PdfParser parser) {
    // Find Metadata stream reference in catalog
    final catalogObj = parser.getObject(parser.rootRef);
    if (catalogObj == null) return null;

    final metadataMatch =
        RegExp(r'/Metadata\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (metadataMatch == null) return null;

    final metadataRef = int.parse(metadataMatch.group(1)!);
    final xmpContent = parser.getStreamContent(metadataRef);
    if (xmpContent == null) return null;

    return _parseXmp(xmpContent);
  }

  /// Parses XMP XML content.
  static XmpMetadata _parseXmp(String xml) {
    // Simple regex-based parsing for common fields
    String? extractSimple(String namespace, String field) {
      final pattern = RegExp('$namespace:$field>([^<]+)<');
      final match = pattern.firstMatch(xml);
      return match?.group(1)?.trim();
    }

    List<String>? extractList(String namespace, String field) {
      final containerPattern =
          RegExp('$namespace:$field[^>]*>([\\s\\S]*?)</$namespace:$field');
      final match = containerPattern.firstMatch(xml);
      if (match == null) return null;

      final items = <String>[];
      final liPattern = RegExp(r'<rdf:li[^>]*>([^<]+)</rdf:li>');
      for (final liMatch in liPattern.allMatches(match.group(1)!)) {
        items.add(liMatch.group(1)!.trim());
      }
      return items.isEmpty ? null : items;
    }

    Map<String, String>? extractAlt(String namespace, String field) {
      final containerPattern =
          RegExp('$namespace:$field[^>]*>([\\s\\S]*?)</$namespace:$field');
      final match = containerPattern.firstMatch(xml);
      if (match == null) return null;

      final result = <String, String>{};
      final liPattern =
          RegExp(r'<rdf:li\s+xml:lang="([^"]+)"[^>]*>([^<]+)</rdf:li>');
      for (final liMatch in liPattern.allMatches(match.group(1)!)) {
        result[liMatch.group(1)!] = liMatch.group(2)!.trim();
      }
      return result.isEmpty ? null : result;
    }

    DateTime? parseXmpDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return XmpMetadata(
      dcTitle: extractAlt('dc', 'title'),
      dcCreator: extractList('dc', 'creator'),
      dcDescription: extractAlt('dc', 'description'),
      dcSubject: extractList('dc', 'subject'),
      dcRights: extractSimple('dc', 'rights'),
      xmpCreateDate: parseXmpDate(extractSimple('xmp', 'CreateDate')),
      xmpModifyDate: parseXmpDate(extractSimple('xmp', 'ModifyDate')),
      xmpCreatorTool: extractSimple('xmp', 'CreatorTool'),
      pdfProducer: extractSimple('pdf', 'Producer'),
      pdfKeywords: extractSimple('pdf', 'Keywords'),
      rawXml: xml,
    );
  }
}
