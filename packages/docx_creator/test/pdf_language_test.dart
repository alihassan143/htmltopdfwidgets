import 'dart:io';

import 'package:docx_creator/src/exporters/pdf/pdf_document_writer.dart';
import 'package:docx_creator/src/exporters/pdf/pdf_font_manager.dart';
import 'package:test/test.dart';

void main() {
  group('PdfLanguageTest', () {
    test('escapeTextHex maps characters to GIDs using DroidSansFallback',
        () async {
      final fontManager = PdfFontManager();

      // Load real font
      final fontPath =
          '/Users/mac/Desktop/htmltopdfwidgets/packages/htmltopdf_syncfusion/assets/fonts/DroidSansFallback.ttf';
      final fontData = await File(fontPath).readAsBytes();

      // Register it
      fontManager.registerFont('DroidSans', fontData);

      // Select it
      final fontRef = fontManager.selectFont(fontFamily: 'DroidSans');
      expect(fontManager.getEmbeddedFont(fontRef), isNotNull);

      // Test Chinese Text "你好" (Hello)
      // Unicode: 4F60 597D
      const text = '你好';
      final hex = fontManager.escapeTextHex(text, fontRef);

      print('Hex for "你好": $hex');
      expect(hex, isNotEmpty);
      expect(hex.length, equals(4 * text.length)); // 4 chars per GID (2 bytes)
      // Verify it's all hex
      expect(RegExp(r'^[0-9A-F]+$').hasMatch(hex), isTrue);
    });

    test('writeFonts returns correct structure', () async {
      final fontManager = PdfFontManager();
      final fontPath =
          '/Users/mac/Desktop/htmltopdfwidgets/packages/htmltopdf_syncfusion/assets/fonts/DroidSansFallback.ttf';
      final fontData = await File(fontPath).readAsBytes();
      fontManager.registerFont('DroidSans', fontData);

      final writer = PdfDocumentWriter();
      final fonts = fontManager.writeFonts(writer);

      expect(fonts, isNotEmpty);
      // Check that we have a font ref key
      final fontRef = fontManager.selectFont(fontFamily: 'DroidSans');
      expect(fonts.containsKey(fontRef), isTrue);
    });
  });
}
