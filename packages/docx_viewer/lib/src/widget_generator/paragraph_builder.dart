import 'dart:math';

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
  final DocxSearchController? searchController;
  final void Function(int id)? onFootnoteTap;
  final void Function(int id)? onEndnoteTap;
  // Used for search highlighting - currently reserved for future use
  // ignore: unused_field
  int _blockIndex = 0;

  ParagraphBuilder({
    required this.theme,
    required this.config,
    this.searchController,
    this.onFootnoteTap,
    this.onEndnoteTap,
  });

  /// Set the current block index for search highlighting.
  void setBlockIndex(int index) {
    _blockIndex = index;
  }

  /// Build a widget from a [DocxParagraph].
  Widget build(DocxParagraph paragraph, {int? blockIndex}) {
    if (blockIndex != null) _blockIndex = blockIndex;
    return _buildNativeParagraph(paragraph);
  }

  /// Native Flutter builder for standard paragraphs.
  Widget _buildNativeParagraph(DocxParagraph paragraph) {
    // Check for floating elements (images or shapes) to use specific wrapping layout
    DocxInline? leftFloatingElement;
    DocxInline? rightFloatingElement;
    List<DocxInline> textChildren = [];

    // Separate content
    for (var child in paragraph.children) {
      bool isFloating = false;
      DocxAlign align = DocxAlign.left; // Default logic

      if (child is DocxInlineImage &&
          child.positionMode == DocxDrawingPosition.floating) {
        isFloating = true;
        align = child.hAlign == DrawingHAlign.right
            ? DocxAlign.right
            : DocxAlign.left;
      } else if (child is DocxShape &&
          child.position == DocxDrawingPosition.floating) {
        isFloating = true;
        align = child.horizontalAlign == DrawingHAlign.right
            ? DocxAlign.right
            : DocxAlign.left;
      }

      if (isFloating) {
        if (align == DocxAlign.right) {
          rightFloatingElement = child;
        } else {
          leftFloatingElement = child;
        }
      } else {
        textChildren.add(child);
      }
    }

    // Build the text spans
    double? lineHeightScale;
    if (paragraph.lineSpacing != null) {
      lineHeightScale = paragraph.lineSpacing! / 240.0;
    }

    final spans = _buildTextSpans(textChildren, lineHeight: lineHeightScale);
    final fullTextSpan = TextSpan(children: spans);
    final textAlign = _convertAlign(paragraph.align);

    // If we have floating elements, build wrap layout
    if (leftFloatingElement != null || rightFloatingElement != null) {
      return _wrapWithParagraphStyle(
          paragraph,
          _buildFloatingLayout(
            textSpan: fullTextSpan,
            leftElement: leftFloatingElement,
            rightElement: rightFloatingElement,
            textAlign: textAlign,
            lineHeightScale: lineHeightScale,
          ));
    }

    // Standard paragraph
    Widget textContent;
    if (config.enableSelection) {
      textContent = SelectableText.rich(
        fullTextSpan,
        textAlign: textAlign,
      );
    } else {
      textContent = RichText(
        text: fullTextSpan,
        textAlign: textAlign,
      );
    }

    // Ensure strictly full width to respect alignment
    textContent = SizedBox(width: double.infinity, child: textContent);

    return _wrapWithParagraphStyle(paragraph, textContent);
  }

  /// Builds a layout that wraps text around left and/or right floating elements.
  Widget _buildFloatingLayout({
    required TextSpan textSpan,
    DocxInline? leftElement,
    DocxInline? rightElement,
    required TextAlign textAlign,
    double? lineHeightScale,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      // 1. Measure elements
      double lWidth = 0, lHeight = 0;
      double rWidth = 0, rHeight = 0;

      Widget? lWidget, rWidget;

      if (leftElement != null) {
        if (leftElement is DocxInlineImage) {
          lWidth = leftElement.width;
          lHeight = leftElement.height;
          lWidget = Image.memory(leftElement.bytes,
              width: lWidth, height: lHeight, fit: BoxFit.contain);
        } else if (leftElement is DocxShape) {
          lWidth = leftElement.width;
          lHeight = leftElement.height;
          lWidget = _buildInlineShape(leftElement);
        }

        // Add padding
        if (lWidget != null) {
          lWidth += 12.0;
          lWidget = Padding(
              padding: const EdgeInsets.only(right: 12.0), child: lWidget);
        }
      }

      if (rightElement != null) {
        if (rightElement is DocxInlineImage) {
          rWidth = rightElement.width;
          rHeight = rightElement.height;
          rWidget = Image.memory(rightElement.bytes,
              width: rWidth, height: rHeight, fit: BoxFit.contain);
        } else if (rightElement is DocxShape) {
          rWidth = rightElement.width;
          rHeight = rightElement.height;
          rWidget = _buildInlineShape(rightElement);
        }

        if (rWidget != null) {
          rWidth += 12.0;
          rWidget = Padding(
              padding: const EdgeInsets.only(left: 12.0), child: rWidget);
        }
      }

      final floatHeight =
          max(lHeight, rHeight); // We wrap under the tallest one

      final availableWidth = constraints.maxWidth - lWidth - rWidth;
      if (availableWidth <= 0) return const SizedBox(); // Too narrow

      // 2. Measure text to see how many lines fit in the float height
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: textAlign,
      );

      // Fix for WidgetSpan crash: provide placeholder dimensions
      final placeholders = _getPlaceholderDimensions(textSpan);
      if (placeholders.isNotEmpty) {
        textPainter.setPlaceholderDimensions(placeholders);
      }

      textPainter.layout(
          maxWidth: constraints.maxWidth); // First to get line height

      double lineHeight = textPainter.preferredLineHeight;
      if (lineHeight == 0) lineHeight = 14.0;

      int rows = (floatHeight / lineHeight).ceil();
      if (rows == 0 && floatHeight > 0) rows = 1;

      // 3. Find break point
      textPainter.maxLines = rows;
      textPainter.layout(maxWidth: availableWidth);

      int breakIndex = 0;
      if (!textPainter.didExceedMaxLines) {
        // Fits completely
        breakIndex = -1; // Flag for all
      } else {
        // Get exact break
        final pos = textPainter
            .getPositionForOffset(Offset(availableWidth, floatHeight - 1));
        breakIndex = pos.offset;
      }

      // 4. Slice
      TextSpan? span1, span2;

      if (breakIndex == -1) {
        span1 = textSpan;
      } else {
        span1 = _sliceSpan(textSpan, 0, breakIndex);
        span2 = _sliceSpan(textSpan, breakIndex);
      }

      // 5. Build
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lWidget != null) lWidget,
              Expanded(
                child: SizedBox(
                  height: floatHeight > 0
                      ? floatHeight
                      : null, // Force height match if not empty
                  child: RichText(
                    text: span1 ?? const TextSpan(text: ''),
                    textAlign: textAlign,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              if (rWidget != null) rWidget,
            ],
          ),
          if (span2 != null)
            RichText(
              text: span2,
              textAlign: textAlign,
            )
        ],
      );
    });
  }

  /// Helper to collect placeholder dimensions for WidgetSpans.
  List<PlaceholderDimensions> _getPlaceholderDimensions(InlineSpan span) {
    List<PlaceholderDimensions> dimensions = [];
    span.visitChildren((child) {
      if (child is WidgetSpan) {
        dimensions.add(const PlaceholderDimensions(
            size: Size(14, 14), alignment: PlaceholderAlignment.middle));
      }
      return true;
    });
    return dimensions;
  }

  // Helper moved from DropCapText (simplified version for local use)
  TextSpan? _sliceSpan(TextSpan span, int start, [int? end]) {
    final walker = _ParagraphSliceWalker(start, end);
    walker.visit(span);
    if (walker.result.isEmpty) return null;
    return TextSpan(children: walker.result);
  }

  /// Helper to build rich text content (Deprecated/Refactored into inline logic above)
  /// Kept for buildDropCap usage if needed, or remove?
  /// _buildTextContent above was removed/replaced in _buildNativeParagraph?
  /// wait, I am replacing lines 38-141. _buildTextContent was at line 111.
  /// So checking if buildDropCap or others use it.
  /// buildDropCap uses `_buildTextSpans`.
  /// No other usages of `_buildTextContent` in this file.

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

    // Handle first line indent (only applies if we have a simple block, but here we apply to wrapper padding?)
    // Actually standard first line indent shifts the first line text.
    // If we have a Row layout, the indent should apply to the TEXT block.
    // For simplicity, we apply wrapping padding here.

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
    final color = _parseHexColor(side.color.hex) ?? Colors.black;

    return BorderSide(
      color: color,
      width: width,
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

    double? fontSize = text.fontSize;
    if (fontSize != null) {
      // Convert Points to Logical Pixels
      // 1 pt = 1.333 px (96 dpi / 72 dpi)
      fontSize = fontSize * 1.333;
    } else {
      fontSize = theme.defaultTextStyle.fontSize;
    }

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

    // Text Border
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

    // Check if we need to wrap text in a Container for border (WidgetSpan)
    if (textBorder != null) {
      return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            decoration: BoxDecoration(
              border: textBorder,
              color:
                  backgroundColor, // Background needs to be here if border is present
            ),
            child: Text(content, style: style.copyWith(backgroundColor: null)),
          ));
    }

    return TextSpan(
      text: content,
      style: style,
    );
  }

  /// Build a widget for a paragraph with a drop cap.
  Widget buildDropCap(DocxDropCap dropCap) {
    // Uses the custom DropCapText widget for robust "L-shaped" text wrapping.

    // Scale the drop cap letter
    const pointToPx = 1.333;
    final defaultFontSize = theme.defaultTextStyle.fontSize ?? 14.0;

    double fontSizePx;
    if (dropCap.fontSize != null) {
      fontSizePx = dropCap.fontSize! * pointToPx;
    } else {
      // Estimate font size based on number of lines
      // Standard line height is usually ~1.2 * fontSize.
      // We want the cap to span 'lines' text lines.
      // Height ≈ lines * (fontSize * 1.2)
      // So fontSize of cap ≈ Height (since height: 1.0)
      fontSizePx = dropCap.lines * defaultFontSize * 1.2;
    }

    final color = theme.defaultTextStyle.color ?? Colors.black;
    final fontFamily = dropCap.fontFamily ?? theme.defaultTextStyle.fontFamily;

    // Measure the drop cap
    final dropCapStyle = TextStyle(
        fontSize: fontSizePx,
        color: color,
        fontFamily: fontFamily,
        height: 1.0,
        fontWeight: FontWeight.bold);

    // We treat the drop cap as a simple text span for standard cases
    final painter = TextPainter(
      text: TextSpan(text: dropCap.letter, style: dropCapStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final dcWidth = painter.width;
    final dcHeight = painter.height;

    // Build the rest of paragraph TextSpan
    final spans = _buildTextSpans(dropCap.restOfParagraph);
    final fullTextSpan = TextSpan(children: spans);

    // Extract plain text for DropCapText's data parameter (required for sizing)
    String restPlainText = '';
    for (final inline in dropCap.restOfParagraph) {
      if (inline is DocxText) {
        restPlainText += inline.content;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropCapText(
        restPlainText, // Non-empty data required for proper layout
        textSpan: fullTextSpan,
        dropCap: DropCap(
          width: dcWidth,
          height: dcHeight,
          child: Text(dropCap.letter, style: dropCapStyle),
        ),
        mode: DropCapMode.inside, // L-shape
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
        color: shape.fillColor != null
            ? (_parseHexColor(shape.fillColor!.hex) ?? Colors.grey.shade200)
            : Colors.grey.shade200,
        border: shape.outlineColor != null
            ? Border.all(
                color: _parseHexColor(shape.outlineColor!.hex) ?? Colors.black,
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

  Color? _parseHexColor(String hex) {
    // Handle 'auto' and empty strings
    if (hex.isEmpty || hex.toLowerCase() == 'auto') {
      return null;
    }

    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');

    // Handle common named colors from DOCX
    switch (cleanHex.toLowerCase()) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'cyan':
        return Colors.cyan;
      case 'magenta':
        return Colors.pink;
    }

    if (cleanHex.length == 6) {
      try {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } catch (e) {
        return null;
      }
    } else if (cleanHex.length == 8) {
      try {
        return Color(int.parse(cleanHex, radix: 16));
      } catch (e) {
        return null;
      }
    }
    return null;
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
    if (c == null) return Colors.black;
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

class _ParagraphSliceWalker {
  final int start;
  final int? end;
  final List<InlineSpan> result = [];
  int currentPos = 0;

  _ParagraphSliceWalker(this.start, this.end);

  void visit(InlineSpan root) {
    final List<InlineSpan> stack = [root];

    while (stack.isNotEmpty) {
      final span = stack.removeLast();

      if (span is TextSpan) {
        final text = span.text;
        if (text != null) {
          final len = text.length;
          final rangeStart = currentPos;
          final rangeEnd = currentPos + len;

          final reqStart = start;
          final reqEnd = end ?? 0x7FFFFFFF;

          final overlapStart = max(rangeStart, reqStart);
          final overlapEnd = min(rangeEnd, reqEnd);

          if (overlapStart < overlapEnd) {
            final s = overlapStart - rangeStart;
            final e = overlapEnd - rangeStart;
            result.add(TextSpan(
              text: text.substring(s, e),
              style: span.style,
              recognizer: span.recognizer,
            ));
          }
          currentPos += len;
        }

        if (span.children != null) {
          // Push children in reverse order to process them in correct order (DFS)
          final children = span.children!;
          for (var i = children.length - 1; i >= 0; i--) {
            stack.add(children[i]);
          }
        }
      } else if (span is WidgetSpan) {
        if (currentPos >= start && (end == null || currentPos < end!)) {
          result.add(span);
        }
        currentPos += 1;
      }
    }
  }
}
