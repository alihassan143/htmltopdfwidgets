/// Comprehensive Reader and Editor Example
///
/// This example demonstrates ALL features of reading, editing,
/// and re-saving DOCX files using DocxReader and DocxExporter.
///
/// Run with: dart run example/reader_editor_example.dart
library;

import 'dart:io';

import 'package:docx_creator/docx_creator.dart';

Future<void> main() async {
  print('='.padRight(60, '='));
  print('DocxCreator - Reader & Editor Complete Example');
  print('='.padRight(60, '='));

  // ============================================================
  // STEP 1: Create an initial document with various features
  // ============================================================
  print('\n📝 Step 1: Creating initial document with all features...');

  final initialDoc = DocxDocumentBuilder()
      .h1('Original Document Title')
      .p('This document will be read, edited, and saved.')
      .h2('Text Formatting Section')
      .add(DocxParagraph(children: [
        DocxText('Normal, '),
        DocxText('bold, ', fontWeight: DocxFontWeight.bold),
        DocxText('italic, ', fontStyle: DocxFontStyle.italic),
        DocxText('underlined, ', decoration: DocxTextDecoration.underline),
        DocxText('colored.', color: DocxColor.blue),
      ]))
      .h2('Lists Section')
      .bullet([
        'First bullet item',
        'Second bullet item',
        'Third bullet item',
      ])
      .numbered([
        'First numbered item',
        'Second numbered item',
        'Third numbered item',
      ])
      .h2('Table Section')
      .table([
        ['Name', 'Age', 'City'],
        ['Alice', '25', 'New York'],
        ['Bob', '30', 'Los Angeles'],
        ['Charlie', '35', 'Chicago'],
      ])
      .h2('Shapes Section')
      .add(DocxShapeBlock.rectangle(
        width: 150,
        height: 60,
        fillColor: DocxColor.blue,
        outlineColor: DocxColor.black,
        text: 'Original Shape',
      ))
      .h2('Links Section')
      .add(DocxParagraph(children: [
        DocxText('Visit '),
        DocxText('Google',
            href: 'https://www.google.com',
            color: DocxColor.blue,
            decoration: DocxTextDecoration.underline),
        DocxText(' for more.'),
      ]))
      .h2('Code Section')
      .add(DocxParagraph(children: [
        DocxText('Code example: '),
        DocxText.code('print("Hello");'),
      ]))
      .build();

  // Save original document
  final exporter = DocxExporter();
  final originalBytes = await exporter.exportToBytes(initialDoc);
  await File('reader_editor_step1_original.docx').writeAsBytes(originalBytes);

  print('✅ Created: reader_editor_step1_original.docx');

  // ============================================================
  // STEP 2: Read the document back
  // ============================================================
  print('\n📖 Step 2: Reading the document...');

  final readDoc = await DocxReader.loadFromBytes(originalBytes);

  print('   Read ${readDoc.elements.length} elements from document');

  // Display what was read
  _printDocumentSummary(readDoc);

  // ============================================================
  // STEP 3: Modify the document
  // ============================================================
  print('\n✏️ Step 3: Editing the document...');

  // Create a new list of elements with modifications
  final modifiedElements = <DocxNode>[];

  // 3a. Modify the title
  print('   - Modifying title...');
  final oldTitle = readDoc.elements[0] as DocxParagraph;
  final oldTitleText = oldTitle.children.isNotEmpty
      ? (oldTitle.children.first as DocxText).content
      : 'Unknown';
  final newTitle = DocxParagraph(
    children: [
      DocxText('EDITED: $oldTitleText',
          fontWeight: DocxFontWeight.bold, color: DocxColor.red),
    ],
  );
  modifiedElements.add(newTitle);

  // 3b. Add a timestamp paragraph after title
  print('   - Adding timestamp...');
  modifiedElements.add(DocxParagraph(
    children: [
      DocxText('Edited on: ${DateTime.now().toString()}',
          fontStyle: DocxFontStyle.italic, color: DocxColor.gray),
    ],
  ));

  // 3c. Keep some original elements
  print('   - Preserving original content...');
  for (var i = 1; i < readDoc.elements.length; i++) {
    modifiedElements.add(readDoc.elements[i]);
  }

  // 3d. Add new content at the end
  print('   - Adding new sections...');
  modifiedElements.addAll([
    DocxParagraph.heading2('New Section Added by Editor'),
    DocxParagraph.text(
        'This section was added programmatically after reading the original document.'),
    DocxParagraph(
      children: [
        DocxText('Features preserved: ', fontWeight: DocxFontWeight.bold),
        DocxText('text formatting, lists, tables, shapes, links, code.'),
      ],
    ),

    // Add new table
    DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(children: [
            DocxParagraph(children: [
              DocxText('Edit Action',
                  fontWeight: DocxFontWeight.bold, color: DocxColor.white)
            ])
          ], shadingFill: '4472C4'),
          DocxTableCell(children: [
            DocxParagraph(children: [
              DocxText('Result',
                  fontWeight: DocxFontWeight.bold, color: DocxColor.white)
            ])
          ], shadingFill: '4472C4'),
        ]),
        DocxTableRow(cells: [
          DocxTableCell(children: [DocxParagraph.text('Modified Title')]),
          DocxTableCell(children: [DocxParagraph.text('Added EDITED prefix')]),
        ]),
        DocxTableRow(cells: [
          DocxTableCell(children: [DocxParagraph.text('Added Timestamp')]),
          DocxTableCell(children: [DocxParagraph.text('Shows edit date/time')]),
        ]),
        DocxTableRow(cells: [
          DocxTableCell(children: [DocxParagraph.text('Added New Section')]),
          DocxTableCell(children: [DocxParagraph.text('Extra content at end')]),
        ]),
      ],
    ),

    // Add new shape
    DocxShapeBlock.ellipse(
      width: 120,
      height: 80,
      fillColor: DocxColor.green,
      outlineColor: DocxColor.black,
      text: 'New Shape!',
    ),
  ]);

  // ============================================================
  // STEP 4: Create the edited document
  // ============================================================
  print('\n📄 Step 4: Creating edited document...');

  final editedDoc = DocxBuiltDocument(
    elements: modifiedElements,
    // Preserve original document properties
    section: readDoc.section,
    stylesXml: readDoc.stylesXml,
    numberingXml: readDoc.numberingXml,
    settingsXml: readDoc.settingsXml,
    fontTableXml: readDoc.fontTableXml,
    contentTypesXml: readDoc.contentTypesXml,
    rootRelsXml: readDoc.rootRelsXml,
  );

  // Save edited document
  await exporter.exportToFile(editedDoc, 'reader_editor_step4_edited.docx');

  print('✅ Created: reader_editor_step4_edited.docx');

  // ============================================================
  // STEP 5: Verify by reading the edited document
  // ============================================================
  print('\n🔍 Step 5: Verifying edited document...');

  final verifyDoc = await DocxReader.load('reader_editor_step4_edited.docx');

  print('   Edited document contains ${verifyDoc.elements.length} elements');
  print('   (Original had ${readDoc.elements.length} elements)');

  // ============================================================
  // STEP 6: Demonstrate advanced editing scenarios
  // ============================================================
  print('\n🔧 Step 6: Advanced editing scenarios...');

  // 6a. Find and replace text
  print('   - Find and replace example...');
  final findReplaceDoc = _findAndReplace(
    verifyDoc,
    'Original',
    'REPLACED',
  );
  await exporter.exportToFile(
      findReplaceDoc, 'reader_editor_step6_findreplace.docx');
  print('   ✅ Created: reader_editor_step6_findreplace.docx');

  // 6b. Extract text only
  print('   - Extract all text...');
  final extractedText = _extractAllText(verifyDoc);
  await File('reader_editor_extracted_text.txt').writeAsString(extractedText);
  print('   ✅ Created: reader_editor_extracted_text.txt');

  // 6c. Count elements
  print('   - Analyze document structure...');
  _analyzeDocument(verifyDoc);

  // ============================================================
  // SUMMARY
  // ============================================================
  print('\n${'=' * 60}');
  print('WORKFLOW COMPLETE');
  print('=' * 60);
  print('\nFiles created:');
  print('  1. reader_editor_step1_original.docx - Initial document');
  print('  2. reader_editor_step4_edited.docx - Modified document');
  print('  3. reader_editor_step6_findreplace.docx - Find/replace example');
  print('  4. reader_editor_extracted_text.txt - Text extraction');

  print('\nReader features demonstrated:');
  print('  • Load DOCX from file (DocxReader.load)');
  print('  • Load DOCX from bytes (DocxReader.loadFromBytes)');
  print('  • Parse paragraphs, formatting, colors');
  print('  • Parse lists (bullet and numbered)');
  print('  • Parse tables with styling');
  print('  • Parse shapes and drawings');
  print('  • Parse hyperlinks');
  print('  • Parse code formatting');
  print('  • Preserve document metadata (styles, numbering, settings)');

  print('\nEditor features demonstrated:');
  print('  • Modify existing paragraphs');
  print('  • Add new content');
  print('  • Preserve original formatting');
  print('  • Preserve document properties');
  print('  • Find and replace text');
  print('  • Extract text content');
  print('  • Analyze document structure');
}

/// Print summary of document contents
void _printDocumentSummary(DocxBuiltDocument doc) {
  var paragraphCount = 0;
  var tableCount = 0;
  var listCount = 0;
  var shapeCount = 0;

  for (final element in doc.elements) {
    if (element is DocxParagraph) {
      paragraphCount++;
      // Count shapes in paragraph
      for (final child in element.children) {
        if (child is DocxShape) shapeCount++;
      }
    } else if (element is DocxTable) {
      tableCount++;
    } else if (element is DocxList) {
      listCount++;
    } else if (element is DocxShapeBlock) {
      shapeCount++;
    }
  }

  print('   Document Summary:');
  print('     - Paragraphs: $paragraphCount');
  print('     - Tables: $tableCount');
  print('     - Lists: $listCount');
  print('     - Shapes: $shapeCount');
  print('     - Has styles: ${doc.stylesXml != null}');
  print('     - Has numbering: ${doc.numberingXml != null}');
}

/// Find and replace text in document
DocxBuiltDocument _findAndReplace(
  DocxBuiltDocument doc,
  String find,
  String replace,
) {
  final newElements = <DocxNode>[];

  for (final element in doc.elements) {
    if (element is DocxParagraph) {
      final newChildren = <DocxInline>[];
      for (final child in element.children) {
        if (child is DocxText) {
          newChildren.add(DocxText(
            child.content.replaceAll(find, replace),
            fontWeight: child.fontWeight,
            fontStyle: child.fontStyle,
            decoration: child.decoration,
            color: child.color,
            shadingFill: child.shadingFill,
            fontSize: child.fontSize,
            fontFamily: child.fontFamily,
          ));
        } else {
          newChildren.add(child);
        }
      }
      newElements.add(DocxParagraph(
        children: newChildren,
        align: element.align,
      ));
    } else {
      newElements.add(element);
    }
  }

  return DocxBuiltDocument(
    elements: newElements,
    section: doc.section,
    stylesXml: doc.stylesXml,
    numberingXml: doc.numberingXml,
  );
}

/// Extract all text from document
String _extractAllText(DocxBuiltDocument doc) {
  final buffer = StringBuffer();

  for (final element in doc.elements) {
    if (element is DocxParagraph) {
      for (final child in element.children) {
        if (child is DocxText) {
          buffer.write(child.content);
        }
      }
      buffer.writeln();
    } else if (element is DocxTable) {
      for (final row in element.rows) {
        for (final cell in row.cells) {
          for (final cellChild in cell.children) {
            if (cellChild is DocxParagraph) {
              for (final inline in cellChild.children) {
                if (inline is DocxText) {
                  buffer.write(inline.content);
                  buffer.write('\t');
                }
              }
            }
          }
        }
        buffer.writeln();
      }
    } else if (element is DocxList) {
      for (final item in element.items) {
        buffer.write('  • ');
        // DocxListItem.children is List<DocxInline>
        for (final inline in item.children) {
          if (inline is DocxText) {
            buffer.write(inline.content);
          }
        }
        buffer.writeln();
      }
    }
  }

  return buffer.toString();
}

/// Analyze document structure
void _analyzeDocument(DocxBuiltDocument doc) {
  var totalChars = 0;
  var totalWords = 0;
  var boldCount = 0;
  var italicCount = 0;
  var linkCount = 0;
  var coloredTextCount = 0;

  for (final element in doc.elements) {
    if (element is DocxParagraph) {
      for (final child in element.children) {
        if (child is DocxText) {
          totalChars += child.content.length;
          totalWords += child.content.split(RegExp(r'\s+')).length;
          if (child.fontWeight == DocxFontWeight.bold) boldCount++;
          if (child.fontStyle == DocxFontStyle.italic) italicCount++;
          if (child.href != null) linkCount++;
          if (child.color != null) coloredTextCount++;
        }
      }
    }
  }

  print('   Document Analysis:');
  print('     - Total characters: $totalChars');
  print('     - Estimated words: $totalWords');
  print('     - Bold text runs: $boldCount');
  print('     - Italic text runs: $italicCount');
  print('     - Hyperlinks: $linkCount');
  print('     - Colored text runs: $coloredTextCount');
}
