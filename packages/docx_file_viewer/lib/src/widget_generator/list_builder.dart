import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/material.dart';

import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxList] elements.
///
/// Supports [DocxListStyle] and all [DocxNumberFormat] types from docx_creator.
class ListBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final DocxTheme? docxTheme;

  /// Default bullet characters for different indent levels when no style specified.
  static const _defaultBullets = ['•', '◦', '▪', '▸', '◦', '▪', '▸', '◦', '▪'];

  ListBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    this.docxTheme,
  });

  /// Build a widget from a [DocxList].
  Widget build(DocxList list, {BlockIndexCounter? counter}) {
    final itemWidgets = <Widget>[];

    // Track numbering per level for nested lists
    final numberingByLevel = <int, int>{};

    for (final item in list.items) {
      final level = item.level;

      // Initialize or increment numbering for this level
      numberingByLevel[level] = (numberingByLevel[level] ?? 0) + 1;

      // Reset numbering for deeper levels when we go back up
      for (var i = level + 1; i <= 8; i++) {
        numberingByLevel.remove(i);
      }

      final widget = _buildListItem(
        item,
        list: list,
        number: numberingByLevel[level]!,
        counter: counter,
      );
      itemWidgets.add(widget);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemWidgets,
      ),
    );
  }

  Widget _buildListItem(
    DocxListItem item, {
    required DocxList list,
    required int number,
    BlockIndexCounter? counter,
  }) {
    final level = item.level.clamp(0, 8);
    // Use override style if available, otherwise fall back to list style
    final style = item.overrideStyle ?? list.style;

    // Calculate indent from list style or default
    final indentPerLevel =
        style.indentPerLevel / 15.0; // Convert twips to pixels
    // Calculate initial indent based on level
    double indent = 16.0 + (level * indentPerLevel.clamp(16.0, 48.0));

    // Apply hanging indent if specified
    if (style.hangingIndent > 0) {
      // Hanging indent shifts the first line (marker) left
      // But in this Row layout, 'indent' is the stored left padding.
      // If we increase stored padding to accommodate hanging, we might just shift marker.
      // Standard logic: Indent Left - Hanging Indent.
      // Here we just accept that 'indent' is the start of content.
    }

    // Build content from all inline children with search support
    List<InlineSpan> spans;
    Key? key;
    if (counter != null && paragraphBuilder.searchController != null) {
      final blockIndex = counter.value;
      final matches = paragraphBuilder.searchController!.matches
          .where((m) => m.blockIndex == blockIndex)
          .toList();

      if (matches.isNotEmpty) {
        key = counter.registerKey(blockIndex);
      }
      counter.increment();

      spans =
          paragraphBuilder.buildInlineSpans(item.children, matches: matches);
    } else {
      spans = paragraphBuilder.buildInlineSpans(item.children);
    }

    // ... (rest of method)

    // Apply style properties from DocxListStyle to the marker

    // Resolve theme color for marker
    final markerColor = _resolveColor(
          style.color.hex,
          style.themeColor,
          style.themeTint,
          style.themeShade,
        ) ??
        _parseHexColor(style.color.hex); // Fallback

    // Resolve theme font for marker
    final markerFont = docxTheme != null && style.themeFont != null
        ? docxTheme!.fonts.getFont(style.themeFont!)
        : null;

    final markerStyle = TextStyle(
      color: markerColor,
      fontSize: style.fontSize != null
          ? style.fontSize! * 1.333
          : theme.defaultTextStyle.fontSize,
      fontWeight: style.fontWeight == DocxFontWeight.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontFamily:
          markerFont ?? style.fontFamily ?? theme.defaultTextStyle.fontFamily,
    );

    // Build marker widget
    Widget markerWidget;
    if (style.imageBulletBytes != null) {
      markerWidget = Image.memory(
        style.imageBulletBytes!,
        width: 12,
        height: 12,
        fit: BoxFit.contain,
      );
    } else {
      String markerText;
      if (list.isOrdered) {
        // For mixed ordered/unordered in one list, this is simplified.
        // Ideally isOrdered should be per level too if complex.
        // But typically the whole list block shares order type or splits.
        // If overrideStyle provides numberFormat.bullet, we should treat as unordered bullet.
        if (style.numberFormat == DocxNumberFormat.bullet) {
          markerText = _getBulletMarker(level, style);
        } else {
          markerText = _getOrderedMarker(number, level, style.numberFormat);
        }
      } else {
        markerText = _getBulletMarker(level, style);
      }
      markerWidget = Text(markerText, style: markerStyle);
    }

    return Padding(
      key: key,
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: markerWidget,
          ),
          Expanded(
            child: config.enableSelection
                ? SelectableText.rich(TextSpan(children: spans))
                : RichText(text: TextSpan(children: spans)),
          ),
        ],
      ),
    );
  }

  /// Get bullet marker based on level and style.
  String _getBulletMarker(int level, DocxListStyle style) {
    // If style has a custom bullet, use it
    if (style.bullet.isNotEmpty && style.bullet != '•') {
      return style.bullet;
    }
    // Otherwise use level-based default bullets
    return _defaultBullets[level];
  }

  /// Get ordered marker based on number format.
  String _getOrderedMarker(int number, int level, DocxNumberFormat format) {
    switch (format) {
      case DocxNumberFormat.decimal:
        return '$number.';
      case DocxNumberFormat.lowerAlpha:
        return '${_toLowerAlpha(number)}.';
      case DocxNumberFormat.upperAlpha:
        return '${_toUpperAlpha(number)}.';
      case DocxNumberFormat.lowerRoman:
        return '${_toRoman(number).toLowerCase()}.';
      case DocxNumberFormat.upperRoman:
        return '${_toRoman(number)}.';
      case DocxNumberFormat.bullet:
        return _defaultBullets[level];
    }
  }

  String _toLowerAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 97; // 'a' = 97
    return String.fromCharCode(code);
  }

  String _toUpperAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 65; // 'A' = 65
    return String.fromCharCode(code);
  }

  String _toRoman(int n) {
    if (n <= 0 || n > 3999) return n.toString();
    const romanNumerals = [
      ['M', 1000],
      ['CM', 900],
      ['D', 500],
      ['CD', 400],
      ['C', 100],
      ['XC', 90],
      ['L', 50],
      ['XL', 40],
      ['X', 10],
      ['IX', 9],
      ['V', 5],
      ['IV', 4],
      ['I', 1],
    ];
    final buffer = StringBuffer();
    int remaining = n;
    for (final entry in romanNumerals) {
      final numeral = entry[0] as String;
      final value = entry[1] as int;
      while (remaining >= value) {
        buffer.write(numeral);
        remaining -= value;
      }
    }
    return buffer.toString();
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
        baseColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        // Shade means darker, mix with black
        final factor = shadeVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - factor), baseColor);
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
    return Colors.black;
  }
}
