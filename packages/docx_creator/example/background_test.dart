import 'package:docx_creator/docx_creator.dart';

void main() async {
  print('Creating document with background color...');

  final doc = docx()
      .section(
        backgroundColor: DocxColor('E3F2FD'), // Light blue
        header: DocxHeader.styled(
          'CONFIDENTIAL',
          color: DocxColor.blue,
          bold: true,
        ),
        footer: DocxFooter.pageNumbers(),
      )
      .h1('Document with Background')
      .p('This document has a light blue background color.')
      .p('')
      .h2('Features')
      .bullet([
        'Page background color support',
        'Custom hex colors via DocxColor class',
        'Works with headers and footers',
      ])
      .p('')
      .table([
        ['Feature', 'Status'],
        ['Background Color', '✓ Implemented'],
        ['Custom Hex', '✓ Working'],
      ], style: DocxTableStyle.zebra)
      .build();

  await DocxExporter().exportToFile(doc, 'background_test.docx');
  print('Created background_test.docx');
}
