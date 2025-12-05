import 'dart:convert';
import 'dart:io';

import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  // Create a dummy 1x1 red pixel png
  final redPixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
  final redPixelBase64 =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  setUp(() async {
    await File('test_image.png').writeAsBytes(redPixel);
  });

  tearDown(() async {
    if (await File('test_image.png').exists()) {
      await File('test_image.png').delete();
    }
  });

  final html = '''
    <h1>Image Test</h1>
    <p>Network Image:</p>
    <img src="https://via.placeholder.com/150" width="100" height="100" />
    <p>Base64 Image:</p>
    <img src="$redPixelBase64" width="50" height="50" />
    <p>Local File Image:</p>
    <img src="test_image.png" width="50" height="50" />
  ''';

  test('Image Support Test - New Browser Engine', () async {
    final widgets = await HTMLToPdf().convert(html, useNewEngine: true);
    expect(widgets, isNotEmpty);

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (c) => widgets));
    final bytes = await pdf.save();
    expect(bytes.length, greaterThan(0));

    final file = File('test_output_images.pdf');
    await file.writeAsBytes(bytes);
  });
}
