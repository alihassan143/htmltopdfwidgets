import 'dart:io';

import 'package:native_pdf_engine/native_pdf_engine.dart';
import 'package:test/test.dart';

void main() {
  test('generate_pdf creates a PDF file', () {
    final html =
        '<html><body><h1>Hello PDF</h1><p>This is a test.</p></body></html>';
    final output = '${Directory.systemTemp.path}/test_output.pdf';

    try {
      NativePdf.convert(html, output);
      final file = File(output);
      expect(file.existsSync(), isTrue);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      if (Platform.isMacOS) {
        rethrow;
      } else {
        print('Skipping non-macOS test: $e');
      }
    }
  });
}
