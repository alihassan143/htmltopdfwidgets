import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import '../search/docx_search_controller.dart';

/// Builds Flutter widgets from [DocxParagraph] elements.
class ParagraphBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final DocxSearchController? searchController;
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

    final spans = _buildTextSpans(paragraph.children);
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

    // Apply paragraph styling
    double leftPadding = 0;
    double topPadding = 4;
    double bottomPadding = 4;

    // Heading detection - use larger spacing
    if (paragraph.children.isNotEmpty) {
      final first = paragraph.children.first;
      if (first is DocxText && first.fontSize != null && first.fontSize! >= 20) {
        topPadding = 16;
        bottomPadding = 8;
      }
    }

    // Handle shading/background
    BoxDecoration? decoration;
    if (paragraph.shadingFill != null) {
      decoration = BoxDecoration(
        color: _parseHexColor(paragraph.shadingFill!),
      );
    }

    // Handle bottom border (for hr elements)
    if (paragraph.borderBottom != null && paragraph.borderBottom != DocxBorder.none) {
      decoration = BoxDecoration(
        color: decoration?.color,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade400,
            width: 1,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: leftPadding,
        top: topPadding,
        bottom: bottomPadding,
      ),
      decoration: decoration,
      child: content,
    );
  }

  /// Build TextSpans from inline elements.
  List<InlineSpan> _buildTextSpans(List<DocxInline> inlines) {
    final spans = <InlineSpan>[];

    for (final inline in inlines) {
      if (inline is DocxText) {
        spans.add(_buildTextSpan(inline));
      } else if (inline is DocxLineBreak) {
        spans.add(const TextSpan(text: '\n'));
      } else if (inline is DocxTab) {
        spans.add(const TextSpan(text: '\t'));
      } else if (inline is DocxInlineImage) {
        spans.add(WidgetSpan(
          child: Image.memory(
            inline.bytes,
            width: inline.width?.toDouble(),
            height: inline.height?.toDouble(),
          ),
        ));
      } else if (inline is DocxShape) {
        spans.add(WidgetSpan(
          child: _buildInlineShape(inline),
        ));
      }
    }

    return spans;
  }

  /// Build a TextSpan from a [DocxText] element.
  TextSpan _buildTextSpan(DocxText text) {
    // Determine text style
    FontWeight fontWeight = text.fontWeight == DocxFontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal;

    FontStyle fontStyle = text.fontStyle == DocxFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

    TextDecoration decoration = TextDecoration.none;
    if (text.decoration == DocxTextDecoration.underline) {
      decoration = TextDecoration.underline;
    } else if (text.decoration == DocxTextDecoration.strikethrough) {
      decoration = TextDecoration.lineThrough;
    }

    Color? textColor;
    if (text.color != null) {
      textColor = _parseHexColor(text.color!.hex);
    }

    Color? backgroundColor;
    if (text.shadingFill != null) {
      backgroundColor = _parseHexColor(text.shadingFill!);
    } else if (text.highlight != null && text.highlight != DocxHighlight.none) {
      backgroundColor = _highlightToColor(text.highlight!);
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

    final style = TextStyle(
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: textColor ?? theme.defaultTextStyle.color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontFamilyFallback: config.customFontFallbacks,
      height: theme.defaultTextStyle.height,
    );

    // Handle hyperlinks
    if (text.href != null && text.href!.isNotEmpty) {
      return TextSpan(
        text: text.content,
        style: style.copyWith(
          color: theme.linkStyle.color,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _launchUrl(text.href!);
          },
      );
    }

    return TextSpan(
      text: text.content,
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
                width: shape.outlineWidth ?? 1,
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
