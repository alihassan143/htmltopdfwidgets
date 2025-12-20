import 'package:docx_creator/docx_creator.dart';

void main() async {
  final doc = docx()
      .h1('Test Lists')
      .p('Bullet list:')
      .bullet(['Item 1', 'Item 2', 'Item 3'])
      .p('Numbered list:')
      .numbered(['Step 1', 'Step 2', 'Step 3'])
      .build();

  print('Elements: ${doc.elements.length}');
  for (var e in doc.elements) {
    if (e is DocxList) {
      print(
        'List: ordered=${e.isOrdered}, numId=${e.numId}, items=${e.items.length}',
      );
    }
  }

  await DocxExporter().exportToFile(doc, 'test_list.docx');
  print('Created test_list.docx');
}
