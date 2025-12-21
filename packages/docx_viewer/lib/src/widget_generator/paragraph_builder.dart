import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../docx_view_config.dart';
import '../search/docx_search_controller.dart';
import '../theme/docx_view_theme.dart';

/// Builds Flutter widgets from [DocxParagraph] elements.
class ParagraphBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final DocxSearchController? searchController;
  // Used for search highlighting - currently reserved for future use
  // ignore: unused_field
  int _blockIndex = 0;

  ParagraphBuilder({
    required this.theme,
    required this.config,
    this.searchController,
  });

  /// Set the current block index for search highlighting.
  void setBlockIndex(int index) {
    _blockIndex = index;
  }

  /// Build a widget from a [DocxParagraph].
  Widget build(DocxParagraph paragraph, {int? blockIndex}) {
    if (blockIndex != null) _blockIndex = blockIndex;

    // Calculate line height from lineSpacing (240 = single line, 360 = 1.5, 480 = double)
    double? lineHeight;
    if (paragraph.lineSpacing != null) {
      lineHeight = paragraph.lineSpacing! / 240.0;
    }

    final spans = _buildTextSpans(paragraph.children, lineHeight: lineHeight);
    final textAlign = _convertAlign(paragraph.align);

    Widget content;
    if (config.enableSelection) {
      content = SelectableText.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
      );
    } else {
      content = RichText(
        text: TextSpan(children: spans),
        textAlign: textAlign,
      );
    }

    // Apply paragraph styling from DocxParagraph properties
    // Convert twips to pixels (20 twips = 1 point, 1 point ≈ 1.33 pixels)
    const double twipsToPixels = 1 / 15.0;

    double leftPadding = (paragraph.indentLeft ?? 0) * twipsToPixels;
    double rightPadding = (paragraph.indentRight ?? 0) * twipsToPixels;
    double topPadding = (paragraph.spacingBefore ?? 80) * twipsToPixels;
    double bottomPadding = (paragraph.spacingAfter ?? 80) * twipsToPixels;

    // Handle first line indent
    if (paragraph.indentFirstLine != null && paragraph.indentFirstLine! > 0) {
      // Apply first line indent by wrapping content
      content = Padding(
        padding:
            EdgeInsets.only(left: paragraph.indentFirstLine! * twipsToPixels),
        child: content,
      );
    }

    // Heading detection - use larger spacing
    if (paragraph.children.isNotEmpty) {
      final first = paragraph.children.first;
      if (first is DocxText &&
          first.fontSize != null &&
          first.fontSize! >= 20) {
        topPadding = topPadding.clamp(16, double.infinity);
        bottomPadding = bottomPadding.clamp(8, double.infinity);
      }
    }

    // Build decoration with shading and borders
    BoxDecoration? decoration = _buildParagraphDecoration(paragraph);

    // Handle page break before
    if (paragraph.pageBreakBefore) {
      // Add a visual separator for page breaks
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32, thickness: 2),
          Container(
            padding: EdgeInsets.only(
              left: leftPadding,
              right: rightPadding,
              top: topPadding,
              bottom: bottomPadding,
            ),
            decoration: decoration,
            child: content,
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: rightPadding,
        top: topPadding,
        bottom: bottomPadding,
      ),
      decoration: decoration,
      child: content,
    );
  }

  /// Build box decoration for paragraph with shading and borders.
  BoxDecoration? _buildParagraphDecoration(DocxParagraph paragraph) {
    Color? backgroundColor;
    if (paragraph.shadingFill != null) {
      backgroundColor = _parseHexColor(paragraph.shadingFill!);
    }

    // Build borders from DocxBorderSide properties
    BorderSide? topBorder;
    BorderSide? bottomBorder;
    BorderSide? leftBorder;
    BorderSide? rightBorder;

    if (paragraph.borderTop != null) {
      topBorder = _buildBorderSide(paragraph.borderTop!);
    }
    if (paragraph.borderBottomSide != null) {
      bottomBorder = _buildBorderSide(paragraph.borderBottomSide!);
    } else if (paragraph.borderBottom != null &&
        paragraph.borderBottom != DocxBorder.none) {
      // Legacy support for deprecated borderBottom
      bottomBorder = BorderSide(color: Colors.grey.shade400, width: 1);
    }
    if (paragraph.borderLeft != null) {
      leftBorder = _buildBorderSide(paragraph.borderLeft!);
    }
    if (paragraph.borderRight != null) {
      rightBorder = _buildBorderSide(paragraph.borderRight!);
    }

    final hasBorder = topBorder != null ||
        bottomBorder != null ||
        leftBorder != null ||
        rightBorder != null;

    if (backgroundColor == null && !hasBorder) {
      return null;
    }

    return BoxDecoration(
      color: backgroundColor,
      border: hasBorder
          ? Border(
              top: topBorder ?? BorderSide.none,
              bottom: bottomBorder ?? BorderSide.none,
              left: leftBorder ?? BorderSide.none,
              right: rightBorder ?? BorderSide.none,
            )
          : null,
    );
  }

  /// Convert DocxBorderSide to Flutter BorderSide.
  BorderSide _buildBorderSide(DocxBorderSide side) {
    if (side.style == DocxBorder.none) {
      return BorderSide.none;
    }

    // Convert size from eighths of a point to pixels
    final width = side.size / 8.0;
    final color = _parseHexColor(side.color.hex);

    return BorderSide(
      color: color,
      width: width.clamp(0.5, 10.0),
      style: side.style == DocxBorder.dotted
          ? BorderStyle.none // Flutter doesn't support dotted natively
          : BorderStyle.solid,
    );
  }

  /// Build TextSpans from inline elements.
  List<InlineSpan> _buildTextSpans(List<DocxInline> inlines,
      {double? lineHeight}) {
    final spans = <InlineSpan>[];

    for (final inline in inlines) {
      if (inline is DocxText) {
        spans.add(_buildTextSpan(inline, lineHeight: lineHeight));
      } else if (inline is DocxLineBreak) {
        spans.add(const TextSpan(text: '\n'));
      } else if (inline is DocxTab) {
        // Better tab rendering - use 4 spaces worth of fixed width
        spans.add(const TextSpan(text: '    '));
      } else if (inline is DocxCheckbox) {
        // Render checkbox as unicode character with styling
        spans.add(_buildCheckboxSpan(inline, lineHeight: lineHeight));
      } else if (inline is DocxInlineImage) {
        // Inline images with proper vertical alignment (like microsoft_viewer)
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Image.memory(
            inline.bytes,
            width: inline.width,
            height: inline.height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: inline.width,
              height: inline.height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, size: 24),
            ),
          ),
        ));
      } else if (inline is DocxShape) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildInlineShape(inline),
        ));
      }
    }

    return spans;
  }

  /// Build a TextSpan for a DocxCheckbox.
  TextSpan _buildCheckboxSpan(DocxCheckbox checkbox, {double? lineHeight}) {
    final content = checkbox.isChecked ? '☒ ' : '☐ ';

    FontWeight fontWeight = checkbox.fontWeight == DocxFontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal;

    FontStyle fontStyle = checkbox.fontStyle == DocxFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

    Color? textColor;
    if (checkbox.color != null) {
      textColor = _parseHexColor(checkbox.color!.hex);
    }

    return TextSpan(
      text: content,
      style: TextStyle(
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: textColor ?? theme.defaultTextStyle.color,
        fontSize: checkbox.fontSize ?? theme.defaultTextStyle.fontSize,
        height: lineHeight ?? theme.defaultTextStyle.height,
      ),
    );
  }

  /// Build a TextSpan from a [DocxText] element.
  TextSpan _buildTextSpan(DocxText text, {double? lineHeight}) {
    // Transform content based on text effects
    String content = text.content;
    if (text.isAllCaps) {
      content = content.toUpperCase();
    } else if (text.isSmallCaps) {
      // Simulate small caps by using uppercase at smaller font size
      // The actual styling will be handled later, just transform text here
      content = content.toUpperCase();
    }

    // Determine text style
    FontWeight fontWeight = text.fontWeight == DocxFontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal;

    FontStyle fontStyle = text.fontStyle == DocxFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

    // Handle multiple text decorations
    TextDecoration decoration = TextDecoration.none;
    final decorations = <TextDecoration>[];

    if (text.decoration == DocxTextDecoration.underline) {
      decorations.add(TextDecoration.underline);
    }
    if (text.decoration == DocxTextDecoration.strikethrough ||
        text.isDoubleStrike) {
      decorations.add(TextDecoration.lineThrough);
    }

    if (decorations.isNotEmpty) {
      decoration = TextDecoration.combine(decorations);
    }

    Color? textColor;
    if (text.color != null) {
      textColor = _parseHexColor(text.color!.hex);
    }

    Color? backgroundColor;
    if (text.shadingFill != null) {
      backgroundColor = _parseHexColor(text.shadingFill!);
    } else if (text.highlight != DocxHighlight.none) {
      backgroundColor = _highlightToColor(text.highlight);
    }

    double? fontSize = text.fontSize ?? theme.defaultTextStyle.fontSize;
    String? fontFamily = text.fontFamily;

    // Apply font fallbacks if no specific font
    if (fontFamily == null && config.customFontFallbacks.isNotEmpty) {
      fontFamily = config.customFontFallbacks.first;
    }

    // Handle superscript/subscript sizing
    if (text.isSuperscript || text.isSubscript) {
      fontSize = (fontSize ?? 14) * 0.7;
    }

    // Handle small caps sizing
    if (text.isSmallCaps && !text.isAllCaps) {
      fontSize = (fontSize ?? 14) * 0.85;
    }

    // Build text shadows for shadow, emboss, and imprint effects
    List<Shadow>? shadows;
    if (text.isShadow) {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ];
    } else if (text.isEmboss) {
      shadows = [
        Shadow(
          color: Colors.white.withValues(alpha: 0.7),
          offset: const Offset(-1, -1),
          blurRadius: 1,
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(1, 1),
          blurRadius: 1,
        ),
      ];
    } else if (text.isImprint) {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(-1, -1),
          blurRadius: 1,
        ),
        Shadow(
          color: Colors.white.withValues(alpha: 0.5),
          offset: const Offset(1, 1),
          blurRadius: 1,
        ),
      ];
    }

    // Handle outline effect by using text foreground
    Paint? foreground;
    if (text.isOutline) {
      foreground = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = textColor ?? Colors.black;
      textColor = null; // Can't use both color and foreground
    }

    final style = TextStyle(
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationStyle: text.isDoubleStrike
          ? TextDecorationStyle.double
          : TextDecorationStyle.solid,
      color: foreground == null
          ? (textColor ?? theme.defaultTextStyle.color)
          : null,
      foreground: foreground,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontFamilyFallback: config.customFontFallbacks,
      height: lineHeight ?? theme.defaultTextStyle.height,
      letterSpacing: text.characterSpacing,
      shadows: shadows,
    );

    // Handle hyperlinks
    if (text.href != null && text.href!.isNotEmpty) {
      return TextSpan(
        text: content,
        style: style.copyWith(
          color: theme.linkStyle.color,
          decoration: TextDecoration.underline,
          foreground: null,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _launchUrl(text.href!);
          },
      );
    }

    return TextSpan(
      text: content,
      style: style,
    );
  }

  Widget _buildInlineShape(DocxShape shape) {
    return Container(
      width: shape.width,
      height: shape.height,
      decoration: BoxDecoration(
        color: shape.fillColor != null
            ? _parseHexColor(shape.fillColor!.hex)
            : Colors.grey.shade200,
        border: shape.outlineColor != null
            ? Border.all(
                color: _parseHexColor(shape.outlineColor!.hex),
                width: shape.outlineWidth,
              )
            : null,
        borderRadius: shape.preset == DocxShapePreset.ellipse ||
                shape.preset == DocxShapePreset.roundRect
            ? BorderRadius.circular(shape.height / 2)
            : null,
      ),
      child: shape.text != null
          ? Center(
              child: Text(
                shape.text!,
                style: TextStyle(
                  fontSize: 12,
                  color: _contrastColor(shape.fillColor),
                ),
              ),
            )
          : null,
    );
  }

  TextAlign _convertAlign(DocxAlign? align) {
    switch (align) {
      case DocxAlign.left:
        return TextAlign.left;
      case DocxAlign.center:
        return TextAlign.center;
      case DocxAlign.right:
        return TextAlign.right;
      case DocxAlign.justify:
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return Colors.black;
  }

  Color _highlightToColor(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.yellow:
        return Colors.yellow.shade200;
      case DocxHighlight.green:
        return Colors.green.shade200;
      case DocxHighlight.cyan:
        return Colors.cyan.shade200;
      case DocxHighlight.magenta:
        return Colors.pink.shade200;
      case DocxHighlight.blue:
        return Colors.blue.shade200;
      case DocxHighlight.red:
        return Colors.red.shade200;
      case DocxHighlight.darkBlue:
        return Colors.blue.shade700;
      case DocxHighlight.darkCyan:
        return Colors.cyan.shade700;
      case DocxHighlight.darkGreen:
        return Colors.green.shade700;
      case DocxHighlight.darkMagenta:
        return Colors.pink.shade700;
      case DocxHighlight.darkRed:
        return Colors.red.shade700;
      case DocxHighlight.darkYellow:
        return Colors.yellow.shade700;
      case DocxHighlight.darkGray:
        return Colors.grey.shade700;
      case DocxHighlight.lightGray:
        return Colors.grey.shade300;
      case DocxHighlight.black:
        return Colors.black;
      default:
        return Colors.transparent;
    }
  }

  Color _contrastColor(DocxColor? color) {
    if (color == null) return Colors.black;
    final c = _parseHexColor(color.hex);
    final luminance = c.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
