import 'package:docx_creator/docx_creator.dart';

/// Debug sample to inspect what's being read from the document
void main() async {
  print('Reading original.docx...');
  final doc = await DocxReader.load('example/output/original.docx');

  print('\nElements in document: ${doc.elements.length}');

  for (var i = 0; i < doc.elements.length; i++) {
    final element = doc.elements[i];
    print('\n[$i] ${element.runtimeType}');

    if (element is DocxParagraph) {
      print('  styleId: ${element.styleId}');
      print('  align: ${element.align}');
      print('  children count: ${element.children.length}');
      for (var j = 0; j < element.children.length; j++) {
        final child = element.children[j];
        if (child is DocxText) {
          print('    [$j] DocxText: "${child.content}"');
          print('        fontWeight: ${child.fontWeight}');
          print('        fontStyle: ${child.fontStyle}');
          print('        fontSize: ${child.fontSize}');
          print('        decoration: ${child.decoration}');
        } else {
          print('    [$j] ${child.runtimeType}');
        }
      }
    } else if (element is DocxTable) {
      print('  rows: ${element.rows.length}');
      print('  style: ${element.style}');
    }
  }
}
