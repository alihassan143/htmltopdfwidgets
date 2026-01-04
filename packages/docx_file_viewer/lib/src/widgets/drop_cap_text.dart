import 'dart:math';

import 'package:flutter/material.dart';

/// Positioning mode for the drop cap relative to the text.
enum DropCapMode {
  /// Default mode: drop cap is positioned inside the text, spanning multiple lines.
  inside,

  /// Drop cap is positioned upwards, aligned with the top of the first line.
  upwards,

  /// Drop cap is positioned aside the text, to the left or right.
  aside,

  /// Drop cap is positioned on the baseline with the text.
  ///
  /// Does not support dropCapPadding, indentation, dropCapPosition and custom dropCap.
  /// Try using DropCapMode.upwards in combination with dropCapPadding and forceNoDescent=true
  baseline,
}

/// Position of the drop cap relative to the text.
enum DropCapPosition {
  /// Drop cap appears at the start of the text.
  start,

  /// Drop cap appears at the end of the text.
  end,
}

/// A custom widget for the drop cap character.
///
/// Use this class to provide a custom widget instead of using the default
/// text-based drop cap. This allows for complete customization of the drop
/// cap appearance.
class DropCap extends StatelessWidget {
  /// Creates a custom drop cap widget.
  ///
  /// The [child] is the widget to display as the drop cap.
  /// The [width] and [height] define the dimensions of the drop cap.
  const DropCap(
      {required this.child,
      required this.width,
      required this.height,
      super.key});

  /// The widget to display as the drop cap.
  final Widget child;

  /// The width of the drop cap.
  final double width;

  /// The height of the drop cap.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: child);
  }
}

/// A widget that displays text with a stylized drop cap (initial letter) effect.
///
/// The drop cap is typically the first letter of the text, displayed in a
/// larger size and positioned to span multiple lines of the following text.
///
/// Example:
/// ```dart
/// DropCapText(
///   'Lorem ipsum dolor sit amet...',
///   mode: DropCapMode.inside,
///   dropCapStyle: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
/// )
/// ```
class DropCapText extends StatelessWidget {
  /// Creates a drop cap text widget.
  ///
  /// The [data] parameter is the text to display with a drop cap effect.
  ///
  /// The [mode] parameter controls how the drop cap is positioned relative
  /// to the text. Defaults to [DropCapMode.inside].
  ///
  /// The [style] parameter applies to the main text body.
  ///
  /// The [dropCapStyle] parameter applies to the drop cap character(s).
  /// If not provided, the drop cap will use a larger version of [style].
  ///
  /// The [dropCap] parameter allows you to provide a custom widget for the
  /// drop cap instead of using the default text-based drop cap.
  const DropCapText(
    this.data, {
    this.textSpan,
    super.key,
    this.mode = DropCapMode.inside,
    this.style,
    this.dropCapStyle,
    this.textAlign = TextAlign.start,
    this.dropCap,
    this.dropCapPadding = EdgeInsets.zero,
    this.indentation = Offset.zero,
    this.dropCapChars = 1,
    this.forceNoDescent = false,
    this.parseInlineMarkdown = false,
    this.textDirection = TextDirection.ltr,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.dropCapPosition,
    this.dropCapLines,
  });

  /// The text to display with a drop cap effect.
  final String data;

  /// The rich text content if using styled text instead of plain string.
  final TextSpan? textSpan;

  /// The positioning mode for the drop cap.
  final DropCapMode mode;

  /// The text style for the main text body.
  final TextStyle? style;

  /// The text style for the drop cap character(s).
  final TextStyle? dropCapStyle;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// A custom widget to use as the drop cap instead of the default text.
  final DropCap? dropCap;

  /// Padding around the drop cap.
  final EdgeInsets dropCapPadding;

  /// Indentation offset for the text body relative to the drop cap.
  final Offset indentation;

  /// Whether to force no descent on the drop cap (useful for certain fonts).
  final bool forceNoDescent;

  /// Whether to parse inline markdown in the text (supports **bold**, _italic_, ++underline++).
  final bool parseInlineMarkdown;

  /// The directionality of the text.
  final TextDirection textDirection;

  /// The position of the drop cap relative to the text.
  final DropCapPosition? dropCapPosition;

  /// The number of characters to use for the drop cap.
  final int dropCapChars;

  /// An optional maximum number of lines for the text to span.
  final int? maxLines;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  /// The number of lines the drop cap should span.
  ///
  /// If provided, this overrides the height-based calculation.
  final int? dropCapLines;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      fontSize: 14,
      height: 1,
      fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
    ).merge(style);

    if (data == '') return Text(data, style: textStyle);

    final capStyle = TextStyle(
      color: textStyle.color,
      fontSize: textStyle.fontSize! * 5.5,
      fontFamily: textStyle.fontFamily,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      height: 1,
    ).merge(dropCapStyle);

    double capWidth;
    double capHeight;
    final dropCapChars = dropCap != null ? 0 : this.dropCapChars;
    var sideCrossAxisAlignment = CrossAxisAlignment.start;
    final mdData = parseInlineMarkdown ? MarkdownParser(data) : null;
    final dropCapStr = (mdData?.plainText ?? data).substring(0, dropCapChars);

    // Use provided TextSpan or build one from data
    final TextSpan mainSpan = textSpan ??
        TextSpan(
          text: parseInlineMarkdown ? null : data.substring(dropCapChars),
          children: parseInlineMarkdown
              ? mdData!.subchars(dropCapChars).toTextSpanList()
              : null,
          style: textStyle.copyWith(
            fontSize: MediaQuery.textScalerOf(context)
                .scale(textStyle.fontSize ?? 14),
          ),
        );

    // For layout calculations, we need plain text length estimation if using TextSpan
    // or just use data length if available.
    // If textSpan is provided, we assume data might be empty.
    // We need 'data' equivalent for length checks.
    String plainTextContent = data;
    if (textSpan != null) {
      final spanText = textSpan!.toPlainText();
      if (spanText.isNotEmpty) {
        plainTextContent = spanText;
      }
    }

    if (mode == DropCapMode.baseline && dropCap == null) {
      return _buildBaseline(context, textStyle, capStyle);
    }

    // custom DropCap
    if (dropCap != null) {
      capWidth = dropCap!.width;
      capHeight = dropCap!.height;
    } else {
      final capPainter = TextPainter(
        text: TextSpan(text: dropCapStr, style: capStyle),
        textDirection: textDirection,
      )..layout();
      capWidth = capPainter.width;
      capHeight = capPainter.height;
      if (forceNoDescent) {
        final ls = capPainter.computeLineMetrics();
        capHeight -= ls.isNotEmpty ? ls[0].descent : capPainter.height * 0.2;
      }
    }

    // compute drop cap padding
    capWidth += dropCapPadding.left + dropCapPadding.right;
    capHeight += dropCapPadding.top + dropCapPadding.bottom;

    // Create a text-only span for layout measurement
    // (TextPainter cannot handle WidgetSpans during layout phase)
    final measurementSpan = TextSpan(
      text: plainTextContent,
      style: mainSpan.style,
    );

    final textPainter = TextPainter(
        textDirection: textDirection,
        text: measurementSpan,
        textAlign: textAlign);
    final lineHeight = textPainter.preferredLineHeight;

    var rows =
        dropCapLines ?? ((capHeight - indentation.dy) / lineHeight).ceil();

    // DROP CAP MODE - UPWARDS
    if (mode == DropCapMode.upwards) {
      rows = 1;
      sideCrossAxisAlignment = CrossAxisAlignment.end;
    }

    // BUILDER
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        var boundsWidth = constraints.maxWidth - capWidth;
        if (boundsWidth < 1) boundsWidth = 1;

        var charIndexEnd = plainTextContent.length;

        //int startMillis = new DateTime.now().millisecondsSinceEpoch;
        if (rows > 0) {
          textPainter.layout(maxWidth: boundsWidth);
          final yPos = rows * lineHeight;
          final charIndex =
              textPainter.getPositionForOffset(Offset(0, yPos)).offset;

          textPainter
            ..maxLines = rows
            ..layout(maxWidth: boundsWidth);
          if (textPainter.didExceedMaxLines) charIndexEnd = charIndex;
        } else {
          charIndexEnd = dropCapChars;
        }
        //int totMillis = new DateTime.now().millisecondsSinceEpoch - startMillis;

        // DROP CAP MODE - LEFT
        if (mode == DropCapMode.aside) charIndexEnd = data.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Text(totMillis.toString() + ' ms'),
            Row(
              textDirection: dropCapPosition == null ||
                      dropCapPosition == DropCapPosition.start
                  ? textDirection
                  : (textDirection == TextDirection.ltr
                      ? TextDirection.rtl
                      : TextDirection.ltr),
              crossAxisAlignment: sideCrossAxisAlignment,
              children: <Widget>[
                if (dropCap != null)
                  Padding(padding: dropCapPadding, child: dropCap)
                else
                  Container(
                    width: capWidth,
                    height: capHeight,
                    padding: dropCapPadding,
                    child: RichText(
                      textDirection: textDirection,
                      textAlign: textAlign,
                      text: TextSpan(text: dropCapStr, style: capStyle),
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.only(top: indentation.dy),
                    width: boundsWidth,
                    // Don't constrain height - let text flow naturally
                    // The remaining text flows below via the Padding section
                    child: RichText(
                      overflow: TextOverflow.clip,
                      maxLines: rows > 0 ? rows : null,
                      textDirection: textDirection,
                      textAlign: textAlign,
                      text: _sliceTextSpan(mainSpan, 0, charIndexEnd) ??
                          const TextSpan(text: ''),
                    ),
                  ),
                ),
              ],
            ),
            if (maxLines == null || maxLines! > rows)
              Padding(
                padding: EdgeInsets.only(left: indentation.dx),
                child: RichText(
                  overflow: overflow,
                  maxLines: maxLines != null && maxLines! > rows
                      ? maxLines! - rows
                      : null,
                  textAlign: textAlign,
                  textDirection: textDirection,
                  text: _sliceTextSpan(mainSpan, charIndexEnd) ??
                      TextSpan(text: ''),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBaseline(
      BuildContext context, TextStyle textStyle, TextStyle capStyle) {
    final mdData = MarkdownParser(data);

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: textStyle,
        children: <TextSpan>[
          TextSpan(
            text: mdData.plainText.substring(0, dropCapChars),
            style: capStyle.merge(const TextStyle(height: 0)),
          ),
          TextSpan(
            children: mdData.subchars(dropCapChars).toTextSpanList(),
            style: textStyle.copyWith(
              fontSize: MediaQuery.textScalerOf(context)
                  .scale(textStyle.fontSize ?? 14),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan? _sliceTextSpan(TextSpan span, int start, [int? end]) {
    if (end != null && start >= end) return null;
    return _DropCapSliceWalker(start, end).slice(span);
  }
}

class _DropCapSliceWalker {
  final int start;
  final int? end;
  final List<InlineSpan> result = [];
  int currentPos = 0;

  _DropCapSliceWalker(this.start, this.end);

  TextSpan? slice(TextSpan root) {
    _visit(root, isRoot: true);
    if (result.isEmpty) return null;
    return TextSpan(style: root.style, children: result);
  }

  void _visit(InlineSpan span, {bool isRoot = false}) {
    if (span is TextSpan) {
      // Process this span's own text
      String? text = span.text;
      if (text != null && text.isNotEmpty) {
        int len = text.length;
        int sStart = currentPos;
        int sEnd = currentPos + len;

        int reqStart = start;
        int reqEnd = end ?? 0x7FFFFFFF;

        int iStart = max(sStart, reqStart);
        int iEnd = min(sEnd, reqEnd);

        if (iStart < iEnd) {
          result.add(TextSpan(
            text: text.substring(iStart - sStart, iEnd - sStart),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
        currentPos += len;
      }

      // Process children if any
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          _visit(child);
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

/// Parser for inline markdown syntax in text.
///
/// Supports parsing of **bold**, _italic_, and ++underline++ markdown
/// syntax within text strings.
class MarkdownParser {
  /// Creates a markdown parser for the given [data] string.
  MarkdownParser(this.data) {
    plainText = '';
    spans = [MarkdownSpan(text: '', markups: [], style: const TextStyle())];

    var bold = false;
    var italic = false;
    var underline = false;

    const markupBold = '**';
    const markupItalic = '_';
    const markupUnderline = '++';

    void addSpan(String markup, {required bool isOpening}) {
      final markups = <Markup>[Markup(markup, isActive: isOpening)];

      if (bold && markup != markupBold) {
        markups.add(Markup(markupBold, isActive: true));
      }
      if (italic && markup != markupItalic) {
        markups.add(Markup(markupItalic, isActive: true));
      }
      if (underline && markup != markupUnderline) {
        markups.add(Markup(markupUnderline, isActive: true));
      }

      spans.add(
        MarkdownSpan(
          text: '',
          markups: markups,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : null,
            fontStyle: italic ? FontStyle.italic : null,
            decoration: underline ? TextDecoration.underline : null,
          ),
        ),
      );
    }

    bool checkMarkup(int i, String markup) {
      return data.substring(i, min(i + markup.length, data.length)) == markup;
    }

    for (var c = 0; c < data.length; c++) {
      if (checkMarkup(c, markupBold)) {
        bold = !bold;
        addSpan(markupBold, isOpening: bold);
        c += markupBold.length - 1;
      } else if (checkMarkup(c, markupItalic)) {
        italic = !italic;
        addSpan(markupItalic, isOpening: italic);
        c += markupItalic.length - 1;
      } else if (checkMarkup(c, markupUnderline)) {
        underline = !underline;
        addSpan(markupUnderline, isOpening: underline);
        c += markupUnderline.length - 1;
      } else {
        spans[spans.length - 1].text += data[c];
        plainText += data[c];
      }
    }
  }

  /// The original text data.
  final String data;

  /// The parsed markdown spans.
  late List<MarkdownSpan> spans;

  /// The plain text without markdown syntax.
  String plainText = '';

  /// Converts the parsed markdown spans to a list of [TextSpan] widgets.
  List<TextSpan> toTextSpanList() {
    return spans.map((s) => s.toTextSpan()).toList();
  }

  /// Creates a new [MarkdownParser] with a substring of the original data.
  ///
  /// The [startIndex] parameter specifies where to start the substring.
  /// The optional [endIndex] parameter specifies where to end the substring.
  MarkdownParser subchars(int startIndex, [int? endIndex]) {
    final subspans = <MarkdownSpan>[];
    var skip = startIndex;
    for (var s = 0; s < spans.length; s++) {
      final span = spans[s];
      if (skip <= 0) {
        subspans.add(span);
      } else if (span.text.length < skip) {
        skip -= span.text.length;
      } else {
        subspans.add(
          MarkdownSpan(
              style: span.style,
              markups: span.markups,
              text: span.text.substring(skip, span.text.length)),
        );
        skip = 0;
      }
    }

    return MarkdownParser(
      subspans
          .asMap()
          .map((int index, MarkdownSpan span) {
            final markup = index > 0
                ? (span.markups.isNotEmpty ? span.markups[0].code : '')
                : span.markups.map((m) => m.isActive ? m.code : '').join();
            return MapEntry(index, '$markup${span.text}');
          })
          .values
          .toList()
          .join(),
    );
  }
}

/// Represents a span of text with associated markdown styling.
class MarkdownSpan {
  /// Creates a markdown span with the given [text], [style], and [markups].
  MarkdownSpan(
      {required this.text, required this.style, required this.markups});

  /// The text style for this span.
  final TextStyle style;

  /// The list of markdown markups applied to this span.
  final List<Markup> markups;

  /// The text content of this span.
  String text;

  /// Converts this markdown span to a [TextSpan] widget.
  TextSpan toTextSpan() => TextSpan(text: text, style: style);
}

/// Represents a markdown markup element (e.g., **, _, ++).
class Markup {
  /// Creates a markup with the given [code] and [isActive] state.
  Markup(this.code, {required this.isActive});

  /// The markup code (e.g., '**', '_', '++').
  final String code;

  /// Whether this markup is currently active (opening) or not (closing).
  final bool isActive;
}
