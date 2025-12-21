import 'dart:io';

import 'package:docx_creator/docx_creator.dart';

void main() async {
  print('Inspecting demo.docx structure...');
  final file = File('../docx_creator/demo.docx');
  if (!await file.exists()) {
    print('demo.docx not found at ${file.absolute.path}');
    return;
  }

  final bytes = await file.readAsBytes();
  final doc = await DocxReader.loadFromBytes(bytes);

  print('Document loaded successfully.');
  if (doc.section == null) {
    print('Warning: No section found.');
  } else {
    print(
        'Sections: Orientation=${doc.section!.orientation}, Size=${doc.section!.pageSize}');
    if (doc.section!.header != null) print('Header found');
    if (doc.section!.footer != null) print('Footer found');
    if (doc.section!.backgroundImage != null) print('Background Image found');
  }

  print('\n--- Elements ---');
  _printElements(doc.elements, 0);
}

void _printElements(List<DocxNode> elements, int indent) {
  final prefix = '  ' * indent;
  for (final element in elements) {
    if (element is DocxParagraph) {
      print(
          '$prefix[Paragraph] aligned=${element.align}, shading=${element.shadingFill}');
      if (element.children.isNotEmpty) {
        _printElements(element.children, indent + 1);
      }
    } else if (element is DocxText) {
      print(
          '$prefix[Text] "${element.content.replaceAll('\n', '\\n')}" color=${element.color?.hex} shading=${element.shadingFill} border=${element.isOutline}');
    } else if (element is DocxTable) {
      print('$prefix[Table] rows=${element.rows.length}');
      for (var row in element.rows) {
        print('$prefix  [Row] cells=${row.cells.length}');
        for (var cell in row.cells) {
          print(
              '$prefix    [Cell] colSpan=${cell.colSpan} rowSpan=${cell.rowSpan} shading=${cell.shadingFill}');
          _printElements(cell.children, indent + 3);
        }
      }
    } else if (element is DocxShape) {
      print(
          '$prefix[Shape] preset=${element.preset} fill=${element.fillColor?.hex} outline=${element.outlineColor?.hex} text="${element.text}"');
    } else if (element is DocxInlineImage) {
      print(
          '$prefix[Image] ${element.extension} ${element.width}x${element.height}');
    } else if (element is DocxList) {
      print('$prefix[List] style=${element.style}');
      for (var item in element.items) {
        print('$prefix  [ListItem] level=${item.level}');
        _printElements(item.children, indent + 2);
      }
    } else {
      print('$prefix[${element.runtimeType}]');
    }
  }
}
