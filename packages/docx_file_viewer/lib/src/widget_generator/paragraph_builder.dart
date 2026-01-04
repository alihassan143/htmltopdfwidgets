import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../docx_view_config.dart';
import '../search/docx_search_controller.dart';
import '../theme/docx_view_theme.dart';
import '../widgets/drop_cap_text.dart';

/// Builds Flutter widgets from [DocxParagraph] elements.
class ParagraphBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final DocxTheme? docxTheme;
  final DocxSearchController? searchController;
  final void Function(int id)? onFootnoteTap;
  final void Function(int id)? onEndnoteTap;

  // Used for search highlighting

  ParagraphBuilder({
    required this.theme,
    required this.config,
    this.searchController,
    this.onFootnoteTap,
    this.onEndnoteTap,
    this.docxTheme,
  });

  /// Build a widget from a [DocxParagraph].
  Widget build(DocxParagraph paragraph, {int? blockIndex}) {
    return _buildNativeParagraph(paragraph);
  }

  /// Build a paragraph widget, excluding specific floating images.
  /// Used when specific floats are being handled separately at the block level.
  Widget buildExcludingFloats(
      DocxParagraph paragraph, Set<DocxInline> excludedFloats) {
    return _buildNativeParagraph(paragraph, excludedFloats: excludedFloats);
  }

  /// Native Flutter builder for standard paragraphs.
  Widget _buildNativeParagraph(DocxParagraph paragraph,
      {Set<DocxInline>? excludedFloats}) {
    List<(DocxInline, DocxAlign?)> textChildren = [];

    // Separate content
    for (var child in paragraph.children) {
      bool isFloating = false;
      DocxAlign align = DocxAlign.left; // Default logic

      if (child is DocxInlineImage &&
          child.positionMode == DocxDrawingPosition.floating) {
        if (excludedFloats?.contains(child) ?? false) {
          continue; // Skip specific excluded float
        }
        isFloating = true;
        if (child.hAlign == DrawingHAlign.center) {
          align = DocxAlign.center;
        } else {
          align = child.hAlign == DrawingHAlign.right
              ? DocxAlign.right
              : DocxAlign.left;
        }
      } else if (child is DocxShape &&
          child.position == DocxDrawingPosition.floating) {
        if (excludedFloats?.contains(child) ?? false) {
          continue; // Skip specific excluded float
        }
        isFloating = true;
        if (child.horizontalAlign == DrawingHAlign.center) {
          align = DocxAlign.center;
        } else {
          align = child.horizontalAlign == DrawingHAlign.right
              ? DocxAlign.right
              : DocxAlign.left;
        }
      }

      textChildren.add((child, isFloating ? align : null));
    }

    // List of block-level widgets (rows or center blocks)
    final List<Widget> columnChildren = [];

    // Buffers for the current "Row" context
    List<DocxInline> currentLeftFloats = [];
    List<DocxInline> currentRightFloats = [];
    List<DocxInline> currentInlines = [];

    double? lineHeightScale;
    if (paragraph.lineSpacing != null) {
      lineHeightScale = paragraph.lineSpacing! / 240.0;
    }
    final textAlign = _convertAlign(paragraph.align);

    // Helper to flush current buffers into a single layout row
    void flushBuffer() {
      if (currentInlines.isEmpty &&
          currentLeftFloats.isEmpty &&
          currentRightFloats.isEmpty) {
        return;
      }

      final spans =
          _buildTextSpans(currentInlines, lineHeight: lineHeightScale);
      final fullTextSpan =
          TextSpan(style: theme.defaultTextStyle, children: spans);

      Widget rowWidget;

      // If we have any floating elements, we MUST use the floating layout (Row)
      // to ensure they sit side-by-side with text.
      if (currentLeftFloats.isNotEmpty || currentRightFloats.isNotEmpty) {
        // Create copies to separate from buffer
        final lefts = List<DocxInline>.from(currentLeftFloats);
        final rights = List<DocxInline>.from(currentRightFloats);

        rowWidget = _buildFloatingLayout(
          textSpan: fullTextSpan,
          leftElements: lefts,
          rightElements: rights,
          textAlign: textAlign,
          lineHeightScale: lineHeightScale,
        );
      } else {
        // Standard text layout for efficiency if no floats
        if (config.enableSelection) {
          rowWidget = SelectableText.rich(
            fullTextSpan,
            textAlign: textAlign,
          );
        } else {
          rowWidget = RichText(
            text: fullTextSpan,
            textAlign: textAlign,
          );
        }
        // Ensure it takes width to respect alignment
        rowWidget = SizedBox(width: double.infinity, child: rowWidget);
      }

      columnChildren.add(rowWidget);

      currentLeftFloats.clear();
      currentRightFloats.clear();
      currentInlines.clear();
    }

    // Iterate through children and bucket them into Rows
    for (var child in paragraph.children) {
      if (excludedFloats?.contains(child) ?? false) {
        continue; // Skip specific excluded float
      }
      DocxAlign? align;
      if (child is DocxInlineImage) {
        if (child.positionMode == DocxDrawingPosition.floating) {
          align = child.hAlign == DrawingHAlign.left
              ? DocxAlign.left
              : (child.hAlign == DrawingHAlign.right
                  ? DocxAlign.right
                  : DocxAlign.center);
        }
      } else if (child is DocxShape) {
        if (child.position == DocxDrawingPosition.floating) {
          align = child.horizontalAlign == DrawingHAlign.left
              ? DocxAlign.left
              : (child.horizontalAlign == DrawingHAlign.right
                  ? DocxAlign.right
                  : DocxAlign.center);
        }
      }

      if (align == DocxAlign.center) {
        // A Center float breaks the current Row.
        flushBuffer();

        Widget centerWidget;
        if (child is DocxInlineImage) {
          centerWidget = Image.memory(
            child.bytes,
            width: child.width,
            height: child.height,
            fit: BoxFit.contain,
          );
        } else if (child is DocxShape) {
          centerWidget = _buildInlineShape(child);
        } else {
          centerWidget = const SizedBox.shrink();
        }
        columnChildren.add(Center(child: centerWidget));
      } else if (align == DocxAlign.left) {
        currentLeftFloats.add(child);
      } else if (align == DocxAlign.right) {
        currentRightFloats.add(child);
      } else {
        currentInlines.add(child);
      }
    }

    // Flush any remaining content
    flushBuffer();

    // Final Assembly
    Widget finalContent;
    if (columnChildren.isEmpty) {
      finalContent = const SizedBox();
    } else if (columnChildren.length == 1) {
      finalContent = columnChildren.first;
    } else {
      finalContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columnChildren
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: w,
                ))
            .toList(),
      );
    }

    return _wrapWithParagraphStyle(paragraph, finalContent);
  }

  /// Builds a layout that wraps text around left and/or right floating elements.
  ///
  /// Uses IntrinsicHeight with Row for proper alignment of floating images and text.
  Widget _buildFloatingLayout({
    required TextSpan textSpan,
    List<DocxInline> leftElements = const [],
    List<DocxInline> rightElements = const [],
    required TextAlign textAlign,
    double? lineHeightScale,
  }) {
    const double floatSpacing = 12.0;

    // Helper to build the widget for a floating element
    Widget? buildFloatWidget(DocxInline? element) {
      if (element == null) return null;
      if (element is DocxInlineImage) {
        return Image.memory(
          element.bytes,
          width: element.width,
          height: element.height,
          fit: BoxFit.contain,
        );
      } else if (element is DocxShape) {
        return _buildInlineShape(element);
      }
      return null;
    }

    // Build a column of floating elements
    Widget buildFloatColumn(List<DocxInline> elements) {
      if (elements.isEmpty) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: elements.map((e) {
          final widget = buildFloatWidget(e) ?? const SizedBox.shrink();
          final index = elements.indexOf(e);
          if (index < elements.length - 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: widget,
            );
          }
          return widget;
        }).toList(),
      );
    }

    // Build the text widget
    Widget textWidget = config.enableSelection
        ? SelectableText.rich(textSpan, textAlign: textAlign)
        : RichText(text: textSpan, textAlign: textAlign);

    // Use IntrinsicHeight to allow text to wrap naturally beside floats
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leftElements.isNotEmpty) ...[
            buildFloatColumn(leftElements),
            const SizedBox(width: floatSpacing),
          ],
          Expanded(child: textWidget),
          if (rightElements.isNotEmpty) ...[
            const SizedBox(width: floatSpacing),
            buildFloatColumn(rightElements),
          ],
        ],
      ),
    );
  }

  /// Helper to apply paragraph decorations (indent, padding, shading, borders)
  Widget _wrapWithParagraphStyle(DocxParagraph paragraph, Widget content) {
    // Apply paragraph styling from DocxParagraph properties
    const double twipsToPixels = 1 / 15.0;

    // Clamp all padding values to non-negative to prevent assertion errors
    double leftPadding =
        ((paragraph.indentLeft ?? 0) * twipsToPixels).clamp(0, double.infinity);
    double rightPadding = ((paragraph.indentRight ?? 0) * twipsToPixels)
        .clamp(0, double.infinity);
    double topPadding = ((paragraph.spacingBefore ?? 80) * twipsToPixels)
        .clamp(0, double.infinity);
    double bottomPadding = ((paragraph.spacingAfter ?? 80) * twipsToPixels)
        .clamp(0, double.infinity);

    // Heading detection
    if (paragraph.children.isNotEmpty) {
      final first = paragraph.children.first;
      if (first is DocxText &&
          first.fontSize != null &&
          first.fontSize! >= 20) {
        topPadding = topPadding.clamp(16, double.infinity);
        bottomPadding = bottomPadding.clamp(8, double.infinity);
      }
    }

    BoxDecoration? decoration = _buildParagraphDecoration(paragraph);

    // Page break
    if (paragraph.pageBreakBefore) {
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

    // Choose the most specific bottom border available
    // Prioritize borderBottomSide (DocxBorderSide)
    final bottomSpec = paragraph.borderBottomSide ?? paragraph.borderBetween;

    if (bottomSpec != null) {
      bottomBorder = _buildBorderSide(bottomSpec);
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
    final width = (side.size / 8.0).clamp(0.5, 10.0);
    final color = _resolveColor(
            side.color.hex, side.themeColor, side.themeTint, side.themeShade) ??
        Colors.black;

    return BorderSide(
      color: color,
      width: width,
      style: side.style == DocxBorder.dotted
          ? BorderStyle.none
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
        // Inline images with proper vertical alignment
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
      } else if (inline is DocxFootnoteRef) {
        spans.add(_buildFootnoteRef(inline));
      } else if (inline is DocxEndnoteRef) {
        spans.add(_buildEndnoteRef(inline));
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
  InlineSpan _buildTextSpan(DocxText text, {double? lineHeight}) {
    // Transform content based on text effects
    String content = text.content;
    if (text.isAllCaps) {
      content = content.toUpperCase();
    } else if (text.isSmallCaps) {
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
      textColor = _resolveColor(
        text.color!.hex,
        text.themeColor ?? text.color!.themeColor,
        text.themeTint ?? text.color!.themeTint,
        text.themeShade ?? text.color!.themeShade,
      );
    }

    Color? backgroundColor;
    if (text.shadingFill != null || text.themeFill != null) {
      backgroundColor = _resolveColor(
        text.shadingFill,
        text.themeFill,
        text.themeFillTint,
        text.themeFillShade,
      );
    }

    if (backgroundColor == null && text.highlight != DocxHighlight.none) {
      backgroundColor = _highlightToColor(text.highlight);
    }

    double? fontSize = text.fontSize;
    if (fontSize != null) {
      fontSize = fontSize * 1.333;
    } else {
      fontSize = theme.defaultTextStyle.fontSize;
    }

    String? fontFamily; // Start with null to prioritize granular resolution

    // Resolve Theme Font if applicable
    if (docxTheme != null) {
      String? themeFontName;
      if (text.fonts?.asciiTheme != null) {
        themeFontName = text.fonts!.asciiTheme;
      } else if (text.fonts?.hAnsiTheme != null) {
        themeFontName = text.fonts!.hAnsiTheme;
      } else if (text.fonts?.eastAsiaTheme != null) {
        themeFontName = text.fonts!.eastAsiaTheme;
      }

      if (themeFontName != null) {
        final resolved = docxTheme!.fonts.getFont(themeFontName);
        if (resolved != null) {
          fontFamily = resolved;
        }
      }
    }

    // granular fonts override theme or base family
    if (text.fonts?.ascii != null) {
      fontFamily = text.fonts!.ascii;
    } else if (text.fonts?.hAnsi != null) {
      fontFamily = text.fonts!.hAnsi;
    } else if (text.fonts?.family != null) {
      fontFamily = text.fonts!.family;
    }

    // Fallback to basic fontFamily property if still null
    fontFamily ??= text.fontFamily;

    // Apply font fallbacks
    if (fontFamily == null && config.customFontFallbacks.isNotEmpty) {
      fontFamily = config.customFontFallbacks.first;
    }

    if (text.isSuperscript || text.isSubscript) {
      fontSize = (fontSize ?? 14) * 0.7;
    }

    if (text.isSmallCaps && !text.isAllCaps) {
      fontSize = (fontSize ?? 14) * 0.85;
    }

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

    Paint? foreground;
    if (text.isOutline) {
      foreground = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = textColor ?? Colors.black;
      textColor = null;
    }

    BoxBorder? textBorder;
    if (text.textBorder != null) {
      final side = _buildBorderSide(text.textBorder!);
      if (side != BorderSide.none) {
        textBorder =
            Border.all(color: side.color, width: side.width, style: side.style);
      }
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
      letterSpacing:
          text.characterSpacing != null ? text.characterSpacing! / 20.0 : null,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontFamilyFallback: config.customFontFallbacks,
      height: lineHeight ?? theme.defaultTextStyle.height,
      shadows: shadows,
      fontFeatures: (text.isSuperscript || text.isSubscript)
          ? [
              if (text.isSuperscript) const FontFeature.superscripts(),
              if (text.isSubscript) const FontFeature.subscripts(),
            ]
          : null,
    );

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

    if (textBorder != null) {
      return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            decoration: BoxDecoration(
              border: textBorder,
              color: backgroundColor,
            ),
            child: Text(content, style: style.copyWith(backgroundColor: null)),
          ));
    }

    return TextSpan(
      text: content,
      style: style,
    );
  }

  /// Resolve color from hex or theme properties.
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
        baseColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        final factor = shadeVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - factor), baseColor);
      }
    }

    return baseColor;
  }

  /// Build a widget for a paragraph with a drop cap.
  Widget buildDropCap(DocxDropCap dropCap) {
    const pointToPx = 1.333;
    final defaultFontSize = theme.defaultTextStyle.fontSize ?? 14.0;

    double fontSizePx;
    if (dropCap.fontSize != null) {
      fontSizePx = dropCap.fontSize! * pointToPx;
    } else {
      fontSizePx = dropCap.lines * defaultFontSize * 1.2;
    }

    final color = theme.defaultTextStyle.color ?? Colors.black;
    final fontFamily = dropCap.fontFamily ?? theme.defaultTextStyle.fontFamily;

    final dropCapStyle = TextStyle(
        fontSize: fontSizePx,
        color: color,
        fontFamily: fontFamily,
        height: 1.0,
        fontWeight: FontWeight.bold);

    final painter = TextPainter(
      text: TextSpan(text: dropCap.letter, style: dropCapStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final dcWidth = painter.width;
    final dcHeight = painter.height;

    // Use theme defaults for the body text of the drop cap paragraph
    final bodyStyle = TextStyle(
      fontSize: defaultFontSize,
      color: theme.defaultTextStyle.color,
      fontFamily: theme.defaultTextStyle.fontFamily,
      height: theme.defaultTextStyle.height,
    );

    final spans = _buildTextSpans(dropCap.restOfParagraph);
    final fullTextSpan = TextSpan(children: spans, style: bodyStyle);

    String restPlainText = '';
    for (final inline in dropCap.restOfParagraph) {
      if (inline is DocxText) {
        restPlainText += inline.content;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropCapText(
        restPlainText, // Only the rest of paragraph text, matching textSpan
        textSpan: fullTextSpan,
        dropCap: DropCap(
          width: dcWidth,
          height: dcHeight,
          child: Text(dropCap.letter, style: dropCapStyle),
        ),
        mode: DropCapMode.inside,
        forceNoDescent: true,
        dropCapLines: dropCap.lines,
        dropCapPadding:
            EdgeInsets.only(right: (dropCap.hSpace / 20.0).clamp(4.0, 20.0)),
      ),
    );
  }

  TextSpan _buildFootnoteRef(DocxFootnoteRef ref) {
    return TextSpan(
      text: '${ref.footnoteId}',
      style: TextStyle(
        fontSize: (theme.defaultTextStyle.fontSize ?? 14) * 0.6,
        color: theme.linkStyle.color,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onFootnoteTap?.call(ref.footnoteId);
        },
    );
  }

  TextSpan _buildEndnoteRef(DocxEndnoteRef ref) {
    return TextSpan(
      text: '${ref.endnoteId}',
      style: TextStyle(
        fontSize: (theme.defaultTextStyle.fontSize ?? 14) * 0.6,
        color: theme.linkStyle.color,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onEndnoteTap?.call(ref.endnoteId);
        },
    );
  }

  Widget _buildInlineShape(DocxShape shape) {
    return Container(
      width: shape.width,
      height: shape.height,
      decoration: BoxDecoration(
        color: _resolveColor(shape.fillColor?.hex, shape.fillColor?.themeColor,
            shape.fillColor?.themeTint, shape.fillColor?.themeShade),
        border: shape.outlineColor != null
            ? Border.all(
                color: _resolveColor(
                        shape.outlineColor!.hex,
                        shape.outlineColor!.themeColor,
                        shape.outlineColor!.themeTint,
                        shape.outlineColor!.themeShade) ??
                    Colors.black,
                width: shape.outlineWidth)
            : null,
      ),
    );
  }

  TextAlign _convertAlign(DocxAlign align) {
    switch (align) {
      case DocxAlign.left:
        return TextAlign.left;
      case DocxAlign.center:
        return TextAlign.center;
      case DocxAlign.right:
        return TextAlign.right;
      case DocxAlign.justify:
        return TextAlign.justify;
    }
  }

  Color? _parseHexColor(String hex) {
    if (hex == 'auto') return Colors.black;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 8) {
        if (hex.length == 6) buffer.write('ff');
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      }
    } catch (_) {}
    return null;
  }

  Color? _highlightToColor(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.black:
        return Colors.black;
      case DocxHighlight.blue:
        return Colors.blue;
      case DocxHighlight.cyan:
        return Colors.cyan;
      case DocxHighlight.green:
        return Colors.green;
      case DocxHighlight.magenta:
        return const Color(0xFFFF00FF);
      case DocxHighlight.red:
        return Colors.red;
      case DocxHighlight.yellow:
        return Colors.yellow;
      case DocxHighlight.white:
        return Colors.white;
      case DocxHighlight.darkBlue:
        return Colors.blue.shade900;
// ... (omitted for brevity in prompt but I will be careful in actual replacement)
// Actually I should just target specific methods.

// 1. Fixing highlighting color
// 2. Fixing _ParagraphSliceWalker

      case DocxHighlight.darkCyan:
        return Colors.cyan.shade900;
      case DocxHighlight.darkGreen:
        return Colors.green.shade900;
      case DocxHighlight.darkMagenta:
        return Colors.purple.shade900;
      case DocxHighlight.darkRed:
        return Colors.red.shade900;
      case DocxHighlight.darkYellow:
        return Colors.yellow.shade800;
      case DocxHighlight.darkGray:
        return Colors.grey.shade700;
      case DocxHighlight.lightGray:
        return Colors.grey.shade300;
      case DocxHighlight.none:
        return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
