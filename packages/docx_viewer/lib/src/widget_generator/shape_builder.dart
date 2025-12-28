import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';

/// Builds Flutter widgets from [DocxShape] and [DocxShapeBlock] elements.
class ShapeBuilder {
  final DocxViewConfig config;
  final DocxTheme? docxTheme;

  ShapeBuilder({required this.config, this.docxTheme});

  /// Build a block-level shape widget.
  Widget buildBlockShape(DocxShapeBlock shapeBlock) {
    final shape = shapeBlock.shape;

    Widget shapeWidget = _buildShape(shape);

    // Apply alignment
    Alignment alignment;
    switch (shapeBlock.align) {
      case DocxAlign.center:
        alignment = Alignment.center;
        break;
      case DocxAlign.right:
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.centerLeft;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: alignment,
      child: shapeWidget,
    );
  }

  /// Build an inline shape widget.
  Widget buildInlineShape(DocxShape shape) {
    return _buildShape(shape);
  }

  Widget _buildShape(DocxShape shape) {
    // Determine shape decoration based on preset
    BoxDecoration decoration;
    BorderRadius? borderRadius;

    switch (shape.preset) {
      case DocxShapePreset.ellipse:
        borderRadius = BorderRadius.circular(shape.height / 2);
        break;
      case DocxShapePreset.roundRect:
        borderRadius = BorderRadius.circular(8);
        break;
      case DocxShapePreset.triangle:
      case DocxShapePreset.rtTriangle:
      case DocxShapePreset.star4:
      case DocxShapePreset.star5:
      case DocxShapePreset.star6:
      case DocxShapePreset.diamond:
        // For complex shapes, use CustomPaint
        return _buildComplexShape(shape);
      default:
        borderRadius = null;
    }

    final fillColor = _resolveColor(
      shape.fillColor?.hex,
      shape.fillColor?.themeColor,
      shape.fillColor?.themeTint,
      shape.fillColor?.themeShade,
    );

    final outlineColor = _resolveColor(
      shape.outlineColor?.hex,
      shape.outlineColor?.themeColor,
      shape.outlineColor?.themeTint,
      shape.outlineColor?.themeShade,
    );

    decoration = BoxDecoration(
      color: fillColor ??
          (shape.fillColor != null
              ? _parseHexColor(shape.fillColor!.hex)
              : Colors.grey.shade200),
      border: shape.outlineColor != null
          ? Border.all(
              color: outlineColor ?? _parseHexColor(shape.outlineColor!.hex),
              width: shape.outlineWidth,
            )
          : null,
      borderRadius: borderRadius,
    );

    // Apply rotation if specified
    Widget container = Container(
      width: shape.width,
      height: shape.height,
      decoration: decoration,
      child: shape.text != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  shape.text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _contrastColor(shape.fillColor),
                  ),
                ),
              ),
            )
          : null,
    );

    if (shape.rotation != 0) {
      container = Transform.rotate(
        angle: (shape.rotation * 3.14159) / 180, // Convert to radians
        child: container,
      );
    }

    return container;
  }

  Widget _buildComplexShape(DocxShape shape) {
    return SizedBox(
      width: shape.width,
      height: shape.height,
      child: CustomPaint(
        painter: _ShapePainter(shape, docxTheme),
        child: shape.text != null
            ? Center(
                child: Text(
                  shape.text!,
                  style: TextStyle(
                    fontSize: 10,
                    color: _contrastColor(shape.fillColor),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return Colors.grey;
  }

  Color _contrastColor(DocxColor? color) {
    if (color == null) return Colors.black;
    // Resolve theme color for contrast check too
    final resolved = _resolveColor(
            color.hex, color.themeColor, color.themeTint, color.themeShade) ??
        _parseHexColor(color.hex);

    final luminance = resolved.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Color? _resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    // 1. Try Theme Color
    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) {
        baseColor = _parseHexColor(themeHex);
      }
    }

    // 2. Fallback to direct Hex
    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = _parseHexColor(hex);
    }

    if (baseColor == null) return null;

    // 3. Apply Tint/Shade
    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        final factor = tintVal / 255.0;
        baseColor =
            Color.alphaBlend(Colors.white.withOpacity(1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        final factor = shadeVal / 255.0;
        baseColor =
            Color.alphaBlend(Colors.black.withOpacity(1 - factor), baseColor);
      }
    }

    return baseColor;
  }
}

/// Custom painter for complex shapes.
class _ShapePainter extends CustomPainter {
  final DocxShape shape;
  final DocxTheme? docxTheme;

  _ShapePainter(this.shape, this.docxTheme);

  @override
  void paint(Canvas canvas, Size size) {
    // Resolve colors manually since _ShapePainter is separate
    final fillColorRaw = shape.fillColor; // default handled later

    // We duplicate _resolveColor logic here or make it static utility?
    // Duplication for now to keep it self-contained in this builder.
    final fillColorVal = _resolveColor(
            fillColorRaw?.hex,
            fillColorRaw?.themeColor,
            fillColorRaw?.themeTint,
            fillColorRaw?.themeShade) ??
        (fillColorRaw != null
            ? _parseHexColor(fillColorRaw.hex)
            : Colors.grey.shade200);

    final outlineColorRaw = shape.outlineColor;
    final outlineColorVal = _resolveColor(
            outlineColorRaw?.hex,
            outlineColorRaw?.themeColor,
            outlineColorRaw?.themeTint,
            outlineColorRaw?.themeShade) ??
        (outlineColorRaw != null
            ? _parseHexColor(outlineColorRaw.hex)
            : Colors.black);

    final fillPaint = Paint()
      ..color = fillColorVal
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = outlineColorVal
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.outlineWidth;

    final path = Path();

    switch (shape.preset) {
      case DocxShapePreset.triangle:
        path.moveTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        path.close();
        break;

      case DocxShapePreset.rtTriangle:
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        path.close();
        break;

      case DocxShapePreset.diamond:
        path.moveTo(size.width / 2, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(0, size.height / 2);
        path.close();
        break;

      case DocxShapePreset.star5:
        _drawStar(path, size, 5);
        break;

      case DocxShapePreset.star4:
        _drawStar(path, size, 4);
        break;

      case DocxShapePreset.star6:
        _drawStar(path, size, 6);
        break;

      default:
        // Fallback to rectangle
        path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    canvas.drawPath(path, fillPaint);
    if (shape.outlineColor != null) {
      canvas.drawPath(path, strokePaint);
    }
  }

  void _drawStar(Path path, Size size, int points) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * 3.14159 / points) - (3.14159 / 2);
      final x = centerX +
          radius * (1 + 0).toDouble() * (i == 0 ? 1 : 1) * _cos(angle);
      final y = centerY + radius * _sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  double _cos(double angle) => angle == 0
      ? 1
      : (angle * 180 / 3.14159).abs() < 0.001
          ? 1
          : 1 - (angle * angle / 2) + (angle * angle * angle * angle / 24);
  double _sin(double angle) =>
      angle -
      (angle * angle * angle / 6) +
      (angle * angle * angle * angle * angle / 120);

  Color? _resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) {
        baseColor = _parseHexColor(themeHex);
      }
    }

    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = _parseHexColor(hex);
    }

    if (baseColor == null) return null;

    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        final factor = tintVal / 255.0;
        baseColor =
            Color.alphaBlend(Colors.white.withOpacity(1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        final factor = shadeVal / 255.0;
        baseColor =
            Color.alphaBlend(Colors.black.withOpacity(1 - factor), baseColor);
      }
    }

    return baseColor;
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return Colors.grey;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
