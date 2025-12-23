import '../../docx_creator.dart';

/// Validates DOCX document structure before export.
///
/// This class performs various checks to ensure the document is well-formed
/// and will produce a valid .docx file.
class DocxValidator {
  final List<String> _errors = [];
  final List<String> _warnings = [];

  /// Gets all validation errors.
  List<String> get errors => List.unmodifiable(_errors);

  /// Gets all validation warnings.
  List<String> get warnings => List.unmodifiable(_warnings);

  /// Returns true if there are no errors.
  bool get isValid => _errors.isEmpty;

  /// Validates a document and returns whether it's valid.
  ///
  /// Use [errors] and [warnings] to get details after calling this.
  bool validate(DocxBuiltDocument doc) {
    _errors.clear();
    _warnings.clear();

    _validateElements(doc.elements);
    _validateSection(doc.section);
    _validateImages(doc);
    _validateTables(doc);

    return isValid;
  }

  void _validateElements(List<DocxNode> elements) {
    if (elements.isEmpty) {
      _warnings.add('Document has no content elements');
    }

    for (var i = 0; i < elements.length; i++) {
      _validateElement(elements[i], 'elements[$i]');
    }
  }

  void _validateElement(DocxNode element, String path) {
    if (element is DocxParagraph) {
      _validateParagraph(element, path);
    } else if (element is DocxTable) {
      _validateTable(element, path);
    } else if (element is DocxList) {
      _validateList(element, path);
    }
  }

  void _validateParagraph(DocxParagraph para, String path) {
    for (var i = 0; i < para.children.length; i++) {
      final child = para.children[i];
      if (child is DocxText) {
        // Check for invalid characters in text
        if (child.content.contains('\x00')) {
          _errors.add('$path.children[$i]: Text contains null character');
        }
      } else if (child is DocxInlineImage) {
        if (child.bytes.isEmpty) {
          _errors.add('$path.children[$i]: Image has empty bytes');
        }
        if (child.width <= 0 || child.height <= 0) {
          _warnings.add('$path.children[$i]: Image has invalid dimensions');
        }
      }
    }
  }

  void _validateTable(DocxTable table, String path) {
    if (table.rows.isEmpty) {
      _warnings.add('$path: Table has no rows');
      return;
    }

    // Check that all rows have consistent cell counts (accounting for spans)
    final expectedCols =
        table.rows.first.cells.fold(0, (sum, c) => sum + c.colSpan);

    for (var i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final actualCols = row.cells.fold(0, (sum, c) => sum + c.colSpan);
      if (actualCols != expectedCols) {
        _warnings.add(
          '$path.rows[$i]: Column count ($actualCols) differs from first row ($expectedCols)',
        );
      }

      // Validate cells
      for (var j = 0; j < row.cells.length; j++) {
        final cell = row.cells[j];
        if (cell.colSpan < 1) {
          _errors.add(
              '$path.rows[$i].cells[$j]: Invalid colSpan (${cell.colSpan})');
        }
        if (cell.rowSpan < 1) {
          _errors.add(
              '$path.rows[$i].cells[$j]: Invalid rowSpan (${cell.rowSpan})');
        }
      }
    }

    // Validate grid columns if present
    if (table.gridColumns != null && table.gridColumns!.isNotEmpty) {
      if (table.gridColumns!.length != expectedCols) {
        _warnings.add(
          '$path: Grid columns (${table.gridColumns!.length}) don\'t match cell count ($expectedCols)',
        );
      }
      for (var i = 0; i < table.gridColumns!.length; i++) {
        if (table.gridColumns![i] <= 0) {
          _warnings.add('$path: Grid column $i has non-positive width');
        }
      }
    }
  }

  void _validateList(DocxList list, String path) {
    if (list.items.isEmpty) {
      _warnings.add('$path: List has no items');
    }
  }

  void _validateSection(DocxSectionDef? section) {
    if (section == null) return;

    // Validate margins
    if (section.marginTop < 0 ||
        section.marginBottom < 0 ||
        section.marginLeft < 0 ||
        section.marginRight < 0) {
      _warnings.add('Section has negative margins');
    }

    // Validate custom dimensions if custom size
    if (section.pageSize == DocxPageSize.custom) {
      if (section.customWidth == null || section.customWidth! <= 0) {
        _errors.add('Custom page size requires positive customWidth');
      }
      if (section.customHeight == null || section.customHeight! <= 0) {
        _errors.add('Custom page size requires positive customHeight');
      }
    }

    // Validate header
    if (section.header != null) {
      for (var i = 0; i < section.header!.children.length; i++) {
        _validateElement(section.header!.children[i], 'header.children[$i]');
      }
    }

    // Validate footer
    if (section.footer != null) {
      for (var i = 0; i < section.footer!.children.length; i++) {
        _validateElement(section.footer!.children[i], 'footer.children[$i]');
      }
    }

    // Validate background image
    if (section.backgroundImage != null) {
      if (section.backgroundImage!.bytes.isEmpty) {
        _errors.add('Background image has empty bytes');
      }
    }
  }

  void _validateImages(DocxBuiltDocument doc) {
    final images = _collectImages(doc);
    final seenBytes = <int, String>{};

    for (var i = 0; i < images.length; i++) {
      final img = images[i];

      // Check for empty images
      if (img.bytes.isEmpty) {
        _errors.add('Image $i has empty bytes');
        continue;
      }

      // Check for valid extension
      final ext = img.extension.toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'tif'].contains(ext)) {
        _warnings.add('Image $i has unusual extension: $ext');
      }

      // Check for duplicate images (optimization opportunity)
      final hash = img.bytes.length;
      if (seenBytes.containsKey(hash)) {
        _warnings.add('Image $i may be a duplicate of ${seenBytes[hash]}');
      }
      seenBytes[hash] = 'image $i';
    }
  }

  void _validateTables(DocxBuiltDocument doc) {
    // Validated in _validateElements
  }

  List<DocxInlineImage> _collectImages(DocxBuiltDocument doc) {
    final images = <DocxInlineImage>[];
    _collectImagesFromNodes(doc.elements, images);
    if (doc.section?.header != null) {
      _collectImagesFromNodes(doc.section!.header!.children, images);
    }
    if (doc.section?.footer != null) {
      _collectImagesFromNodes(doc.section!.footer!.children, images);
    }
    return images;
  }

  void _collectImagesFromNodes(
      List<DocxNode> nodes, List<DocxInlineImage> images) {
    for (var node in nodes) {
      if (node is DocxParagraph) {
        for (var child in node.children) {
          if (child is DocxInlineImage) {
            images.add(child);
          }
        }
      } else if (node is DocxTable) {
        for (var row in node.rows) {
          for (var cell in row.cells) {
            _collectImagesFromNodes(cell.children, images);
          }
        }
      } else if (node is DocxList) {
        for (var item in node.items) {
          _collectImagesFromNodes(item.children, images);
        }
      }
    }
  }

  /// Returns a formatted string of all errors and warnings.
  @override
  String toString() {
    final buffer = StringBuffer();
    if (_errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (var e in _errors) {
        buffer.writeln('  - $e');
      }
    }
    if (_warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (var w in _warnings) {
        buffer.writeln('  - $w');
      }
    }
    if (isValid && _warnings.isEmpty) {
      buffer.writeln('Document is valid');
    }
    return buffer.toString();
  }
}
