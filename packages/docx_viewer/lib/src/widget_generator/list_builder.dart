import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxList] elements.
class ListBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;

  /// Bullet characters for different indent levels.
  static const _bulletChars = ['•', '◦', '▪', '▸', '◦', '▪', '▸', '◦', '▪'];

  ListBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
  });

  /// Build a widget from a [DocxList].
  Widget build(DocxList list) {
    final itemWidgets = <Widget>[];
    int numbering = 1;

    for (final item in list.items) {
      final widget = _buildListItem(
        item,
        isOrdered: list.isOrdered,
        number: numbering,
      );
      itemWidgets.add(widget);

      if (item.level == 0) numbering++;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemWidgets,
      ),
    );
  }

  Widget _buildListItem(DocxListItem item, {required bool isOrdered, required int number}) {
    final level = item.level.clamp(0, 8);
    final indent = 24.0 + (level * 24.0);

    // Build marker
    String marker;
    if (isOrdered) {
      // For ordered lists, use numbers with level-based formatting
      marker = _getOrderedMarker(number, level);
    } else {
      // For unordered lists, use bullet characters based on level
      marker = _bulletChars[level];
    }

    // Build content from inline children
    final textSpans = <InlineSpan>[];
    for (final child in item.children) {
      if (child is DocxText) {
        textSpans.add(TextSpan(
          text: child.content,
          style: _buildTextStyle(child),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: TextStyle(
                color: theme.bulletColor,
                fontSize: theme.defaultTextStyle.fontSize,
              ),
            ),
          ),
          Expanded(
            child: config.enableSelection
                ? SelectableText.rich(TextSpan(children: textSpans))
                : RichText(text: TextSpan(children: textSpans)),
          ),
        ],
      ),
    );
  }

  String _getOrderedMarker(int number, int level) {
    switch (level % 3) {
      case 0:
        return '$number.';
      case 1:
        return '${_toLowerAlpha(number)}.';
      case 2:
        return '${_toRoman(number).toLowerCase()}.';
      default:
        return '$number.';
    }
  }

  String _toLowerAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 97; // 'a' = 97
    return String.fromCharCode(code);
  }

  String _toRoman(int n) {
    if (n <= 0 || n > 3999) return n.toString();
    const romanNumerals = [
      ['M', 1000], ['CM', 900], ['D', 500], ['CD', 400],
      ['C', 100], ['XC', 90], ['L', 50], ['XL', 40],
      ['X', 10], ['IX', 9], ['V', 5], ['IV', 4], ['I', 1],
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

  TextStyle _buildTextStyle(DocxText text) {
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

    return TextStyle(
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: textColor ?? theme.defaultTextStyle.color,
      fontSize: text.fontSize ?? theme.defaultTextStyle.fontSize,
      fontFamily: text.fontFamily,
      fontFamilyFallback: config.customFontFallbacks,
    );
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return Colors.black;
  }
}
