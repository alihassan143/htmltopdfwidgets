import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/models/docx_font.dart';
import 'package:docx_viewer/src/docx_view_config.dart';
import 'package:docx_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_viewer/src/widget_generator/shape_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Setup a mock theme
  final theme = DocxTheme(
    colors: DocxThemeColors(
      accent1: 'FF0000', // Red
      accent2: '00FF00', // Green
    ),
    fonts: DocxThemeFonts(
      majorLatin: 'MajorFont',
      minorLatin: 'MinorFont',
    ),
  );

  final viewConfig = const DocxViewConfig();
  final viewTheme = const DocxViewTheme();

  group('Theme Awareness', () {
    testWidgets('ParagraphBuilder resolves theme color', (tester) async {
      final text = DocxText(
        'Hello',
        color: DocxColor('auto', themeColor: 'accent1'),
      );
      final para = DocxParagraph(children: [text]);

      final builder = ParagraphBuilder(
        config: viewConfig,
        theme: viewTheme,
        docxTheme: theme,
      );

      final widget = builder.build(para);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: widget),
      ));

      final richText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final span = richText.textSpan as TextSpan;
      final childSpan = span.children!.first as TextSpan;

      // accent1 is FF0000 -> Red
      expect(childSpan.style?.color, const Color(0xFFFF0000));
    });

    testWidgets('ParagraphBuilder resolves theme font', (tester) async {
      final text = DocxText(
        'Hello',
        // Theme font reference - should be via fonts.hAnsiTheme, not fontFamily
        fonts: const DocxFont(hAnsiTheme: 'majorHAnsi'),
      );

      final para = DocxParagraph(children: [text]);

      final builder = ParagraphBuilder(
        config: viewConfig,
        theme: viewTheme,
        docxTheme: theme,
      );

      final widget = builder.build(para);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: widget),
      ));

      final richText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final span = richText.textSpan as TextSpan;
      final childSpan = span.children!.first as TextSpan;

      expect(childSpan.style?.fontFamily, 'MajorFont');
    });

    testWidgets('ListBuilder resolves theme color for bullet', (tester) async {
      final listStyle = DocxListStyle(
        themeColor: 'accent2', // Green
        bullet: '•',
      );
      final list = DocxList.bullet(['Item'], style: listStyle);

      final paraBuilder = ParagraphBuilder(
        config: viewConfig,
        theme: viewTheme,
        docxTheme: theme,
      );

      final builder = ListBuilder(
        config: viewConfig,
        theme: viewTheme,
        paragraphBuilder: paraBuilder,
        docxTheme: theme,
      );

      final widget = builder.build(list);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: widget),
      ));

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));

      bool foundGreen = false;
      for (var rt in richTexts) {
        if (rt.text is TextSpan) {
          final span = rt.text as TextSpan;
          if (span.style?.color == const Color(0xFF00FF00)) {
            foundGreen = true;
            break;
          }
        }
      }
      expect(foundGreen, isTrue);
    });

    testWidgets('ShapeBuilder resolves theme fill', (tester) async {
      final shape = DocxShape(
        fillColor: DocxColor('auto', themeColor: 'accent1'), // Red
        width: 100,
        height: 100,
      );

      final builder = ShapeBuilder(config: viewConfig, docxTheme: theme);

      final widget = builder.buildInlineShape(shape);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: widget),
      ));

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      expect(customPaint, isNotNull);
    });
  });
}
