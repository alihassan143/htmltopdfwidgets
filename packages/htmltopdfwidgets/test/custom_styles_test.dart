import 'dart:io';

import 'package:test/test.dart';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Custom Styles Test - New Engine', () async {
    final html = '''
      <h1>Heading 1 (Should be Red)</h1>
      <p>Paragraph (Should be Blue)</p>
    ''';

    final tagStyle = HtmlTagStyle(
      h1Style: const pw.TextStyle(color: PdfColors.red),
      paragraphStyle: const pw.TextStyle(color: PdfColors.blue),
    );

    final pdf = pw.Document();
    final widgets = await HTMLToPdf().convert(
      html,
      useNewEngine: true,
      tagStyle: tagStyle,
    );

    pdf.addPage(pw.MultiPage(
      build: (context) => widgets,
    ));

    final file = File('test_output_custom_styles.pdf');
    await file.writeAsBytes(await pdf.save());
    print('Generated test_output_custom_styles.pdf');
  });
}
