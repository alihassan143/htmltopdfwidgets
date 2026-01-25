import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_pdf_engine/native_pdf_engine.dart';
import 'package:path/path.dart' as path;

// Use IntegrationTestWidgetsFlutterBinding to initialize the Flutter engine
// which ensures platform channels and FFI plugins are properly registered/loaded.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('generate pdf from html to file', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
    final outputPath = path.join(tempDir.path, 'test_output.pdf');
    final htmlContent =
        '<h1>Hello Integration</h1><p>Running in valid context.</p>';

    try {
      await NativePdf.convert(htmlContent, outputPath);

      final file = File(outputPath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  });

  testWidgets('generate pdf from html to data', (WidgetTester tester) async {
    final htmlContent = '<h1>Hello Data Integration</h1><p>Bytes.</p>';

    final bytes = await NativePdf.convertToData(htmlContent);

    expect(bytes, isNotNull);
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
  });

  // URL test (might be skipped if no network, but good for local)
  testWidgets('generate pdf from url (data uri) to data', (
    WidgetTester tester,
  ) async {
    final dataUri = Uri.dataFromString(
      '<h1>Hello URL Integration</h1>',
      mimeType: 'text/html',
    ).toString();

    final bytes = await NativePdf.convertUrlToData(dataUri);

    expect(bytes, isNotNull);
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
  });
}
