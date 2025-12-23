import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../core/enums.dart';
import '../core/xml_extension.dart';
import 'docx_drawing.dart';
import 'docx_node.dart';

/// An inline image element (can be used inside paragraphs).
class DocxInlineImage extends DocxInline {
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

  /// Positioning mode (inline or floating).
  final DocxDrawingPosition positionMode;

  /// Text wrapping mode (only for floating images).
  final DocxTextWrap textWrap;

  /// Horizontal alignment (for floating images).
  final DrawingHAlign? hAlign;

  /// Vertical alignment (for floating images).
  final DrawingVAlign? vAlign;

  /// Horizontal offset in points (for floating images).
  final double? x;

  /// Vertical offset in points (for floating images).
  final double? y;

  /// Horizontal position origin (relative from).
  final DocxHorizontalPositionFrom hPositionFrom;

  /// Vertical position origin (relative from).
  final DocxVerticalPositionFrom vPositionFrom;

  // ==========================================================================
  // True-Fidelity Anchor Attributes (for round-trip preservation)
  // ==========================================================================

  /// Distance from text on top (in EMUs). Default: 0
  final int distT;

  /// Distance from text on bottom (in EMUs). Default: 0
  final int distB;

  /// Distance from text on left (in EMUs). Default: 114300 (0.125 inch)
  final int distL;

  /// Distance from text on right (in EMUs). Default: 114300 (0.125 inch)
  final int distR;

  /// Whether simple positioning is used (simplePos attribute).
  final bool simplePos;

  /// Relative z-order height for overlapping objects.
  final int relativeHeight;

  /// Whether the anchor position is locked.
  final bool locked;

  /// Whether the object can be positioned inside a table cell.
  final bool layoutInCell;

  /// Whether overlapping with other floating objects is allowed.
  final bool allowOverlap;

  /// Effect extent values (l, t, r, b) in EMUs for shadows/glows.
  final int effectExtentL;
  final int effectExtentT;
  final int effectExtentR;
  final int effectExtentB;

  /// Stores unknown anchor attributes for round-trip preservation.
  final XmlExtensionMap? anchorExtensions;

  // Internal: Set by the exporter when processing
  String? _relationshipId;
  int? _uniqueId;

  DocxInlineImage({
    required this.bytes,
    required this.extension,
    this.width = 200,
    this.height = 150,
    this.altText,
    this.positionMode = DocxDrawingPosition.inline,
    this.textWrap = DocxTextWrap.none,
    this.x,
    this.y,
    this.hAlign,
    this.vAlign,
    this.hPositionFrom = DocxHorizontalPositionFrom.column,
    this.vPositionFrom = DocxVerticalPositionFrom.paragraph,
    // True-Fidelity anchor attributes with sensible defaults
    this.distT = 0,
    this.distB = 0,
    this.distL = 114300,
    this.distR = 114300,
    this.simplePos = false,
    this.relativeHeight = 251658240,
    this.locked = false,
    this.layoutInCell = true,
    this.allowOverlap = true,
    this.effectExtentL = 0,
    this.effectExtentT = 0,
    this.effectExtentR = 0,
    this.effectExtentB = 0,
    this.anchorExtensions,
    super.id,
  });

  /// Sets the relationship ID for DOCX export.
  void setRelationshipId(String rId, int uniqueId) {
    _relationshipId = rId;
    _uniqueId = uniqueId;
  }

  String? get relationshipId => _relationshipId;

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
      'w:r',
      nest: () {
        builder.element(
          'w:drawing',
          nest: () {
            if (positionMode == DocxDrawingPosition.floating) {
              _buildAnchor(builder, cx, cy);
            } else {
              _buildInline(builder, cx, cy);
            }
          },
        );
      },
    );
  }

  void _buildInline(XmlBuilder builder, int cx, int cy) {
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
        _buildDocPr(builder);
        _buildGraphic(builder, cx, cy);
      },
    );
  }

  void _buildAnchor(XmlBuilder builder, int cx, int cy) {
    builder.element(
      'wp:anchor',
      nest: () {
        // True-Fidelity: Use preserved values instead of hardcoded ones
        builder.attribute('distT', distT.toString());
        builder.attribute('distB', distB.toString());
        builder.attribute('distL', distL.toString());
        builder.attribute('distR', distR.toString());
        builder.attribute('simplePos', simplePos ? '1' : '0');
        builder.attribute('relativeHeight', relativeHeight.toString());
        builder.attribute(
            'behindDoc', textWrap == DocxTextWrap.behindText ? '1' : '0');
        builder.attribute('locked', locked ? '1' : '0');
        builder.attribute('layoutInCell', layoutInCell ? '1' : '0');
        builder.attribute('allowOverlap', allowOverlap ? '1' : '0');

        // Write back any unknown extension attributes
        anchorExtensions?.writeAttributesTo(builder);

        builder.element('wp:simplePos', nest: () {
          builder.attribute('x', '0');
          builder.attribute('y', '0');
        });

        // Horizontal Position
        builder.element('wp:positionH', nest: () {
          builder.attribute('relativeFrom', hPositionFrom.name);
          if (hAlign != null) {
            builder.element('wp:align', nest: () {
              builder.text(hAlign!.name);
            });
          } else {
            builder.element('wp:posOffset', nest: () {
              final xEmu = ((x ?? 0) * 12700).toInt();
              builder.text(xEmu.toString());
            });
          }
        });

        // Vertical Position
        builder.element('wp:positionV', nest: () {
          builder.attribute('relativeFrom', vPositionFrom.name);
          if (vAlign != null) {
            builder.element('wp:align', nest: () {
              builder.text(vAlign!.name);
            });
          } else {
            builder.element('wp:posOffset', nest: () {
              final yEmu = ((y ?? 0) * 12700).toInt();
              builder.text(yEmu.toString());
            });
          }
        });

        builder.element(
          'wp:extent',
          nest: () {
            builder.attribute('cx', cx);
            builder.attribute('cy', cy);
          },
        );

        // True-Fidelity: Use preserved effect extent values
        builder.element(
          'wp:effectExtent',
          nest: () {
            builder.attribute('l', effectExtentL.toString());
            builder.attribute('t', effectExtentT.toString());
            builder.attribute('r', effectExtentR.toString());
            builder.attribute('b', effectExtentB.toString());
          },
        );

        _buildTextWrap(builder);
        _buildDocPr(builder);
        _buildGraphic(builder, cx, cy);
      },
    );
  }

  void _buildTextWrap(XmlBuilder builder) {
    switch (textWrap) {
      case DocxTextWrap.square:
        builder.element('wp:wrapSquare', nest: () {
          builder.attribute('wrapText', 'bothSides');
        });
        break;
      case DocxTextWrap.tight:
        builder.element('wp:wrapTight', nest: () {
          builder.attribute('wrapText', 'bothSides');
        });
        break;
      case DocxTextWrap.through:
        builder.element('wp:wrapThrough', nest: () {
          builder.attribute('wrapText', 'bothSides');
        });
        break;
      case DocxTextWrap.topAndBottom:
        builder.element('wp:wrapTopAndBottom');
        break;
      case DocxTextWrap.none:
      case DocxTextWrap.behindText:
      case DocxTextWrap.inFrontOfText:
        builder.element('wp:wrapNone');
        break;
    }
  }

  void _buildDocPr(XmlBuilder builder) {
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
  }

  void _buildGraphic(XmlBuilder builder, int cx, int cy) {
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
  }
}

/// An image element in the document (Block Level).
///
/// [DocxImage] represents an image with block-level alignment.
class DocxImage extends DocxBlock {
  /// The underlying inline image.
  final DocxInlineImage _inlineImage;

  /// Horizontal alignment within the paragraph.
  final DocxAlign align;

  DocxImage({
    required Uint8List bytes,
    required String extension,
    double width = 200,
    double height = 150,
    String? altText,
    this.align = DocxAlign.center,
    super.id,
  }) : _inlineImage = DocxInlineImage(
          bytes: bytes,
          extension: extension,
          width: width,
          height: height,
          altText: altText,
        );

  // Expose properties from inner image for backward compatibility
  Uint8List get bytes => _inlineImage.bytes;
  String get extension => _inlineImage.extension;
  double get width => _inlineImage.width;
  double get height => _inlineImage.height;
  String? get altText => _inlineImage.altText;

  DocxInlineImage get asInline => _inlineImage;

  /// Sets the relationship ID for DOCX export.
  void setRelationshipId(String rId, int uniqueId) {
    _inlineImage.setRelationshipId(rId, uniqueId);
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitImage(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    // Block image is just a Paragraph containing the inline image
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

        // Inline image now handles its own w:r wrapper
        _inlineImage.buildXml(builder);
      },
    );
  }
}
