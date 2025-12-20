import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../docx_creator.dart';

/// Exports [DocxBuiltDocument] to .docx format.
class DocxExporter {
  final Map<String, Uint8List> _images = {};
  int _imageCounter = 0;
  int _uniqueIdCounter = 1;
  int _numIdCounter = 1;
  final List<bool> _listTypes = []; // true = ordered, false = bullet
  DocxBackgroundImage? _backgroundImage;

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
    _images.clear();
    _imageCounter = 0;
    _uniqueIdCounter = 1;
    _numIdCounter = 1;
    _listTypes.clear();
    _backgroundImage = null;

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
    for (var list in allLists) {
      list.numId = _numIdCounter++;
      _listTypes.add(list.isOrdered);
    }

    final archive = Archive();

    archive.addFile(_createContentTypes(doc));
    archive.addFile(_createRootRels(doc));
    archive.addFile(_createDocument(doc));
    archive.addFile(_createDocumentRels(doc));
    archive.addFile(_createSettings(doc));
    archive.addFile(_createStyles(doc));
    archive.addFile(_createFontTable(doc));
    archive.addFile(_createNumbering(doc));

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

  ArchiveFile _createContentTypes(DocxBuiltDocument doc) {
    if (doc.contentTypesXml != null) {
      return ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(doc.contentTypesXml!).length,
        utf8.encode(doc.contentTypesXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Types',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/content-types',
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'rels');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-package.relationships+xml',
            );
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'xml');
            builder.attribute('ContentType', 'application/xml');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'png');
            builder.attribute('ContentType', 'image/png');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'jpeg');
            builder.attribute('ContentType', 'image/jpeg');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'jpg');
            builder.attribute('ContentType', 'image/jpeg');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'gif');
            builder.attribute('ContentType', 'image/gif');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'bmp');
            builder.attribute('ContentType', 'image/bmp');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'tiff');
            builder.attribute('ContentType', 'image/tiff');
          },
        );
        builder.element(
          'Default',
          nest: () {
            builder.attribute('Extension', 'tif');
            builder.attribute('ContentType', 'image/tiff');
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/document.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/styles.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/settings.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/fontTable.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml',
            );
          },
        );
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/numbering.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml',
            );
          },
        );
        // Background header content type (if using background image)
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/header_bg.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml',
            );
          },
        );
        // Regular header content type
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/header1.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml',
            );
          },
        );
        // Footer content type
        builder.element(
          'Override',
          nest: () {
            builder.attribute('PartName', '/word/footer1.xml');
            builder.attribute(
              'ContentType',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml',
            );
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
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
        // Add VML namespaces for background images
        builder.attribute(
          'xmlns:v',
          'urn:schemas-microsoft-com:vml',
        );
        builder.attribute(
          'xmlns:o',
          'urn:schemas-microsoft-com:office:office',
        );
        builder.attribute(
          'xmlns:w14',
          'http://schemas.microsoft.com/office/word/2010/wordml',
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
    final xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="Calibri"><w:panose1 w:val="020F0502020204030204"/></w:font>
  <w:font w:name="Calibri Light"><w:panose1 w:val="020F0302020204030204"/></w:font>
  <w:font w:name="Times New Roman"><w:panose1 w:val="02020603050405020304"/></w:font>
  <w:font w:name="Courier New"><w:panose1 w:val="02070309020205020404"/></w:font>
  <w:font w:name="Symbol"><w:panose1 w:val="05050102010706020507"/></w:font>
</w:fonts>''';
    return ArchiveFile(
      'word/fontTable.xml',
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
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );

    // Abstract numbering for bullets (abstractNumId=0) - multi-level
    buffer.writeln('''
  <w:abstractNum w:abstractNumId="0">
    <w:nsid w:val="FFFFFF89"/>
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:tmpl w:val="29761A62"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="•"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="720"/></w:tabs>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="1">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="○"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="1440"/></w:tabs>
        <w:ind w:left="1440" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="2">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="▪"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="2160"/></w:tabs>
        <w:ind w:left="2160" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
  </w:abstractNum>''');

    // Abstract numbering for decimals (abstractNumId=1) - multi-level
    buffer.writeln('''
  <w:abstractNum w:abstractNumId="1">
    <w:nsid w:val="FFFFFF88"/>
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:tmpl w:val="D0A62B40"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="720"/></w:tabs>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="1">
      <w:start w:val="1"/>
      <w:numFmt w:val="lowerLetter"/>
      <w:lvlText w:val="%2."/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="1440"/></w:tabs>
        <w:ind w:left="1440" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="2">
      <w:start w:val="1"/>
      <w:numFmt w:val="lowerRoman"/>
      <w:lvlText w:val="%3."/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="2160"/></w:tabs>
        <w:ind w:left="2160" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
  </w:abstractNum>''');

    // Generate num instances linking to correct abstractNumId
    for (int i = 0; i < _listTypes.length; i++) {
      final numId = i + 1;
      final abstractNumId = _listTypes[i] ? 1 : 0; // ordered = 1, bullet = 0
      buffer.writeln(
        '  <w:num w:numId="$numId"><w:abstractNumId w:val="$abstractNumId"/></w:num>',
      );
    }

    buffer.writeln('</w:numbering>');
    final xml = buffer.toString();
    return ArchiveFile(
      'word/numbering.xml',
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
    } else if (node is DocxTable) {
      for (var row in node.rows) {
        for (var cell in row.cells) {
          for (var child in cell.children) {
            _collectListsFromNode(child, lists);
          }
        }
      }
    }
  }
}
