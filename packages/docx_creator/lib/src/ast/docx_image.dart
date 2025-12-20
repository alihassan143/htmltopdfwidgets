import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

/// An image element in the document.
///
/// [DocxImage] represents an embedded image with size and positioning options.
///
/// ## Basic Usage
/// ```dart
/// DocxImage(
///   bytes: imageBytes,
///   extension: 'png',
///   width: 300,
///   height: 200,
/// )
/// ```
///
/// ## Alignment
/// ```dart
/// DocxImage(
///   bytes: imageBytes,
///   extension: 'jpeg',
///   align: DocxAlign.center,
///   altText: 'Company Logo',
/// )
/// ```
class DocxImage extends DocxBlock {
  /// Raw image bytes.
  final Uint8List bytes;

  /// Image file extension (e.g., 'png', 'jpeg', 'gif').
  final String extension;

  /// Image width in points.
  final double width;

  /// Image height in points.
  final double height;

  /// Alternative text for accessibility.
  final String? altText;

  /// Horizontal alignment within the paragraph.
  final DocxAlign align;

  // Internal: Set by the exporter when processing
  String? _relationshipId;
  int? _uniqueId;

  DocxImage({
    required this.bytes,
    required this.extension,
    this.width = 200,
    this.height = 150,
    this.altText,
    this.align = DocxAlign.center,
    super.id,
  });

  /// Sets the relationship ID for DOCX export.
  void setRelationshipId(String rId, int uniqueId) {
    _relationshipId = rId;
    _uniqueId = uniqueId;
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitImage(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    if (_relationshipId == null) return;

    // Convert points to EMUs (1 pt = 12700 EMU)
    final int cx = (width * 12700).toInt();
    final int cy = (height * 12700).toInt();

    builder.element(
      'w:p',
      nest: () {
        // Alignment
        builder.element(
          'w:pPr',
          nest: () {
            builder.element(
              'w:jc',
              nest: () {
                builder.attribute('w:val', align.name);
              },
            );
          },
        );

        builder.element(
          'w:r',
          nest: () {
            builder.element(
              'w:drawing',
              nest: () {
                builder.element(
                  'wp:inline',
                  nest: () {
                    builder.element(
                      'wp:extent',
                      nest: () {
                        builder.attribute('cx', cx);
                        builder.attribute('cy', cy);
                      },
                    );
                    builder.element(
                      'wp:docPr',
                      nest: () {
                        builder.attribute('id', _uniqueId!);
                        builder.attribute('name', 'Picture $_uniqueId');
                        if (altText != null) {
                          builder.attribute('descr', altText!);
                        }
                      },
                    );
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
                                // Non-Visual Properties
                                builder.element(
                                  'pic:nvPicPr',
                                  nest: () {
                                    builder.element(
                                      'pic:cNvPr',
                                      nest: () {
                                        builder.attribute('id', _uniqueId!);
                                        builder.attribute(
                                          'name',
                                          'Picture $_uniqueId',
                                        );
                                      },
                                    );
                                    builder.element('pic:cNvPicPr');
                                  },
                                );
                                // Fill
                                builder.element(
                                  'pic:blipFill',
                                  nest: () {
                                    builder.element(
                                      'a:blip',
                                      nest: () {
                                        builder.attribute(
                                          'r:embed',
                                          _relationshipId!,
                                        );
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
                                // Shape Properties
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
                                            builder.attribute('cx', cx);
                                            builder.attribute('cy', cy);
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
}
