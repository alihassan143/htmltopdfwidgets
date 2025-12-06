import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:htmltopdfwidgets_syncfusion/htmltopdfwidgets_syncfusion.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Basic HTML conversion', () async {
    final pdf = PdfDocument();
    const html = '''
      <h1>Hello World</h1>
      <p>This is a paragraph with <b>bold</b> and <i>italic</i> text.</p>
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
      <table border="1">
        <tr>
          <td>Cell 1</td><td>Cell 2</td>
        </tr>
      </table>
    ''';

    final converter = HtmlToPdf();
    await converter.convert(html, targetDocument: pdf);

    final bytes = await pdf.save();
    pdf.dispose();

    final file = File('test_output.pdf');
    await file.writeAsBytes(bytes);

    expect(bytes.isNotEmpty, true);
    print('PDF saved to ${file.absolute.path}');
  });
}
