import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// List styling configuration.
///
/// ```dart
/// DocxList.bullet(items, style: DocxListStyle.circle)
/// DocxList.numbered(items, style: DocxListStyle.roman)
/// ```
class DocxListStyle {
  /// Bullet character (for unordered lists).
  final String bullet;

  /// Number format (for ordered lists).
  final DocxNumberFormat numberFormat;

  /// Indentation per level in twips.
  final int indentPerLevel;

  /// Hanging indent in twips.
  final int hangingIndent;

  /// Text style for list items.
  final DocxFontWeight fontWeight;
  final DocxColor color;
  final double? fontSize;

  /// Custom image bullet bytes (png/jpg).
  ///
  /// If provided, this overrides [bullet] and [numberFormat].
  final Uint8List? imageBulletBytes;

  const DocxListStyle({
    this.bullet = '•',
    this.numberFormat = DocxNumberFormat.decimal,
    this.indentPerLevel = 720,
    this.hangingIndent = 360,
    this.fontWeight = DocxFontWeight.normal,
    this.color = DocxColor.black,
    this.fontSize,
    this.imageBulletBytes,
  });

  /// Solid disc bullet (default)
  static const disc = DocxListStyle(bullet: '•');

  /// Circle bullet
  static const circle = DocxListStyle(bullet: '◦');

  /// Square bullet
  static const square = DocxListStyle(bullet: '▪');

  /// Dash bullet
  static const dash = DocxListStyle(bullet: '-');

  /// Arrow bullet
  static const arrow = DocxListStyle(bullet: '→');

  /// Checkmark bullet
  static const check = DocxListStyle(bullet: '✓');

  /// Decimal numbers (1, 2, 3)
  static const decimal = DocxListStyle(numberFormat: DocxNumberFormat.decimal);

  /// Lowercase letters (a, b, c)
  static const lowerAlpha = DocxListStyle(
    numberFormat: DocxNumberFormat.lowerAlpha,
  );

  /// Uppercase letters (A, B, C)
  static const upperAlpha = DocxListStyle(
    numberFormat: DocxNumberFormat.upperAlpha,
  );

  /// Lowercase roman (i, ii, iii)
  static const lowerRoman = DocxListStyle(
    numberFormat: DocxNumberFormat.lowerRoman,
  );

  /// Uppercase roman (I, II, III)
  static const upperRoman = DocxListStyle(
    numberFormat: DocxNumberFormat.upperRoman,
  );
}

/// Number format for ordered lists.
enum DocxNumberFormat {
  decimal, // 1, 2, 3
  lowerAlpha, // a, b, c
  upperAlpha, // A, B, C
  lowerRoman, // i, ii, iii
  upperRoman, // I, II, III
  bullet, // Unordered
}

/// A list element (bulleted or numbered).
///
/// ## Bulleted List
/// ```dart
/// DocxList.bullet(['First', 'Second', 'Third'])
/// DocxList.bullet(items, style: DocxListStyle.circle)
/// ```
///
/// ## Numbered List
/// ```dart
/// DocxList.numbered(['Step 1', 'Step 2'])
/// DocxList.numbered(items, style: DocxListStyle.roman)
/// ```
///
/// ## Custom Items
/// ```dart
/// DocxList(
///   items: [
///     DocxListItem([DocxText.bold('Bold item')]),
///     DocxListItem([DocxText('Normal item')]),
///   ],
/// )
/// ```
class DocxList extends DocxBlock {
  final List<DocxListItem> items;
  final bool isOrdered;
  final DocxListStyle style;

  int? numId;

  DocxList({
    required this.items,
    this.isOrdered = false,
    this.style = const DocxListStyle(),
    super.id,
  });

  /// Creates a bulleted list.
  factory DocxList.bullet(
    List<String> texts, {
    DocxListStyle style = const DocxListStyle(),
  }) {
    return DocxList(
      isOrdered: false,
      style: style,
      items: texts.map((t) => DocxListItem.text(t)).toList(),
    );
  }

  /// Creates a numbered list.
  factory DocxList.numbered(
    List<String> texts, {
    DocxListStyle style = const DocxListStyle(),
  }) {
    return DocxList(
      isOrdered: true,
      style: style,
      items: texts.map((t) => DocxListItem.text(t)).toList(),
    );
  }

  /// Creates from list items with rich content.
  factory DocxList.items(
    List<DocxListItem> items, {
    bool ordered = false,
    DocxListStyle style = const DocxListStyle(),
  }) {
    return DocxList(items: items, isOrdered: ordered, style: style);
  }

  DocxList copyWith({
    List<DocxListItem>? items,
    bool? isOrdered,
    DocxListStyle? style,
    int? numId,
  }) {
    final list = DocxList(
      items: items ?? this.items,
      isOrdered: isOrdered ?? this.isOrdered,
      style: style ?? this.style,
      id: id,
    );
    list.numId = numId ?? this.numId;
    return list;
  }

  @override
  void accept(DocxVisitor visitor) {}

  @override
  void buildXml(XmlBuilder builder) {
    for (var item in items) {
      item.buildXmlWithStyle(builder, numId ?? 1, style, isOrdered);
    }
  }
}

/// A single item in a list.
class DocxListItem extends DocxNode {
  final List<DocxInline> children;
  final int level;

  const DocxListItem(this.children, {this.level = 0, super.id});

  factory DocxListItem.text(String text, {int level = 0}) {
    return DocxListItem([DocxText(text)], level: level);
  }

  factory DocxListItem.rich(List<DocxInline> content, {int level = 0}) {
    return DocxListItem(content, level: level);
  }

  DocxListItem copyWith({
    List<DocxInline>? children,
    int? level,
  }) {
    return DocxListItem(
      children ?? this.children,
      level: level ?? this.level,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {}

  @override
  void buildXml(XmlBuilder builder) {
    buildXmlWithStyle(builder, 1, const DocxListStyle(), false);
  }

  void buildXmlWithStyle(
    XmlBuilder builder,
    int numId,
    DocxListStyle style,
    bool isOrdered,
  ) {
    builder.element(
      'w:p',
      nest: () {
        builder.element(
          'w:pPr',
          nest: () {
            builder.element(
              'w:numPr',
              nest: () {
                builder.element(
                  'w:ilvl',
                  nest: () {
                    builder.attribute('w:val', level.toString());
                  },
                );
                builder.element(
                  'w:numId',
                  nest: () {
                    builder.attribute('w:val', numId.toString());
                  },
                );
              },
            );
          },
        );
        for (var child in children) {
          child.buildXml(builder);
        }
      },
    );
  }
}
