import 'dart:io';

import 'package:archive/archive.dart';

void main() async {
  final file = File('../docx_creator/demo.docx');
  final bytes = await file.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  final documentXml = archive.findFile('word/document.xml');
  if (documentXml != null) {
    print('--- document.xml content ---');
    final content = String.fromCharCodes(documentXml.content as List<int>);

    final tags = [
      'w:tbl',
      'w:drawing',
      'w:gridSpan',
      'w:vMerge',
      'w:shd',
      'wsp:wsp'
    ];
    for (final tag in tags) {
      final index = content.indexOf(tag);
      if (index != -1) {
        final start = index - 100 < 0 ? 0 : index - 100;
        final end = index + 500 > content.length ? content.length : index + 500;
        print('\nFound $tag at $index:');
        print(content.substring(start, end));
      } else {
        print('\n$tag NOT FOUND');
      }
    }
  } else {
    print('word/document.xml not found');
  }
}
