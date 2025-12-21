import 'dart:io';

import 'package:docx_creator/docx_creator.dart';

void main() async {
  final file = File('demo.docx');
  if (!file.existsSync()) {
    print('Error: demo.docx not found in current directory');
    return;
  }

  print('Reading demo.docx...');
  final bytes = await file.readAsBytes();
  final doc = await DocxReader.loadFromBytes(bytes);

  await DocxExporter().exportToFile(doc, 'new.docx');
  print('Successfully loaded document.');
  print('Section Page Size: ${doc.section?.pageSize}');
  print('Section Orientation: ${doc.section?.orientation}');
  print(
      'Margins: top=${doc.section?.marginTop}, right=${doc.section?.marginRight}, bottom=${doc.section?.marginBottom}, left=${doc.section?.marginLeft}');

  print('\n--- Document Elements ---');
  _printElements(doc.elements, 0);

  print('\n--- Detailed Alignment & Constraints Check ---');
  _checkSpecificFeatures(doc.elements);
}

void _printElements(List<DocxNode> elements, int indentLevel) {
  final indent = '  ' * indentLevel;

  for (var element in elements) {
    if (element is DocxParagraph) {
      print('$indent[P] Style: ${element.styleId ?? "Normal"}');
      // Print children (runs, images, etc.)
      for (var child in element.children) {
        if (child is DocxText) {
          String info = '"${child.content}"';
          if (child.isBold) info += ' [BOLD]';
          if (child.isItalic) info += ' [ITALIC]';
          if (child.fontSize != null) info += ' Size:${child.fontSize}';
          if (child.color != null) info += ' Color:${child.color!.hex}';
          if (child.textBorder != null) info += ' [BORDERED]';

          print('$indent  - Text: $info');
        } else if (child is DocxInlineImage) {
          String imgInfo =
              'Image (Inline): ${child.width}x${child.height}, ext: ${child.extension}';
          if (child.altText != null) imgInfo += ', alt: ${child.altText}';
          if (child.positionMode == DocxDrawingPosition.floating) {
            imgInfo +=
                ' [FLOATING] x:${child.x} y:${child.y} wrap:${child.textWrap.name} relH:${child.hPositionFrom.name} relV:${child.vPositionFrom.name}';
            if (child.hAlign != null)
              imgInfo += ' hAlign:${child.hAlign!.name}';
            if (child.vAlign != null)
              imgInfo += ' vAlign:${child.vAlign!.name}';
          }
          print('$indent  - $imgInfo');
        } else if (child is DocxFootnoteRef) {
          print('$indent  - FootnoteRef: ID=${child.footnoteId}');
        } else if (child is DocxEndnoteRef) {
          print('$indent  - EndnoteRef: ID=${child.endnoteId}');
        } else {
          print('$indent  - ${child.runtimeType}');
        }
      }
    } else if (element is DocxTable) {
      String alignInfo = element.alignment?.name ?? 'none';
      String posInfo = element.position != null
          ? 'Floating (hAnchor: ${element.position!.hAnchor.name}, vAnchor: ${element.position!.vAnchor.name}, x: ${element.position!.tblpX}, y: ${element.position!.tblpY})'
          : 'Inline';
      String styleInfo =
          element.styleId != null ? ', Style: ${element.styleId}' : '';

      print(
          '$indent[TABLE] Align: $alignInfo, Pos: $posInfo, Width: ${element.width} (${element.widthType.name})$styleInfo');

      for (var i = 0; i < element.rows.length; i++) {
        final row = element.rows[i];
        print('$indent  Row $i ${row.isHeader ? "[HEADER]" : ""}');
        for (var j = 0; j < row.cells.length; j++) {
          final cell = row.cells[j];
          String cellInfo = 'Cell $j';
          if (cell.shadingFill != null) cellInfo += ' Fill:${cell.shadingFill}';
          cellInfo += ' VAlign:${cell.verticalAlign.name}';
          print('$indent    $cellInfo');
          _printElements(cell.children, indentLevel + 3);
        }
      }
    } else if (element is DocxDropCap) {
      print(
          '$indent[DROPCAP] Letter: "${element.letter}", Lines: ${element.lines}, Style: ${element.style.name}');
      // Print rest of paragraph
      // Usually restOfParagraph contains DocxText or other inline elements, but basic text printing:
      var restText = element.restOfParagraph
          .map((e) => e is DocxText ? e.content : '?')
          .join('');
      print('$indent  Rest: "$restText"');
    } else if (element is DocxSectionBreakBlock) {
      print('$indent[SECTION BREAK]');
    } else {
      print('$indent[UNKOWN] ${element.runtimeType}');
    }
  }
}

void _checkSpecificFeatures(List<DocxNode> elements) {
  int tablesCount = 0;
  int dropCapsCount = 0;
  int footnotesCount = 0;
  int bordersCount = 0;
  int floatingTablesCount = 0;

  void traverse(List<DocxNode> nodes) {
    for (var node in nodes) {
      if (node is DocxTable) {
        tablesCount++;
        if (node.position != null) floatingTablesCount++;

        for (var row in node.rows) {
          for (var cell in row.cells) {
            traverse(cell.children);
          }
        }
      } else if (node is DocxDropCap) {
        dropCapsCount++;
      } else if (node is DocxParagraph) {
        for (var child in node.children) {
          if (child is DocxFootnoteRef) footnotesCount++;
          if (child is DocxText && child.textBorder != null) bordersCount++;
        }
      }
    }
  }

  traverse(elements);

  print('Summary of detected features:');
  print('- Tables: $tablesCount');
  print('- Floating Tables: $floatingTablesCount');
  print('- Drop Caps: $dropCapsCount');
  print('- Footnote Refs: $footnotesCount');
  print('- Text Borders: $bordersCount');
}
