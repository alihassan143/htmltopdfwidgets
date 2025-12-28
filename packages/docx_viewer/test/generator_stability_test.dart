import 'package:docx_creator/docx_creator.dart';
import 'package:docx_viewer/src/docx_view_config.dart';
import 'package:docx_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DocxWidgetGenerator initializes and generates widgets without error',
      () {
    final config = const DocxViewConfig();
    final generator = DocxWidgetGenerator(config: config);

    final doc = DocxBuiltDocument(
        elements: [],
        footnotes: [],
        endnotes: [],
        theme: DocxTheme(colors: DocxThemeColors(), fonts: DocxThemeFonts()));

    // First call
    generator.generateWidgets(doc);

    // Second call (should not crash with LateInitializationError)
    generator.generateWidgets(doc);
  });
}
