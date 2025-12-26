import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../docx_creator.dart';
import '../core/font_manager.dart';

/// Exports [DocxBuiltDocument] to .docx format.
class DocxExporter {
  final Map<String, Uint8List> _images = {};
  int _imageCounter = 0;
  int _uniqueIdCounter = 1;
  int _numIdCounter = 1;
  // final List<bool> _listTypes = []; // Removed in favor of _listAbstractNumMap
  final List<Uint8List> _imageBullets = [];
  final Map<int, int> _listAbstractNumMap = {}; // numId -> abstractNumId
  final Map<int, int> _abstractNumImageBulletMap =
      {}; // abstractNumId -> imageBulletIndex
  final Map<int, int> _preservedNumIds = {}; // sourceNumId -> exportedNumId
  final Map<int, int> _listStartOverrides = {}; // exportedNumId -> startIndex
  DocxBackgroundImage? _backgroundImage;
  final FontManager fontManager = FontManager();

  /// ID generator for unique element IDs (available for advanced usage).
  final DocxIdGenerator idGenerator = DocxIdGenerator();

  /// Optional validator for pre-export validation.
  /// If set, the document will be validated before export.
  final DocxValidator? validator;

  /// Creates a DocxExporter.
  ///
  /// Optionally provide a [validator] for pre-export validation.
  DocxExporter({this.validator});

  /// Exports the document to a file.
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    try {
      final bytes = await exportToBytes(doc);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      throw DocxExportException(
        'Failed to write file: $e',
        targetFormat: 'DOCX',
        context: filePath,
      );
    }
  }

  /// Exports the document to bytes.
  Future<Uint8List> exportToBytes(DocxBuiltDocument doc) async {
    // Run validation if validator is provided
    if (validator != null) {
      final isValid = validator!.validate(doc);
      if (!isValid) {
        throw DocxExportException(
          'Document validation failed: ${validator!.errors.join(", ")}',
          targetFormat: 'DOCX',
        );
      }
    }

    _images.clear();
    _imageCounter = 0;
    _uniqueIdCounter = 1;
    _numIdCounter = 1;
    _listAbstractNumMap.clear();
    _imageBullets.clear();
    _abstractNumImageBulletMap.clear();
    _preservedNumIds.clear();
    _listStartOverrides.clear();
    _backgroundImage = null;

    // Register document fonts
    for (var font in doc.fonts) {
      fontManager.registerFont(font);
    }

    // Process background image
    if (doc.section?.backgroundImage != null) {
      _backgroundImage = doc.section!.backgroundImage;
      _backgroundImage!.setRelationshipId('rIdBg');
      final ext = _backgroundImage!.normalizedExtension;
      _images['word/media/background.$ext'] = _backgroundImage!.bytes;
    }

    // Process images recursively
    final allImages = _collectImages(doc);
    for (var img in allImages) {
      _imageCounter++;
      final rId = 'rId${_imageCounter + 10}';
      img.setRelationshipId(rId, _uniqueIdCounter++);
      _images['word/media/image$_imageCounter.${img.extension}'] = img.bytes;
    }

    // Process lists recursively
    final allLists = _collectLists(doc);
    int abstractNumIdCounter = 2; // 0 and 1 are reserved for default styles

    for (var list in allLists) {
      int exportedNumId;
      final sourceNumId = list.numId;

      if (sourceNumId != null && _preservedNumIds.containsKey(sourceNumId)) {
        // Reuse existing exported ID for continuity
        exportedNumId = _preservedNumIds[sourceNumId]!;
      } else {
        // Create new exported ID
        exportedNumId = _numIdCounter++;
        if (sourceNumId != null) {
          _preservedNumIds[sourceNumId] = exportedNumId;
        }

        if (list.style.imageBulletBytes != null) {
          // Image Bullet List
          final bulletIndex = _imageBullets.length;
          _imageBullets.add(list.style.imageBulletBytes!);

          final absId = abstractNumIdCounter++;
          _abstractNumImageBulletMap[absId] = bulletIndex;
          _listAbstractNumMap[exportedNumId] = absId;
        } else {
          // Standard List
          _listAbstractNumMap[exportedNumId] = list.isOrdered ? 1 : 0;
          // Only apply start override if this is the start of the chain (new ID)
          if (list.isOrdered && list.startIndex > 1) {
            _listStartOverrides[exportedNumId] = list.startIndex;
          }
        }
      }

      list.numId = exportedNumId;
    }

    final archive = Archive();

    archive.addFile(_createContentTypes(doc));
    archive.addFile(_createRootRels(doc));
    archive.addFile(_createDocument(doc));
    archive.addFile(_createDocumentRels(doc));
    archive.addFile(_createSettings(doc));
    archive.addFile(_createStyles(doc));
    archive.addFile(_createFontTable(doc));
    archive.addFile(_createFontTableRels(doc)); // Add Font Table Rels
    archive.addFile(_createTheme(doc)); // Add Theme (Critical for fonts)

    archive.addFile(_createNumbering(doc));

    // Numbering Rels (for image bullets - check doc first for preservation)
    if (_imageBullets.isNotEmpty || doc.numberingRelsXml != null) {
      archive.addFile(_createNumberingRels(doc));

      // Add image bullet files (generated)
      for (int i = 0; i < _imageBullets.length; i++) {
        final filename = 'word/media/imageBullet$i.png';
        archive.addFile(
            ArchiveFile(filename, _imageBullets[i].length, _imageBullets[i]));
      }

      // Add original numbering images (preserved)
      if (doc.numberingImages.isNotEmpty) {
        doc.numberingImages.forEach((target, bytes) {
          final filename = target.startsWith('/')
              ? target.substring(1)
              : 'word/$target'; // Target is relative to word/ usually
          // Avoid duplicate entries if something overlaps (unlikely if naming differs)
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));
        });
      }
    }

    // Process fonts
    for (var font in fontManager.fonts) {
      final filename = font.preservedFilename != null
          ? 'word/${font.preservedFilename}'
          : 'word/fonts/${font.obfuscationKey}.odttf';
      archive.addFile(ArchiveFile(
          filename, font.obfuscatedBytes.length, font.obfuscatedBytes));
    }

    // Headers and Footers
    if (doc.section?.header != null) {
      archive.addFile(_createHeader(doc.section!.header!));
    }
    if (doc.section?.footer != null) {
      archive.addFile(_createFooter(doc.section!.footer!));
    }
    // Background header (for background image)
    if (_backgroundImage != null) {
      archive.addFile(_createBackgroundHeader(doc));
      archive.addFile(_createBackgroundHeaderRels(doc));
    }

    // Footnotes and Endnotes
    // Priority: Generated Objects > Raw XML (Round-trip)
    if (doc.footnotes != null && doc.footnotes!.isNotEmpty) {
      archive.addFile(_createFootnotes(doc.footnotes!));
    } else if (doc.footnotesXml != null) {
      archive.addFile(ArchiveFile(
        'word/footnotes.xml',
        utf8.encode(doc.footnotesXml!).length,
        utf8.encode(doc.footnotesXml!),
      ));
    }

    if (doc.endnotes != null && doc.endnotes!.isNotEmpty) {
      archive.addFile(_createEndnotes(doc.endnotes!));
    } else if (doc.endnotesXml != null) {
      archive.addFile(ArchiveFile(
        'word/endnotes.xml',
        utf8.encode(doc.endnotesXml!).length,
        utf8.encode(doc.endnotesXml!),
      ));
    }

    // Images
    for (var entry in _images.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    if (bytes.isEmpty) {
      throw DocxExportException('Failed to encode ZIP', targetFormat: 'DOCX');
    }

    return Uint8List.fromList(bytes);
  }

  ArchiveFile _createTheme(DocxBuiltDocument doc) {
    final themeXml = doc.themeXml ?? _defaultThemeXml;
    return ArchiveFile(
      'word/theme/theme1.xml',
      utf8.encode(themeXml).length,
      utf8.encode(themeXml),
    );
  }

  ArchiveFile _createContentTypes(DocxBuiltDocument doc) {
    if (doc.contentTypesXml != null) {
      return ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(doc.contentTypesXml!).length,
        utf8.encode(doc.contentTypesXml!),
      );
    }

    // Dynamic generation using ContentTypesGenerator
    final generator = ContentTypesGenerator();

    // Register standard parts
    generator.registerPart('/word/document.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml');
    generator.registerPart('/word/styles.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml');
    generator.registerPart('/word/settings.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml');
    generator.registerPart('/word/fontTable.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml');
    generator.registerPart('/word/numbering.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml');

    // Theme
    generator.registerPart('/word/theme/theme1.xml',
        'application/vnd.openxmlformats-officedocument.theme+xml');

    // Footnotes/Endnotes
    if (doc.footnotesXml != null) {
      generator.registerPart('/word/footnotes.xml',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml');
    }
    if (doc.endnotesXml != null) {
      generator.registerPart('/word/endnotes.xml',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml');
    }

    // Headers/Footers
    if (doc.section?.header != null) generator.registerHeader('header1.xml');
    if (doc.section?.footer != null) generator.registerFooter('footer1.xml');

    // Background Header
    if (_backgroundImage != null) {
      generator.registerHeader('header_bg.xml');
    }

    // Scan for images to register extensions
    for (var i = 0; i < _images.length; i++) {
      final key = _images.keys.elementAt(i);
      final ext = key.split('.').last.toLowerCase();
      // Ensure we register unique extensions
      final contentType = 'image/${ext == "jpg" ? "jpeg" : ext}';
      generator.registerExtension(ext, contentType);
    }

    // Ensure png is registered for image bullets
    if (_imageBullets.isNotEmpty) {
      generator.registerExtension('png', 'image/png');
    }

    final xml = generator.generate();
    return ArchiveFile(
      '[Content_Types].xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createRootRels(DocxBuiltDocument doc) {
    if (doc.rootRelsXml != null) {
      return ArchiveFile(
        '_rels/.rels',
        utf8.encode(doc.rootRelsXml!).length,
        utf8.encode(doc.rootRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId1');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
            );
            builder.attribute('Target', 'word/document.xml');
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      '_rels/.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createDocument(DocxBuiltDocument doc) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:document',
      nest: () {
        // Core WordprocessingML namespace
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        // DrawingML WordprocessingDrawing namespace
        builder.attribute(
          'xmlns:wp',
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
        );
        // Relationships namespace
        builder.attribute(
          'xmlns:r',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        );
        // DrawingML main namespace
        builder.attribute(
          'xmlns:a',
          'http://schemas.openxmlformats.org/drawingml/2006/main',
        );
        // Picture namespace
        builder.attribute(
          'xmlns:pic',
          'http://schemas.openxmlformats.org/drawingml/2006/picture',
        );
        // VML namespaces for legacy shapes
        builder.attribute(
          'xmlns:v',
          'urn:schemas-microsoft-com:vml',
        );
        builder.attribute(
          'xmlns:o',
          'urn:schemas-microsoft-com:office:office',
        );
        // Math namespace
        builder.attribute(
          'xmlns:m',
          'http://schemas.openxmlformats.org/officeDocument/2006/math',
        );
        // Markup Compatibility namespace
        builder.attribute(
          'xmlns:mc',
          'http://schemas.openxmlformats.org/markup-compatibility/2006',
        );
        // Word 2010 extensions
        builder.attribute(
          'xmlns:w14',
          'http://schemas.microsoft.com/office/word/2010/wordml',
        );
        // WordprocessingShape namespace (Word 2010+)
        builder.attribute(
          'xmlns:wps',
          'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
        );
        // WordprocessingGroup namespace (Word 2010+)
        builder.attribute(
          'xmlns:wpg',
          'http://schemas.microsoft.com/office/word/2010/wordprocessingGroup',
        );
        // DrawingML WordprocessingDrawing (Word 2010+)
        builder.attribute(
          'xmlns:wp14',
          'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing',
        );

        // Add background (color and/or image)
        _buildBackground(builder, doc);

        builder.element(
          'w:body',
          nest: () {
            // Background image is handled via header (not in body)
            for (var element in doc.elements) {
              element.buildXml(builder);
            }
            // Build section properties including background header reference
            _buildSectionProperties(builder, doc);
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/document.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  /// Builds the background element with color
  void _buildBackground(XmlBuilder builder, DocxBuiltDocument doc) {
    final hasColor = doc.section?.backgroundColor != null;

    if (hasColor) {
      builder.element(
        'w:background',
        nest: () {
          builder.attribute('w:color', doc.section!.backgroundColor!.hex);
        },
      );
    }
  }

  /// Builds section properties including header references for background image
  void _buildSectionProperties(XmlBuilder builder, DocxBuiltDocument doc) {
    builder.element(
      'w:sectPr',
      nest: () {
        // Reference background header if we have a background image
        if (_backgroundImage != null) {
          builder.element(
            'w:headerReference',
            nest: () {
              builder.attribute('w:type', 'default');
              builder.attribute('r:id', 'rIdBgHdr');
            },
          );
        }

        // Reference user-defined header if present
        if (doc.section?.header != null) {
          builder.element(
            'w:headerReference',
            nest: () {
              builder.attribute('w:type', 'first');
              builder.attribute('r:id', 'rId5');
            },
          );
        }

        // Reference user-defined footer if present
        if (doc.section?.footer != null) {
          builder.element(
            'w:footerReference',
            nest: () {
              builder.attribute('w:type', 'default');
              builder.attribute('r:id', 'rId6');
            },
          );
        }

        // Page size and orientation
        final section = doc.section;
        if (section != null) {
          final isLandscape =
              section.orientation == DocxPageOrientation.landscape;
          builder.element(
            'w:pgSz',
            nest: () {
              builder.attribute(
                'w:w',
                (isLandscape ? section.effectiveHeight : section.effectiveWidth)
                    .toString(),
              );
              builder.attribute(
                'w:h',
                (isLandscape ? section.effectiveWidth : section.effectiveHeight)
                    .toString(),
              );
              if (isLandscape) {
                builder.attribute('w:orient', 'landscape');
              }
            },
          );
          builder.element(
            'w:pgMar',
            nest: () {
              builder.attribute('w:top', section.marginTop.toString());
              builder.attribute('w:right', section.marginRight.toString());
              builder.attribute('w:bottom', section.marginBottom.toString());
              builder.attribute('w:left', section.marginLeft.toString());
              builder.attribute('w:header', '720');
              builder.attribute('w:footer', '720');
            },
          );
        } else {
          // Default page size (Letter)
          builder.element(
            'w:pgSz',
            nest: () {
              builder.attribute('w:w', '12240');
              builder.attribute('w:h', '15840');
            },
          );
          builder.element(
            'w:pgMar',
            nest: () {
              builder.attribute('w:top', '1440');
              builder.attribute('w:right', '1440');
              builder.attribute('w:bottom', '1440');
              builder.attribute('w:left', '1440');
              builder.attribute('w:header', '720');
              builder.attribute('w:footer', '720');
            },
          );
        }
      },
    );
  }

  /// Builds a paragraph containing the background image as an anchored drawing
  /// behind text. This uses DrawingML which is compatible with modern Word.
  void _buildBackgroundImageParagraph(XmlBuilder builder) {
    if (_backgroundImage == null) return;

    // Page dimensions in EMUs (1 inch = 914400 EMUs)
    // Letter size: 8.5 x 11 inches = 7772400 x 10058400 EMUs
    const int pageWidthEmu = 7772400; // 8.5 inches
    const int pageHeightEmu = 10058400; // 11 inches

    builder.element(
      'w:p',
      nest: () {
        builder.element(
          'w:r',
          nest: () {
            builder.element(
              'w:drawing',
              nest: () {
                builder.element(
                  'wp:anchor',
                  nest: () {
                    // Critical: place BEHIND document text
                    builder.attribute('behindDoc', '1');
                    builder.attribute('distT', '0');
                    builder.attribute('distB', '0');
                    builder.attribute('distL', '0');
                    builder.attribute('distR', '0');
                    builder.attribute('simplePos', '0');
                    // Use low relativeHeight to ensure it's behind everything
                    builder.attribute('relativeHeight', '251658240');
                    builder.attribute('locked', '1');
                    builder.attribute('layoutInCell', '0');
                    builder.attribute('allowOverlap', '1');

                    // Simple position (not used but required)
                    builder.element(
                      'wp:simplePos',
                      nest: () {
                        builder.attribute('x', '0');
                        builder.attribute('y', '0');
                      },
                    );

                    // Horizontal position - relative to page, from left edge
                    builder.element(
                      'wp:positionH',
                      nest: () {
                        builder.attribute('relativeFrom', 'page');
                        builder.element('wp:posOffset', nest: () {
                          builder.text('0');
                        });
                      },
                    );

                    // Vertical position - relative to page, from top edge
                    builder.element(
                      'wp:positionV',
                      nest: () {
                        builder.attribute('relativeFrom', 'page');
                        builder.element('wp:posOffset', nest: () {
                          builder.text('0');
                        });
                      },
                    );

                    // Extent (size of the image)
                    builder.element(
                      'wp:extent',
                      nest: () {
                        builder.attribute('cx', pageWidthEmu.toString());
                        builder.attribute('cy', pageHeightEmu.toString());
                      },
                    );

                    // Effect extent
                    builder.element(
                      'wp:effectExtent',
                      nest: () {
                        builder.attribute('l', '0');
                        builder.attribute('t', '0');
                        builder.attribute('r', '0');
                        builder.attribute('b', '0');
                      },
                    );

                    // No text wrapping (behind text)
                    builder.element('wp:wrapNone');

                    // Document properties
                    builder.element(
                      'wp:docPr',
                      nest: () {
                        builder.attribute('id', '1');
                        builder.attribute('name', 'Background Image');
                        builder.attribute('descr', 'Page background image');
                      },
                    );

                    // Graphic frame
                    builder.element(
                      'wp:cNvGraphicFramePr',
                      nest: () {
                        builder.element(
                          'a:graphicFrameLocks',
                          nest: () {
                            builder.attribute(
                              'xmlns:a',
                              'http://schemas.openxmlformats.org/drawingml/2006/main',
                            );
                            builder.attribute('noChangeAspect', '1');
                          },
                        );
                      },
                    );

                    // The actual graphic
                    builder.element(
                      'a:graphic',
                      nest: () {
                        builder.attribute(
                          'xmlns:a',
                          'http://schemas.openxmlformats.org/drawingml/2006/main',
                        );
                        builder.element(
                          'a:graphicData',
                          nest: () {
                            builder.attribute(
                              'uri',
                              'http://schemas.openxmlformats.org/drawingml/2006/picture',
                            );
                            builder.element(
                              'pic:pic',
                              nest: () {
                                builder.attribute(
                                  'xmlns:pic',
                                  'http://schemas.openxmlformats.org/drawingml/2006/picture',
                                );

                                // Non-visual properties
                                builder.element(
                                  'pic:nvPicPr',
                                  nest: () {
                                    builder.element(
                                      'pic:cNvPr',
                                      nest: () {
                                        builder.attribute('id', '0');
                                        builder.attribute(
                                          'name',
                                          'background.${_backgroundImage!.normalizedExtension}',
                                        );
                                      },
                                    );
                                    builder.element('pic:cNvPicPr');
                                  },
                                );

                                // Blob fill reference
                                builder.element(
                                  'pic:blipFill',
                                  nest: () {
                                    builder.element(
                                      'a:blip',
                                      nest: () {
                                        builder.attribute(
                                          'r:embed',
                                          _backgroundImage!.relationshipId!,
                                        );

                                        // Apply opacity if needed
                                        if (_backgroundImage!.opacity < 1.0) {
                                          builder.element(
                                            'a:alphaModFix',
                                            nest: () {
                                              final amt =
                                                  (_backgroundImage!.opacity *
                                                          100000)
                                                      .toInt();
                                              builder.attribute(
                                                'amt',
                                                amt.toString(),
                                              );
                                            },
                                          );
                                        }
                                      },
                                    );
                                    builder.element(
                                      'a:stretch',
                                      nest: () {
                                        builder.element('a:fillRect');
                                      },
                                    );
                                  },
                                );

                                // Shape properties
                                builder.element(
                                  'pic:spPr',
                                  nest: () {
                                    builder.element(
                                      'a:xfrm',
                                      nest: () {
                                        builder.element(
                                          'a:off',
                                          nest: () {
                                            builder.attribute('x', '0');
                                            builder.attribute('y', '0');
                                          },
                                        );
                                        builder.element(
                                          'a:ext',
                                          nest: () {
                                            builder.attribute(
                                              'cx',
                                              pageWidthEmu.toString(),
                                            );
                                            builder.attribute(
                                              'cy',
                                              pageHeightEmu.toString(),
                                            );
                                          },
                                        );
                                      },
                                    );
                                    builder.element(
                                      'a:prstGeom',
                                      nest: () {
                                        builder.attribute('prst', 'rect');
                                        builder.element('a:avLst');
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Creates a header file containing the background image
  ArchiveFile _createBackgroundHeader(DocxBuiltDocument doc) {
    if (doc.headerBgXml != null) {
      return ArchiveFile(
        'word/header_bg.xml',
        utf8.encode(doc.headerBgXml!).length,
        utf8.encode(doc.headerBgXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:hdr',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        builder.attribute(
          'xmlns:wp',
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
        );
        builder.attribute(
          'xmlns:r',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        );
        builder.attribute(
          'xmlns:a',
          'http://schemas.openxmlformats.org/drawingml/2006/main',
        );
        builder.attribute(
          'xmlns:pic',
          'http://schemas.openxmlformats.org/drawingml/2006/picture',
        );

        // Build the background image paragraph inside the header
        _buildBackgroundImageParagraph(builder);
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/header_bg.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  /// Creates relationships file for background header (references the image)
  ArchiveFile _createBackgroundHeaderRels(DocxBuiltDocument doc) {
    if (doc.headerBgRelsXml != null) {
      return ArchiveFile(
        'word/_rels/header_bg.xml.rels',
        utf8.encode(doc.headerBgRelsXml!).length,
        utf8.encode(doc.headerBgRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rIdBg');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
            );
            final ext = _backgroundImage!.normalizedExtension;
            builder.attribute('Target', 'media/background.$ext');
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/header_bg.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFootnotes(List<DocxFootnote> footnotes) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:footnotes',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );

        for (var note in footnotes) {
          note.buildXml(builder);
        }
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/footnotes.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createEndnotes(List<DocxEndnote> endnotes) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:endnotes',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );

        for (var note in endnotes) {
          note.buildXml(builder);
        }
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/endnotes.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createDocumentRels(DocxBuiltDocument doc) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId1');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles',
            );
            builder.attribute('Target', 'styles.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId2');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings',
            );
            builder.attribute('Target', 'settings.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId3');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable',
            );
            builder.attribute('Target', 'fontTable.xml');
          },
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId4');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering',
            );
            builder.attribute('Target', 'numbering.xml');
          },
        );

        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdTheme');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme');
          builder.attribute('Target', 'theme/theme1.xml');
        });

        // Header (rId5)
        if (doc.section?.header != null) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rId5');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header',
              );
              builder.attribute('Target', 'header1.xml');
            },
          );
        }

        // Footer (rId6)
        if (doc.section?.footer != null) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rId6');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer',
              );
              builder.attribute('Target', 'footer1.xml');
            },
          );
        }

        // Background image relationship
        if (_backgroundImage != null) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdBg');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              );
              final ext = _backgroundImage!.normalizedExtension;
              builder.attribute('Target', 'media/background.$ext');
            },
          );
          // Background header relationship
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdBgHdr');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header',
              );
              builder.attribute('Target', 'header_bg.xml');
            },
          );
        }
        // CORE RELATIONSHIPS (Styles, Settings, Numbering, etc.)
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdStyles');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles');
          builder.attribute('Target', 'styles.xml');
        });

        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdSettings');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings');
          builder.attribute('Target', 'settings.xml');
        });

        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdNumbering');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering');
          builder.attribute('Target', 'numbering.xml');
        });

        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdFontTable');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable');
          builder.attribute('Target', 'fontTable.xml');
        });

        if ((doc.footnotes != null && doc.footnotes!.isNotEmpty) ||
            doc.footnotesXml != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdFootnotes');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes');
            builder.attribute('Target', 'footnotes.xml');
          });
        }

        if ((doc.endnotes != null && doc.endnotes!.isNotEmpty) ||
            doc.endnotesXml != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdEndnotes');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes');
            builder.attribute('Target', 'endnotes.xml');
          });
        }

        // Images
        int rIdOffset = 10;
        for (int i = 0; i < _images.length; i++) {
          final key = _images.keys.elementAt(i);
          // Skip background image, already handled above
          if (key.contains('background.')) continue;
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rId${rIdOffset + i + 1}');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              );
              final ext = key.split('.').last;
              builder.attribute('Target', 'media/image${i + 1}.$ext');
            },
          );
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/document.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createSettings(DocxBuiltDocument doc) {
    if (doc.settingsXml != null) {
      return ArchiveFile(
        'word/settings.xml',
        utf8.encode(doc.settingsXml!).length,
        utf8.encode(doc.settingsXml!),
      );
    }
    final xml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:compat/><w:displayBackgroundShape/></w:settings>';
    return ArchiveFile(
      'word/settings.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createStyles(DocxBuiltDocument doc) {
    if (doc.stylesXml != null) {
      return ArchiveFile(
        'word/styles.xml',
        utf8.encode(doc.stylesXml!).length,
        utf8.encode(doc.stylesXml!),
      );
    }
    final xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr><w:spacing w:after="200" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/><w:b/><w:sz w:val="48"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="200"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="40"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720"/></w:pPr></w:style>
  <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>
</w:styles>''';
    return ArchiveFile(
      'word/styles.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFontTable(DocxBuiltDocument doc) {
    if (doc.fontTableXml != null) {
      return ArchiveFile(
        'word/fontTable.xml',
        utf8.encode(doc.fontTableXml!).length,
        utf8.encode(doc.fontTableXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:fonts',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        builder.attribute('xmlns:r',
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships');

        // Standard fonts
        builder.element('w:font', nest: () {
          builder.attribute('w:name', 'Calibri');
          builder.element('w:panose1', nest: () {
            builder.attribute('w:val', '020F0502020204030204');
          });
        });
        builder.element('w:font', nest: () {
          builder.attribute('w:name', 'Calibri Light');
          builder.element('w:panose1', nest: () {
            builder.attribute('w:val', '020F0302020204030204');
          });
        });
        builder.element('w:font', nest: () {
          builder.attribute('w:name', 'Times New Roman');
          builder.element('w:panose1', nest: () {
            builder.attribute('w:val', '02020603050405020304');
          });
        });

        // Embedded fonts
        int i = 0;
        for (var font in fontManager.fonts) {
          builder.element('w:font', nest: () {
            builder.attribute('w:name', font.familyName);
            builder.element('w:embedRegular', nest: () {
              builder.attribute('r:id', 'rIdFont$i');
              builder.attribute('w:fontKey', '{${font.obfuscationKey}}');
            });
          });
          i++;
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/fontTable.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFontTableRels(DocxBuiltDocument doc) {
    if (doc.fontTableRelsXml != null) {
      return ArchiveFile(
        'word/_rels/fontTable.xml.rels',
        utf8.encode(doc.fontTableRelsXml!).length,
        utf8.encode(doc.fontTableRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );

        int i = 0;
        for (var font in fontManager.fonts) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdFont$i');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font',
              );
              builder.attribute('Target', 'fonts/${font.obfuscationKey}.odttf');
            },
          );
          i++;
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/fontTable.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createNumbering(DocxBuiltDocument doc) {
    if (doc.numberingXml != null) {
      return ArchiveFile(
        'word/numbering.xml',
        utf8.encode(doc.numberingXml!).length,
        utf8.encode(doc.numberingXml!),
      );
    }
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:v="urn:schemas-microsoft-com:vml" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:w10="urn:schemas-microsoft-com:office:word" '
      'xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml">',
    );

    // Bullet characters for each level
    const bulletChars = ['•', '○', '▪', '•', '○', '▪', '•', '○', '▪'];

    // Image Bullets definitions
    const vmlShapetype =
        '<v:shapetype id="_x0000_t75" coordsize="21600,21600" o:spt="75" o:preferrelative="t" path="m@4@5l@4@11@9@11@9@5xe" filled="f" stroked="f">'
        '<v:stroke joinstyle="miter"/>'
        '<v:formulas>'
        '<v:f eqn="if lineDrawn pixelLineWidth 0"/>'
        '<v:f eqn="sum @0 1 0"/>'
        '<v:f eqn="sum 0 0 @1"/>'
        '<v:f eqn="prod @2 1 2"/>'
        '<v:f eqn="prod @3 21600 pixelWidth"/>'
        '<v:f eqn="prod @3 21600 pixelHeight"/>'
        '<v:f eqn="sum @0 0 1"/>'
        '<v:f eqn="prod @6 1 2"/>'
        '<v:f eqn="prod @7 21600 pixelWidth"/>'
        '<v:f eqn="sum @8 21600 0"/>'
        '<v:f eqn="prod @7 21600 pixelHeight"/>'
        '<v:f eqn="sum @10 21600 0"/>'
        '</v:formulas>'
        '<v:path o:extrusionok="f" gradientshapeok="t" o:connecttype="rect"/>'
        '<o:lock v:ext="edit" aspectratio="t"/>'
        '</v:shapetype>';

    for (int i = 0; i < _imageBullets.length; i++) {
      buffer.writeln('  <w:numPicBullet w:numPicBulletId="$i">');
      buffer.writeln('    <w:pict>');
      if (i == 0) buffer.writeln(vmlShapetype);
      buffer.writeln(
          '      <v:shape id="_x0000_i102$i" type="#_x0000_t75" style="width:9pt;height:9pt" o:bullet="t">');
      buffer.writeln('      <v:imagedata r:id="rIdImgBullet$i" o:title=""/>');
      buffer.writeln('    </v:shape></w:pict>');
      buffer.writeln('  </w:numPicBullet>');
    }

    // Abstract numbering for bullets (abstractNumId=0) - 9 levels
    buffer.writeln('  <w:abstractNum w:abstractNumId="0">');
    buffer.writeln('    <w:nsid w:val="FFFFFF89"/>');
    buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');
    buffer.writeln('    <w:tmpl w:val="29761A62"/>');

    for (int lvl = 0; lvl < 9; lvl++) {
      final indent = (lvl + 1) * 720;
      final bullet = bulletChars[lvl];
      buffer.writeln('''
    <w:lvl w:ilvl="$lvl">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="$bullet"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
        <w:ind w:left="$indent" w:hanging="360"/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/>
      </w:rPr>
    </w:lvl>''');
    }
    buffer.writeln('  </w:abstractNum>');

    // Number formats for each level of ordered lists
    const numFormats = [
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
    ];
    const lvlTextFormats = [
      '%1.',
      '%2.',
      '%3.',
      '%4.',
      '%5.',
      '%6.',
      '%7.',
      '%8.',
      '%9.'
    ];

    // Abstract numbering for decimals (abstractNumId=1) - 9 levels
    buffer.writeln('  <w:abstractNum w:abstractNumId="1">');
    buffer.writeln('    <w:nsid w:val="FFFFFF88"/>');
    buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');
    buffer.writeln('    <w:tmpl w:val="D0A62B40"/>');

    for (int lvl = 0; lvl < 9; lvl++) {
      final indent = (lvl + 1) * 720;
      final numFmt = numFormats[lvl];
      final lvlText = lvlTextFormats[lvl];
      buffer.writeln('''
    <w:lvl w:ilvl="$lvl">
      <w:start w:val="1"/>
      <w:numFmt w:val="$numFmt"/>
      <w:lvlText w:val="$lvlText"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
        <w:ind w:left="$indent" w:hanging="360"/>
      </w:pPr>
    </w:lvl>''');
    }
    buffer.writeln('  </w:abstractNum>');

    // Abstract Custom Image Bullets
    _abstractNumImageBulletMap.forEach((absId, bulletIndex) {
      buffer.writeln('  <w:abstractNum w:abstractNumId="$absId">');
      buffer.writeln(
          '    <w:nsid w:val="${(100000 + absId).toRadixString(16)}"/>');
      buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');

      for (int lvl = 0; lvl < 9; lvl++) {
        // Use 360 twips (0.25 inch) step for image bullets to match demo.docx fidelity
        // Level 0 starts at 720 (0.5 inch), then increments by 360.
        final indent = 720 + (lvl * 360);
        buffer.writeln('''
      <w:lvl w:ilvl="$lvl">
        <w:start w:val="1"/>
        <w:numFmt w:val="bullet"/>
        <w:lvlText w:val=""/>
        <w:lvlPicBulletId w:val="$bulletIndex"/>
        <w:lvlJc w:val="left"/>
        <w:pPr>
          <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
          <w:ind w:left="$indent" w:hanging="360"/>
        </w:pPr>
        <w:rPr>
          <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/>
          <w:color w:val="auto"/>
        </w:rPr>
      </w:lvl>''');
      }
      buffer.writeln('  </w:abstractNum>');
    });

    // Generate num instances linking to correct abstractNumId
    _listAbstractNumMap.forEach((numId, absId) {
      buffer.write(
        '  <w:num w:numId="$numId"><w:abstractNumId w:val="$absId"/>',
      );
      if (_listStartOverrides.containsKey(numId)) {
        final start = _listStartOverrides[numId];
        buffer.write(
          '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="$start"/></w:lvlOverride>',
        );
      }
      buffer.writeln('</w:num>');
    });

    buffer.writeln('</w:numbering>');
    final xml = buffer.toString();
    return ArchiveFile(
      'word/numbering.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createNumberingRels(DocxBuiltDocument doc) {
    if (doc.numberingRelsXml != null) {
      return ArchiveFile(
        'word/_rels/numbering.xml.rels',
        utf8.encode(doc.numberingRelsXml!).length,
        utf8.encode(doc.numberingRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );

        for (int i = 0; i < _imageBullets.length; i++) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdImgBullet$i');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              );
              builder.attribute('Target', 'media/imageBullet$i.png');
            },
          );
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/numbering.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createHeader(dynamic header) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:hdr',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        (header as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/header1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  ArchiveFile _createFooter(dynamic footer) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'w:ftr',
      nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        (footer as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/footer1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  List<DocxInlineImage> _collectImages(DocxBuiltDocument doc) {
    final images = <DocxInlineImage>[];
    for (var element in doc.elements) {
      _collectImagesFromNode(element, images);
    }
    if (doc.section?.header != null) {
      for (var child in doc.section!.header!.children) {
        _collectImagesFromNode(child, images);
      }
    }
    if (doc.section?.footer != null) {
      for (var child in doc.section!.footer!.children) {
        _collectImagesFromNode(child, images);
      }
    }
    return images;
  }

  void _collectImagesFromNode(DocxNode node, List<DocxInlineImage> images) {
    if (node is DocxImage) {
      images.add(node.asInline);
    } else if (node is DocxInlineImage) {
      images.add(node);
    } else if (node is DocxParagraph) {
      for (var child in node.children) {
        _collectImagesFromNode(child, images);
      }
    } else if (node is DocxTable) {
      for (var row in node.rows) {
        for (var cell in row.cells) {
          for (var child in cell.children) {
            _collectImagesFromNode(child, images);
          }
        }
      }
    } else if (node is DocxHeader) {
      for (var child in (node).children) {
        _collectImagesFromNode(child, images);
      }
    } else if (node is DocxFooter) {
      for (var child in (node).children) {
        _collectImagesFromNode(child, images);
      }
    }
  }

  List<DocxList> _collectLists(DocxBuiltDocument doc) {
    final lists = <DocxList>[];
    for (var element in doc.elements) {
      _collectListsFromNode(element, lists);
    }
    return lists;
  }

  void _collectListsFromNode(DocxNode node, List<DocxList> lists) {
    if (node is DocxList) {
      lists.add(node);
      // Also collect nested lists within list items
      for (var item in node.items) {
        for (var child in item.children) {
          _collectListsFromNode(child, lists);
        }
      }
    } else if (node is DocxTable) {
      for (var row in node.rows) {
        for (var cell in row.cells) {
          for (var child in cell.children) {
            _collectListsFromNode(child, lists);
          }
        }
      }
    } else if (node is DocxParagraph) {
      // Paragraphs might contain inline elements with nested content
      for (var child in node.children) {
        _collectListsFromNode(child, lists);
      }
    }
  }
}

const String _defaultThemeXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Cambria"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="50000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="35000"><a:schemeClr val="phClr"><a:tint val="37000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:tint val="15000"/><a:satMod val="350000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="16200000" scaled="1"/></a:gradFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:shade val="51000"/><a:satMod val="130000"/></a:schemeClr></a:gs><a:gs pos="80000"><a:schemeClr val="phClr"><a:shade val="93000"/><a:satMod val="130000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="94000"/><a:satMod val="135000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="16200000" scaled="0"/></a:gradFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"><a:shade val="95000"/><a:satMod val="105000"/></a:schemeClr></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="25400" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="38100" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst><a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="38000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle><a:effectStyle><a:effectLst><a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="35000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle><a:effectStyle><a:effectLst><a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="35000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="40000"/><a:satMod val="350000"/></a:schemeClr></a:gs><a:gs pos="40000"><a:schemeClr val="phClr"><a:tint val="45000"/><a:shade val="99000"/><a:satMod val="350000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="20000"/><a:satMod val="255000"/></a:schemeClr></a:gs></a:gsLst><a:path path="circle"><a:fillToRect l="50000" t="-80000" r="50000" b="180000"/></a:path></a:gradFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="80000"/><a:satMod val="300000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="30000"/><a:satMod val="200000"/></a:schemeClr></a:gs></a:gsLst><a:path path="circle"><a:fillToRect l="50000" t="50000" r="50000" b="50000"/></a:path></a:gradFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
  <a:objectDefaults/>
  <a:extraClrSchemeLst/>
</a:theme>''';
