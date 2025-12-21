import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

/// Drawing position mode - how the drawing is placed relative to text.
enum DocxDrawingPosition {
  /// Inline with text (wp:inline)
  inline,

  /// Floating/anchored to a position on the page (wp:anchor)
  floating,
}

/// Horizontal position origin for floating drawings
enum DocxHorizontalPositionFrom {
  margin,
  page,
  column,
  character,
  leftMargin,
  rightMargin,
  insideMargin,
  outsideMargin,
}

/// Vertical position origin for floating drawings
enum DocxVerticalPositionFrom {
  margin,
  page,
  paragraph,
  line,
  topMargin,
  bottomMargin,
  insideMargin,
  outsideMargin,
}

/// Horizontal alignment for floating drawings
enum DrawingHAlign {
  left,
  center,
  right,
  inside,
  outside,
}

/// Vertical alignment for floating drawings
enum DrawingVAlign {
  top,
  center,
  bottom,
  inside,
  outside,
}

/// Text wrapping mode for floating drawings
enum DocxTextWrap {
  /// No wrapping (wrapNone)
  none,

  /// Square wrapping (wrapSquare)
  square,

  /// Tight wrapping (wrapTight)
  tight,

  /// Through wrapping (wrapThrough)
  through,

  /// Top and bottom only (wrapTopAndBottom)
  topAndBottom,

  /// Behind text
  behindText,

  /// In front of text
  inFrontOfText,
}

/// Preset shape geometry types
enum DocxShapePreset {
  rect,
  roundRect,
  ellipse,
  triangle,
  rtTriangle,
  parallelogram,
  trapezoid,
  diamond,
  pentagon,
  hexagon,
  heptagon,
  octagon,
  star4,
  star5,
  star6,
  heart,
  cloud,
  lightning,
  arrow,
  leftArrow,
  rightArrow,
  upArrow,
  downArrow,
  leftRightArrow,
  upDownArrow,
  line,
  straightConnector1,
  bentConnector2,
  bentConnector3,
  curvedConnector2,
  curvedConnector3,
  callout1,
  callout2,
  callout3,
  borderCallout1,
  borderCallout2,
  borderCallout3,
  ribbon,
  ribbon2,
  chevron,
  plus,
  minus,
  cross,
  cube,
  can,
  donut,
  noSmoking,
  blockArc,
  wedgeRectCallout,
  wedgeRoundRectCallout,
  wedgeEllipseCallout,
  flowChartProcess,
  flowChartAlternateProcess,
  flowChartDecision,
  flowChartInputOutput,
  flowChartPredefinedProcess,
  flowChartDocument,
  flowChartMultidocument,
  flowChartTerminator,
  flowChartConnector,
  flowChartExtract,
  flowChartMerge,
  bevel,
  foldedCorner,
  smileyFace,
  sun,
  moon,
  bracePair,
  bracketPair,
  actionButtonHome,
  actionButtonHelp,
  actionButtonInformation,
}

/// Represents a DrawingML shape in the document.
///
/// Based on python-docx drawing module structure.
/// Supports both inline and floating (anchored) positioning.
class DocxShape extends DocxInline {
  /// Shape width in points.
  final double width;

  /// Shape height in points.
  final double height;

  /// Preset shape geometry.
  final DocxShapePreset preset;

  /// Position mode (inline or floating).
  final DocxDrawingPosition position;

  /// Fill color (null for no fill).
  final DocxColor? fillColor;

  /// Outline/stroke color (null for no outline).
  final DocxColor? outlineColor;

  /// Outline width in points.
  final double outlineWidth;

  /// Text content inside the shape (optional).
  final String? text;

  /// Horizontal position from origin (for floating shapes).
  final DocxHorizontalPositionFrom horizontalFrom;

  /// Vertical position from origin (for floating shapes).
  final DocxVerticalPositionFrom verticalFrom;

  /// Horizontal alignment (for floating shapes).
  final DrawingHAlign? horizontalAlign;

  /// Vertical alignment (for floating shapes).
  final DrawingVAlign? verticalAlign;

  /// Horizontal offset in points (for floating shapes with absolute positioning).
  final double? horizontalOffset;

  /// Vertical offset in points (for floating shapes with absolute positioning).
  final double? verticalOffset;

  /// Text wrapping mode (for floating shapes).
  final DocxTextWrap textWrap;

  /// Whether the shape should be behind the text.
  final bool behindDocument;

  /// Rotation angle in degrees.
  final double rotation;

  // Internal: Set by the exporter when processing
  int? _shapeId;

  DocxShape({
    this.width = 100,
    this.height = 100,
    this.preset = DocxShapePreset.rect,
    this.position = DocxDrawingPosition.inline,
    this.fillColor,
    this.outlineColor,
    this.outlineWidth = 1,
    this.text,
    this.horizontalFrom = DocxHorizontalPositionFrom.column,
    this.verticalFrom = DocxVerticalPositionFrom.paragraph,
    this.horizontalAlign,
    this.verticalAlign,
    this.horizontalOffset,
    this.verticalOffset,
    this.textWrap = DocxTextWrap.square,
    this.behindDocument = false,
    this.rotation = 0,
    super.id,
  });

  /// Creates a rectangle shape.
  factory DocxShape.rectangle({
    double width = 100,
    double height = 60,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.rect,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Creates an ellipse/circle shape.
  factory DocxShape.ellipse({
    double width = 100,
    double height = 100,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.ellipse,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Creates a circle (ellipse with equal width/height).
  factory DocxShape.circle({
    double diameter = 100,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: diameter,
        height: diameter,
        preset: DocxShapePreset.ellipse,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Creates a rounded rectangle shape.
  factory DocxShape.roundedRectangle({
    double width = 100,
    double height = 60,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.roundRect,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Creates a line connector shape.
  factory DocxShape.line({
    double width = 100,
    double height = 1,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.line,
        fillColor: null,
        outlineColor: outlineColor ?? DocxColor.black,
        outlineWidth: outlineWidth,
        position: position,
      );

  /// Creates a right arrow shape.
  factory DocxShape.rightArrow({
    double width = 100,
    double height = 40,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.rightArrow,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        position: position,
      );

  /// Creates a left arrow shape.
  factory DocxShape.leftArrow({
    double width = 100,
    double height = 40,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.leftArrow,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        position: position,
      );

  /// Creates a triangle shape.
  factory DocxShape.triangle({
    double width = 100,
    double height = 100,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.triangle,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Creates a star shape.
  factory DocxShape.star({
    double width = 100,
    double height = 100,
    int points = 5,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) {
    final preset = switch (points) {
      4 => DocxShapePreset.star4,
      6 => DocxShapePreset.star6,
      _ => DocxShapePreset.star5,
    };
    return DocxShape(
      width: width,
      height: height,
      preset: preset,
      fillColor: fillColor,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      position: position,
    );
  }

  /// Creates a diamond shape.
  factory DocxShape.diamond({
    double width = 100,
    double height = 100,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxDrawingPosition position = DocxDrawingPosition.inline,
  }) =>
      DocxShape(
        width: width,
        height: height,
        preset: DocxShapePreset.diamond,
        fillColor: fillColor,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        text: text,
        position: position,
      );

  /// Sets the shape ID (called by exporter).
  void setShapeId(int id) {
    _shapeId = id;
  }

  int? get shapeId => _shapeId;

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitShape(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    final int cx = (width * 12700).toInt(); // EMUs
    final int cy = (height * 12700).toInt();
    final int shapeId = _shapeId ?? 1;

    builder.element('w:r', nest: () {
      builder.element('w:drawing', nest: () {
        if (position == DocxDrawingPosition.inline) {
          _buildInlineDrawing(builder, cx, cy, shapeId);
        } else {
          _buildAnchorDrawing(builder, cx, cy, shapeId);
        }
      });
    });
  }

  void _buildInlineDrawing(XmlBuilder builder, int cx, int cy, int shapeId) {
    builder.element('wp:inline', nest: () {
      _buildDrawingExtent(builder, cx, cy);
      _buildDocPr(builder, shapeId);
      _buildCNvGraphicFramePr(builder);
      _buildGraphic(builder, cx, cy, shapeId);
    });
  }

  void _buildAnchorDrawing(XmlBuilder builder, int cx, int cy, int shapeId) {
    builder.element('wp:anchor', nest: () {
      // Anchor attributes
      builder.attribute('distT', '0');
      builder.attribute('distB', '0');
      builder.attribute('distL', '114300');
      builder.attribute('distR', '114300');
      builder.attribute('simplePos', '0');
      builder.attribute('relativeHeight', '251659264');
      builder.attribute('behindDoc', behindDocument ? '1' : '0');
      builder.attribute('locked', '0');
      builder.attribute('layoutInCell', '1');
      builder.attribute('allowOverlap', '1');

      // Simple position
      builder.element('wp:simplePos', nest: () {
        builder.attribute('x', '0');
        builder.attribute('y', '0');
      });

      // Horizontal position
      builder.element('wp:positionH', nest: () {
        builder.attribute('relativeFrom', horizontalFrom.name);
        if (horizontalAlign != null) {
          builder.element('wp:align', nest: () {
            builder.text(horizontalAlign!.name);
          });
        } else {
          builder.element('wp:posOffset', nest: () {
            final offset = ((horizontalOffset ?? 0) * 12700).toInt();
            builder.text(offset.toString());
          });
        }
      });

      // Vertical position
      builder.element('wp:positionV', nest: () {
        builder.attribute('relativeFrom', verticalFrom.name);
        if (verticalAlign != null) {
          builder.element('wp:align', nest: () {
            builder.text(verticalAlign!.name);
          });
        } else {
          builder.element('wp:posOffset', nest: () {
            final offset = ((verticalOffset ?? 0) * 12700).toInt();
            builder.text(offset.toString());
          });
        }
      });

      // Extent
      _buildDrawingExtent(builder, cx, cy);

      // Effect extent
      builder.element('wp:effectExtent', nest: () {
        builder.attribute('l', '0');
        builder.attribute('t', '0');
        builder.attribute('r', '0');
        builder.attribute('b', '0');
      });

      // Text wrap
      _buildTextWrap(builder);

      // Doc properties
      _buildDocPr(builder, shapeId);
      _buildCNvGraphicFramePr(builder);
      _buildGraphic(builder, cx, cy, shapeId);
    });
  }

  void _buildDrawingExtent(XmlBuilder builder, int cx, int cy) {
    builder.element('wp:extent', nest: () {
      builder.attribute('cx', cx.toString());
      builder.attribute('cy', cy.toString());
    });
  }

  void _buildDocPr(XmlBuilder builder, int shapeId) {
    builder.element('wp:docPr', nest: () {
      builder.attribute('id', shapeId.toString());
      builder.attribute('name', 'Shape $shapeId');
    });
  }

  void _buildCNvGraphicFramePr(XmlBuilder builder) {
    builder.element('wp:cNvGraphicFramePr', nest: () {
      builder.element('a:graphicFrameLocks', nest: () {
        builder.attribute(
            'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
      });
    });
  }

  void _buildTextWrap(XmlBuilder builder) {
    switch (textWrap) {
      case DocxTextWrap.none:
      case DocxTextWrap.behindText:
      case DocxTextWrap.inFrontOfText:
        builder.element('wp:wrapNone');
        break;
      case DocxTextWrap.square:
        builder.element('wp:wrapSquare', nest: () {
          builder.attribute('wrapText', 'bothSides');
        });
        break;
      case DocxTextWrap.tight:
        builder.element('wp:wrapTight', nest: () {
          builder.attribute('wrapText', 'bothSides');
          builder.element('wp:wrapPolygon', nest: () {
            builder.attribute('edited', '0');
            builder.element('wp:start', nest: () {
              builder.attribute('x', '0');
              builder.attribute('y', '0');
            });
            builder.element('wp:lineTo', nest: () {
              builder.attribute('x', '21600');
              builder.attribute('y', '0');
            });
            builder.element('wp:lineTo', nest: () {
              builder.attribute('x', '21600');
              builder.attribute('y', '21600');
            });
            builder.element('wp:lineTo', nest: () {
              builder.attribute('x', '0');
              builder.attribute('y', '21600');
            });
            builder.element('wp:lineTo', nest: () {
              builder.attribute('x', '0');
              builder.attribute('y', '0');
            });
          });
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
    }
  }

  void _buildGraphic(XmlBuilder builder, int cx, int cy, int shapeId) {
    builder.element('a:graphic', nest: () {
      builder.attribute(
          'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
      builder.element('a:graphicData', nest: () {
        builder.attribute('uri',
            'http://schemas.microsoft.com/office/word/2010/wordprocessingShape');
        _buildWordprocessingShape(builder, cx, cy, shapeId);
      });
    });
  }

  void _buildWordprocessingShape(
      XmlBuilder builder, int cx, int cy, int shapeId) {
    builder.element('wsp:wsp', nest: () {
      builder.attribute('xmlns:wsp',
          'http://schemas.microsoft.com/office/word/2010/wordprocessingShape');

      // Non-visual properties
      builder.element('wsp:cNvSpPr', nest: () {});

      // Shape properties
      builder.element('wsp:spPr', nest: () {
        // Transform
        builder.element('a:xfrm', nest: () {
          if (rotation != 0) {
            builder.attribute('rot', (rotation * 60000).toInt().toString());
          }
          builder.element('a:off', nest: () {
            builder.attribute('x', '0');
            builder.attribute('y', '0');
          });
          builder.element('a:ext', nest: () {
            builder.attribute('cx', cx.toString());
            builder.attribute('cy', cy.toString());
          });
        });

        // Preset geometry
        builder.element('a:prstGeom', nest: () {
          builder.attribute('prst', preset.name);
          builder.element('a:avLst');
        });

        // Fill
        if (fillColor != null) {
          builder.element('a:solidFill', nest: () {
            builder.element('a:srgbClr', nest: () {
              builder.attribute('val', fillColor!.hex);
            });
          });
        } else {
          builder.element('a:noFill');
        }

        // Outline
        if (outlineColor != null) {
          final outlineEmu = (outlineWidth * 12700).toInt();
          builder.element('a:ln', nest: () {
            builder.attribute('w', outlineEmu.toString());
            builder.element('a:solidFill', nest: () {
              builder.element('a:srgbClr', nest: () {
                builder.attribute('val', outlineColor!.hex);
              });
            });
          });
        } else {
          builder.element('a:ln', nest: () {
            builder.element('a:noFill');
          });
        }
      });

      // Text body (if shape contains text)
      if (text != null && text!.isNotEmpty) {
        builder.element('wsp:txbx', nest: () {
          builder.element('w:txbxContent', nest: () {
            builder.element('w:p', nest: () {
              builder.element('w:pPr', nest: () {
                builder.element('w:jc', nest: () {
                  builder.attribute('w:val', 'center');
                });
              });
              builder.element('w:r', nest: () {
                builder.element('w:t', nest: () {
                  builder.text(text!);
                });
              });
            });
          });
        });
      }

      // Body properties
      builder.element('wsp:bodyPr', nest: () {
        builder.attribute('rot', '0');
        builder.attribute('vert', 'horz');
        builder.attribute('wrap', 'square');
        builder.attribute('anchor', 'ctr');
        builder.attribute('anchorCtr', '0');
      });
    });
  }
}

/// Block-level drawing shape container.
class DocxShapeBlock extends DocxBlock {
  /// The underlying shape.
  final DocxShape shape;

  /// Alignment when rendered as block.
  final DocxAlign align;

  DocxShapeBlock({
    required this.shape,
    this.align = DocxAlign.center,
    super.id,
  });

  /// Creates a rectangle block shape.
  factory DocxShapeBlock.rectangle({
    double width = 100,
    double height = 60,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxAlign align = DocxAlign.center,
  }) =>
      DocxShapeBlock(
        shape: DocxShape.rectangle(
          width: width,
          height: height,
          fillColor: fillColor,
          outlineColor: outlineColor,
          outlineWidth: outlineWidth,
          text: text,
        ),
        align: align,
      );

  /// Creates an ellipse block shape.
  factory DocxShapeBlock.ellipse({
    double width = 100,
    double height = 100,
    DocxColor? fillColor,
    DocxColor? outlineColor,
    double outlineWidth = 1,
    String? text,
    DocxAlign align = DocxAlign.center,
  }) =>
      DocxShapeBlock(
        shape: DocxShape.ellipse(
          width: width,
          height: height,
          fillColor: fillColor,
          outlineColor: outlineColor,
          outlineWidth: outlineWidth,
          text: text,
        ),
        align: align,
      );

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitShapeBlock(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:jc', nest: () {
          builder.attribute('w:val', align.name);
        });
      });
      shape.buildXml(builder);
    });
  }
}
