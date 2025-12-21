/// Comprehensive Manual Document Builder Example
///
/// This example demonstrates ALL features of the docx_creator package
/// using the fluent builder API and manual node construction.
///
/// Run with: dart run example/manual_builder_example.dart
library;

import 'package:docx_creator/docx_creator.dart';

Future<void> main() async {
  print('='.padRight(60, '='));
  print('DocxCreator - Manual Builder Complete Example');
  print('='.padRight(60, '='));

  // ============================================================
  // SECTION 1: Basic Text and Paragraphs
  // ============================================================
  print('\n📝 Section 1: Basic Text and Paragraphs');

  final doc = DocxDocumentBuilder()
      // Headings (H1-H6)
      .h1('Document Title - Heading 1')
      .h2('Chapter One - Heading 2')
      .h3('Section 1.1 - Heading 3')
      .heading(DocxHeadingLevel.h4, 'Subsection 1.1.1 - Heading 4')
      .heading(DocxHeadingLevel.h5, 'Paragraph Group - Heading 5')
      .heading(DocxHeadingLevel.h6, 'Detail Level - Heading 6')

      // Basic paragraphs
      .p('This is a simple paragraph with plain text.')
      .p('Paragraphs can span multiple sentences. Each paragraph '
          'is a separate block element in the document.')

      // ============================================================
      // SECTION 2: Text Formatting
      // ============================================================
      .h2('Text Formatting Options')

      // Bold, Italic, Underline
      .add(DocxParagraph(children: [
        DocxText('Normal text, '),
        DocxText('bold text, ', fontWeight: DocxFontWeight.bold),
        DocxText('italic text, ', fontStyle: DocxFontStyle.italic),
        DocxText('underlined text, ', decoration: DocxTextDecoration.underline),
        DocxText('strikethrough text.',
            decoration: DocxTextDecoration.strikethrough),
      ]))

      // Combined formatting
      .add(DocxParagraph(children: [
        DocxText('Combined: ',
            fontWeight: DocxFontWeight.bold, fontStyle: DocxFontStyle.italic),
        DocxText('bold + italic + underline',
            fontWeight: DocxFontWeight.bold,
            fontStyle: DocxFontStyle.italic,
            decoration: DocxTextDecoration.underline),
      ]))

      // Colors
      .add(DocxParagraph(children: [
        DocxText('Colors: '),
        DocxText('Red ', color: DocxColor.red),
        DocxText('Green ', color: DocxColor.green),
        DocxText('Blue ', color: DocxColor.blue),
        DocxText('Custom #FF6600 ', color: DocxColor('#FF6600')),
        DocxText('DodgerBlue ', color: DocxColor('1E90FF')),
      ]))

      // Background/Shading
      .add(DocxParagraph(children: [
        DocxText('Background colors: '),
        DocxText('Yellow highlight ', shadingFill: 'FFFF00'),
        DocxText('Light gray ', shadingFill: 'D3D3D3', color: DocxColor.black),
        DocxText('Dark with white text ',
            shadingFill: '000000', color: DocxColor.white),
      ]))

      // Font sizes
      .add(DocxParagraph(children: [
        DocxText('Font sizes: '),
        DocxText('8pt ', fontSize: 8),
        DocxText('12pt ', fontSize: 12),
        DocxText('16pt ', fontSize: 16),
        DocxText('24pt ', fontSize: 24),
        DocxText('36pt', fontSize: 36),
      ]))

      // Superscript and Subscript
      .add(DocxParagraph(children: [
        DocxText('Superscript: E=mc'),
        DocxText('2', isSuperscript: true),
        DocxText('  |  Subscript: H'),
        DocxText('2', isSubscript: true),
        DocxText('O'),
      ]))

      // Text effects
      .add(DocxParagraph(children: [
        DocxText('ALL CAPS ', isAllCaps: true),
        DocxText('Small Caps ', isSmallCaps: true),
        DocxText('Double Strike ', isDoubleStrike: true),
        DocxText('Outline ', isOutline: true),
      ]))

      // Highlighting
      .add(DocxParagraph(children: [
        DocxText('Highlights: '),
        DocxText('Yellow ', highlight: DocxHighlight.yellow),
        DocxText('Cyan ', highlight: DocxHighlight.cyan),
        DocxText('Magenta ', highlight: DocxHighlight.magenta),
        DocxText('Green ', highlight: DocxHighlight.green),
      ]))

      // ============================================================
      // SECTION 3: Paragraph Alignment
      // ============================================================
      .h2('Paragraph Alignment')
      .add(DocxParagraph.text('Left aligned (default)', align: DocxAlign.left))
      .add(DocxParagraph.text('Center aligned', align: DocxAlign.center))
      .add(DocxParagraph.text('Right aligned', align: DocxAlign.right))
      .add(DocxParagraph.text(
          'Justified text fills the entire line width by adjusting spacing between words. '
          'This is commonly used in books and formal documents.',
          align: DocxAlign.justify))

      // ============================================================
      // SECTION 4: Lists
      // ============================================================
      .h2('Lists')

      // Bullet list
      .h3('Bullet List')
      .bullet([
        'First bullet item',
        'Second bullet item',
        'Third bullet item with longer text that may wrap to the next line',
      ])

      // Numbered list
      .h3('Numbered List')
      .numbered([
        'First numbered item',
        'Second numbered item',
        'Third numbered item',
      ])

      // Nested list (manual construction)
      .h3('Nested List')
      .add(DocxList(
        style: DocxListStyle.disc,
        items: [
          DocxListItem.text('Level 0 - First', level: 0),
          DocxListItem.text('Level 1 - Nested', level: 1),
          DocxListItem.text('Level 2 - Deep nested', level: 2),
          DocxListItem.text('Level 1 - Back', level: 1),
          DocxListItem.text('Level 0 - Root', level: 0),
        ],
      ))

      // ============================================================
      // SECTION 5: Tables
      // ============================================================
      .h2('Tables')

      // Simple table
      .h3('Simple Table')
      .table([
        ['Header 1', 'Header 2', 'Header 3'],
        ['Row 1 Col 1', 'Row 1 Col 2', 'Row 1 Col 3'],
        ['Row 2 Col 1', 'Row 2 Col 2', 'Row 2 Col 3'],
        ['Row 3 Col 1', 'Row 3 Col 2', 'Row 3 Col 3'],
      ])

      // Styled table (manual construction)
      .h3('Styled Table with Formatting')
      .add(DocxTable(
        rows: [
          DocxTableRow(
            cells: [
              DocxTableCell(
                children: [
                  DocxParagraph(children: [
                    DocxText('Product',
                        fontWeight: DocxFontWeight.bold,
                        color: DocxColor.white),
                  ])
                ],
                shadingFill: '4472C4',
                verticalAlign: DocxVerticalAlign.center,
              ),
              DocxTableCell(
                children: [
                  DocxParagraph(children: [
                    DocxText('Price',
                        fontWeight: DocxFontWeight.bold,
                        color: DocxColor.white),
                  ])
                ],
                shadingFill: '4472C4',
              ),
              DocxTableCell(
                children: [
                  DocxParagraph(children: [
                    DocxText('Quantity',
                        fontWeight: DocxFontWeight.bold,
                        color: DocxColor.white),
                  ])
                ],
                shadingFill: '4472C4',
              ),
            ],
          ),
          DocxTableRow(
            cells: [
              DocxTableCell(children: [DocxParagraph.text('Widget A')]),
              DocxTableCell(
                  children: [DocxParagraph.text('\$19.99')],
                  shadingFill: 'E2EFDA'),
              DocxTableCell(children: [DocxParagraph.text('150')]),
            ],
          ),
          DocxTableRow(
            cells: [
              DocxTableCell(children: [DocxParagraph.text('Widget B')]),
              DocxTableCell(
                  children: [DocxParagraph.text('\$29.99')],
                  shadingFill: 'E2EFDA'),
              DocxTableCell(children: [DocxParagraph.text('75')]),
            ],
          ),
        ],
      ))

      // ============================================================
      // SECTION 6: Links
      // ============================================================
      .h2('Hyperlinks')
      .add(DocxParagraph(children: [
        DocxText('Visit '),
        DocxText('Google',
            href: 'https://www.google.com',
            color: DocxColor.blue,
            decoration: DocxTextDecoration.underline),
        DocxText(' or '),
        DocxText('GitHub',
            href: 'https://github.com',
            color: DocxColor.blue,
            decoration: DocxTextDecoration.underline),
        DocxText(' for more information.'),
      ]))

      // ============================================================
      // SECTION 7: Code Blocks
      // ============================================================
      .h2('Code Blocks')
      .add(DocxParagraph(children: [
        DocxText('Inline code: '),
        DocxText.code('print("Hello World")'),
        DocxText(' in Dart.'),
      ]))
      .p('Code block example:')
      .code('''void main() {
  final greeting = "Hello, DocxCreator!";
  print(greeting);
}''')

      // ============================================================
      // SECTION 8: Shapes and Drawings
      // ============================================================
      .h2('Shapes and Drawings')
      .p('Rectangle shape:')
      .add(DocxShapeBlock.rectangle(
        width: 200,
        height: 60,
        fillColor: DocxColor.blue,
        outlineColor: DocxColor.black,
        outlineWidth: 2,
        text: 'Blue Rectangle',
        align: DocxAlign.center,
      ))
      .p('Ellipse shape:')
      .add(DocxShapeBlock.ellipse(
        width: 150,
        height: 100,
        fillColor: DocxColor.green,
        outlineColor: DocxColor.black,
        align: DocxAlign.center,
      ))
      .p('Various shapes inline:')
      .add(DocxParagraph(children: [
        DocxShape.circle(
          diameter: 40,
          fillColor: DocxColor.red,
        ),
        DocxText('  '),
        DocxShape.triangle(
          width: 50,
          height: 50,
          fillColor: DocxColor.yellow,
          outlineColor: DocxColor.black,
        ),
        DocxText('  '),
        DocxShape.star(
          points: 5,
          width: 50,
          height: 50,
          fillColor: DocxColor.gold,
          outlineColor: DocxColor.black,
        ),
        DocxText('  '),
        DocxShape.diamond(
          width: 40,
          height: 50,
          fillColor: DocxColor.purple,
        ),
      ]))
      .p('Arrow shapes:')
      .add(DocxParagraph(children: [
        DocxShape.rightArrow(
          width: 80,
          height: 30,
          fillColor: DocxColor.blue,
        ),
        DocxText('  '),
        DocxShape.leftArrow(
          width: 80,
          height: 30,
          fillColor: DocxColor.red,
        ),
      ]))

      // ============================================================
      // SECTION 9: Special Characters
      // ============================================================
      .h2('Special Characters')
      .add(DocxParagraph(children: [
        DocxText('Line break after this:'),
        const DocxLineBreak(),
        DocxText('New line here.'),
      ]))
      .add(DocxParagraph(children: [
        DocxText('Tab character:'),
        const DocxTab(),
        DocxText('After tab.'),
      ]))

      // ============================================================
      // SECTION 10: Page Breaks
      // ============================================================
      .h2('Section and Page Breaks')
      .p('Content before page break.')
      .pageBreak()
      .h2('After Page Break')
      .p('This content appears on a new page.')

      // Build the document
      .build();

  // Export to file
  final exporter = DocxExporter();
  await exporter.exportToFile(doc, 'manual_builder_complete.docx');

  print('✅ Created: manual_builder_complete.docx');
  print('\nFeatures demonstrated:');
  print('  • Headings (H1-H6)');
  print('  • Text formatting (bold, italic, underline, strikethrough)');
  print('  • Colors (foreground and background)');
  print('  • Font sizes');
  print('  • Superscript and subscript');
  print('  • Text effects (caps, outline, shadow)');
  print('  • Highlighting');
  print('  • Paragraph alignment');
  print('  • Bullet and numbered lists');
  print('  • Nested lists');
  print('  • Simple and styled tables');
  print('  • Hyperlinks');
  print('  • Code blocks');
  print(
      '  • Shapes (rectangle, ellipse, circle, triangle, star, diamond, arrows)');
  print('  • Line breaks and tabs');
  print('  • Page breaks');
}
