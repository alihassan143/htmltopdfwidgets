import 'pdf_parser.dart';

/// Types of PDF form fields.
enum PdfFieldType {
  text,
  checkbox,
  radio,
  button,
  choice,
  signature,
  unknown,
}

/// Represents a PDF form field.
class PdfFormField {
  /// Full qualified name of the field.
  final String name;

  /// Partial name (just this field's name, not including parent).
  final String? partialName;

  /// Type of form field.
  final PdfFieldType type;

  /// Current value of the field.
  final dynamic value;

  /// Default value.
  final dynamic defaultValue;

  /// Options for choice fields (dropdown/listbox).
  final List<String>? options;

  /// Whether the field is read-only.
  final bool isReadOnly;

  /// Whether the field is required.
  final bool isRequired;

  /// Whether the field should not be exported.
  final bool noExport;

  /// Maximum length for text fields.
  final int? maxLength;

  /// Whether multiline is allowed (text fields).
  final bool isMultiline;

  /// Whether password masking is used (text fields).
  final bool isPassword;

  /// Whether file select is enabled (text fields).
  final bool isFileSelect;

  /// Whether the field is a comb field (text fields).
  final bool isComb;

  /// Whether rich text is allowed (text fields).
  final bool isRichText;

  /// Whether this is a combo box or list box (choice fields).
  final bool isComboBox;

  /// Whether editing is allowed in combo box (choice fields).
  final bool isEditable;

  /// Whether multiple selections are allowed (choice fields).
  final bool isMultiSelect;

  /// Page number where this field appears.
  final int? pageNumber;

  /// Bounding rectangle.
  final List<double>? rect;

  /// Child fields (for radio button groups).
  final List<PdfFormField> children;

  PdfFormField({
    required this.name,
    this.partialName,
    required this.type,
    this.value,
    this.defaultValue,
    this.options,
    this.isReadOnly = false,
    this.isRequired = false,
    this.noExport = false,
    this.maxLength,
    this.isMultiline = false,
    this.isPassword = false,
    this.isFileSelect = false,
    this.isComb = false,
    this.isRichText = false,
    this.isComboBox = false,
    this.isEditable = false,
    this.isMultiSelect = false,
    this.pageNumber,
    this.rect,
    this.children = const [],
  });

  @override
  String toString() => 'PdfFormField($name, type: $type, value: $value)';
}

/// Extracts form fields from PDF documents.
class PdfFormExtractor {
  final PdfParser _parser;

  PdfFormExtractor(this._parser);

  /// Whether the document contains a form.
  bool hasForm() {
    final catalogObj = _parser.getObject(_parser.rootRef);
    if (catalogObj == null) return false;

    return catalogObj.content.contains('/AcroForm');
  }

  /// Extracts all form fields.
  List<PdfFormField> extractFields() {
    if (!hasForm()) return [];

    final catalogObj = _parser.getObject(_parser.rootRef);
    if (catalogObj == null) return [];

    // Get AcroForm reference
    final acroFormMatch =
        RegExp(r'/AcroForm\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (acroFormMatch == null) {
      // Try inline AcroForm dictionary
      final inlineMatch =
          RegExp(r'/AcroForm\s*<<([^>]*)>>').firstMatch(catalogObj.content);
      if (inlineMatch != null) {
        return _parseFieldsFromContent(inlineMatch.group(1)!, '');
      }
      return [];
    }

    final acroFormRef = int.parse(acroFormMatch.group(1)!);
    final acroFormObj = _parser.getObject(acroFormRef);
    if (acroFormObj == null) return [];

    return _parseFieldsFromContent(acroFormObj.content, '');
  }

  /// Parses fields from AcroForm content.
  List<PdfFormField> _parseFieldsFromContent(
      String content, String parentName) {
    final fields = <PdfFormField>[];

    // Get Fields array
    final fieldsMatch = RegExp(r'/Fields\s*\[([^\]]*)\]').firstMatch(content);
    if (fieldsMatch == null) return fields;

    final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(fieldsMatch.group(1)!);
    for (final ref in refs) {
      final fieldRef = int.parse(ref.group(1)!);
      final field = _parseField(fieldRef, parentName);
      if (field != null) {
        fields.add(field);
      }
    }

    return fields;
  }

  /// Parses a single field.
  PdfFormField? _parseField(int fieldRef, String parentName) {
    final obj = _parser.getObject(fieldRef);
    if (obj == null) return null;

    final content = obj.content;

    // Parse partial name
    String? partialName;
    final tMatch = RegExp(r'/T\s*\(([^)]*)\)').firstMatch(content);
    if (tMatch != null) {
      partialName = _decodeLiteralString(tMatch.group(1)!);
    } else {
      final hexTMatch = RegExp(r'/T\s*<([^>]*)>').firstMatch(content);
      if (hexTMatch != null) {
        partialName = _decodeHexString(hexTMatch.group(1)!);
      }
    }

    // Build full name
    final fullName = parentName.isEmpty
        ? (partialName ?? 'Field$fieldRef')
        : '$parentName.${partialName ?? 'Field$fieldRef'}';

    // Parse field type
    final type = _parseFieldType(content);

    // Parse value
    dynamic value = _parseValue(content, '/V');
    dynamic defaultValue = _parseValue(content, '/DV');

    // Parse flags
    final flags = _parseFlags(content);

    // Parse options for choice fields
    List<String>? options;
    if (type == PdfFieldType.choice) {
      options = _parseOptions(content);
    }

    // Parse max length
    int? maxLength;
    final maxLenMatch = RegExp(r'/MaxLen\s+(\d+)').firstMatch(content);
    if (maxLenMatch != null) {
      maxLength = int.tryParse(maxLenMatch.group(1)!);
    }

    // Parse rectangle
    List<double>? rect;
    final rectMatch = RegExp(r'/Rect\s*\[\s*([^\]]+)\]').firstMatch(content);
    if (rectMatch != null) {
      rect = RegExp(r'-?[\d.]+')
          .allMatches(rectMatch.group(1)!)
          .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
          .toList();
    }

    // Parse page reference
    int? pageNumber;
    final pMatch = RegExp(r'/P\s+(\d+)\s+\d+\s+R').firstMatch(content);
    if (pMatch != null) {
      pageNumber = int.tryParse(pMatch.group(1)!);
    }

    // Parse child fields (Kids)
    final children = <PdfFormField>[];
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(content);
    if (kidsMatch != null) {
      final kidRefs =
          RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final kidRef in kidRefs) {
        final child = _parseField(int.parse(kidRef.group(1)!), fullName);
        if (child != null) {
          children.add(child);
        }
      }
    }

    // Determine checkbox/radio state
    if (type == PdfFieldType.checkbox || type == PdfFieldType.radio) {
      value = _parseCheckboxValue(content);
    }

    return PdfFormField(
      name: fullName,
      partialName: partialName,
      type: type,
      value: value,
      defaultValue: defaultValue,
      options: options,
      isReadOnly: (flags & 1) != 0,
      isRequired: (flags & 2) != 0,
      noExport: (flags & 4) != 0,
      maxLength: maxLength,
      isMultiline: (flags & 0x1000) != 0,
      isPassword: (flags & 0x2000) != 0,
      isFileSelect: (flags & 0x100000) != 0,
      isComb: (flags & 0x1000000) != 0,
      isRichText: (flags & 0x2000000) != 0,
      isComboBox: (flags & 0x20000) != 0,
      isEditable: (flags & 0x40000) != 0,
      isMultiSelect: (flags & 0x200000) != 0,
      pageNumber: pageNumber,
      rect: rect,
      children: children,
    );
  }

  /// Parses field type from content.
  PdfFieldType _parseFieldType(String content) {
    final ftMatch = RegExp(r'/FT\s*/(\w+)').firstMatch(content);
    if (ftMatch == null) {
      // Check if it has Kids - might be a container
      if (content.contains('/Kids')) {
        return PdfFieldType.unknown;
      }
      return PdfFieldType.unknown;
    }

    switch (ftMatch.group(1)!) {
      case 'Tx':
        return PdfFieldType.text;
      case 'Btn':
        // Distinguish between checkbox, radio, and pushbutton
        final ffMatch = RegExp(r'/Ff\s+(\d+)').firstMatch(content);
        if (ffMatch != null) {
          final ff = int.parse(ffMatch.group(1)!);
          if ((ff & 0x10000) != 0) {
            // Pushbutton
            return PdfFieldType.button;
          } else if ((ff & 0x8000) != 0) {
            // Radio
            return PdfFieldType.radio;
          }
        }
        return PdfFieldType.checkbox;
      case 'Ch':
        return PdfFieldType.choice;
      case 'Sig':
        return PdfFieldType.signature;
      default:
        return PdfFieldType.unknown;
    }
  }

  /// Parses field flags.
  int _parseFlags(String content) {
    final ffMatch = RegExp(r'/Ff\s+(\d+)').firstMatch(content);
    return ffMatch != null ? (int.tryParse(ffMatch.group(1)!) ?? 0) : 0;
  }

  /// Parses a value from content.
  dynamic _parseValue(String content, String key) {
    // Try literal string
    final literalMatch = RegExp('$key\\s*\\(([^)]*)\\)').firstMatch(content);
    if (literalMatch != null) {
      return _decodeLiteralString(literalMatch.group(1)!);
    }

    // Try hex string
    final hexMatch = RegExp('$key\\s*<([^>]*)>').firstMatch(content);
    if (hexMatch != null) {
      return _decodeHexString(hexMatch.group(1)!);
    }

    // Try name
    final nameMatch = RegExp('$key\\s*/(\\w+)').firstMatch(content);
    if (nameMatch != null) {
      return nameMatch.group(1)!;
    }

    // Try number
    final numMatch = RegExp('$key\\s+(-?[\\d.]+)').firstMatch(content);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!);
    }

    return null;
  }

  /// Parses checkbox/radio button value.
  bool _parseCheckboxValue(String content) {
    // Check /AS (appearance state)
    final asMatch = RegExp(r'/AS\s*/(\w+)').firstMatch(content);
    if (asMatch != null) {
      final state = asMatch.group(1)!;
      return state != 'Off';
    }

    // Check /V
    final vMatch = RegExp(r'/V\s*/(\w+)').firstMatch(content);
    if (vMatch != null) {
      final state = vMatch.group(1)!;
      return state != 'Off';
    }

    return false;
  }

  /// Parses options for choice fields.
  List<String> _parseOptions(String content) {
    final options = <String>[];

    // Try /Opt array
    final optMatch = RegExp(r'/Opt\s*\[([^\]]*)\]').firstMatch(content);
    if (optMatch != null) {
      final optContent = optMatch.group(1)!;

      // Options can be strings or arrays of [export_value display_value]
      final literalPattern = RegExp(r'\(([^)]*)\)');
      for (final match in literalPattern.allMatches(optContent)) {
        options.add(_decodeLiteralString(match.group(1)!));
      }
    }

    return options;
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

  /// Gets a field by name.
  PdfFormField? getField(String name) {
    final fields = extractFields();
    return _findField(fields, name);
  }

  /// Recursively finds a field by name.
  PdfFormField? _findField(List<PdfFormField> fields, String name) {
    for (final field in fields) {
      if (field.name == name) return field;
      final found = _findField(field.children, name);
      if (found != null) return found;
    }
    return null;
  }

  /// Gets all field names.
  List<String> getFieldNames() {
    final fields = extractFields();
    return _collectFieldNames(fields);
  }

  /// Recursively collects field names.
  List<String> _collectFieldNames(List<PdfFormField> fields) {
    final names = <String>[];
    for (final field in fields) {
      names.add(field.name);
      names.addAll(_collectFieldNames(field.children));
    }
    return names;
  }

  /// Gets form data as a map of field names to values.
  Map<String, dynamic> getFormData() {
    final fields = extractFields();
    return _collectFormData(fields, {});
  }

  /// Recursively collects form data.
  Map<String, dynamic> _collectFormData(
      List<PdfFormField> fields, Map<String, dynamic> data) {
    for (final field in fields) {
      if (field.value != null) {
        data[field.name] = field.value;
      }
      _collectFormData(field.children, data);
    }
    return data;
  }
}
