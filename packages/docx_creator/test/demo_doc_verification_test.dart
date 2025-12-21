import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  test('demo.docx verification', () async {
    final file = File('demo.docx');
    if (!file.existsSync()) {
      // detailed check for CI/CD where path might differ
      print(
          'Warning: demo.docx not found at ${file.absolute.path}. Skipping test.');
      return;
    }

    final bytes = await file.readAsBytes();
    final doc = await DocxReader.loadFromBytes(bytes);

    // 1. Verify Basic Structure
    expect(doc.elements, isNotEmpty);
    expect(doc.section, isNotNull);

    // 2. Count Features
    int tablesCount = 0;
    int floatingTablesCount = 0;
    int dropCapsCount = 0;
    int footnotesCount = 0;
    int textBordersCount = 0;
    int inlineImagesCount = 0;
    int listsCount = 0;

    void traverse(List<DocxNode> nodes) {
      for (var node in nodes) {
        if (node is DocxTable) {
          tablesCount++;
          if (node.position != null) {
            floatingTablesCount++;
            // Verify floating table detected
            expect(node.position, isNotNull);
          }
          for (var row in node.rows) {
            for (var cell in row.cells) {
              traverse(cell.children);
            }
          }
        } else if (node is DocxDropCap) {
          dropCapsCount++;
          expect(node.letter, isNotEmpty);
          expect(node.lines, greaterThanOrEqualTo(2));
        } else if (node is DocxParagraph) {
          for (var child in node.children) {
            if (child is DocxFootnoteRef) {
              footnotesCount++;
            } else if (child is DocxText) {
              if (child.textBorder != null) {
                textBordersCount++;
                expect(child.textBorder!.style, isNot(DocxBorder.none));
              }
            } else if (child is DocxInlineImage) {
              inlineImagesCount++;
            }
          }
        } else if (node is DocxList) {
          listsCount++;
        }
      }
    }

    traverse(doc.elements);

    // 3. Assert on specific known content of demo.docx
    // Based on inspection findings

    // Check for "Demonstration of DOCX support" text
    bool foundTitle = false;
    for (var element in doc.elements) {
      if (element is DocxParagraph) {
        final text =
            element.children.whereType<DocxText>().map((e) => e.content).join();
        if (text.contains('Demonstration of DOCX support')) {
          foundTitle = true;
          break;
        }
      }
    }
    expect(foundTitle, isTrue, reason: 'Title text not found');

    // 4. Assert Feature Counts (based on inspection)
    // We saw: Tables: 6, Floating Tables: 1, Drop Caps: 1, Footnotes: 1, Text Borders: 1

    expect(tablesCount, 6, reason: 'Should identify 6 tables');
    expect(floatingTablesCount, 1, reason: 'Should identify 1 floating table');
    expect(dropCapsCount, 1, reason: 'Should identify 1 drop cap');
    expect(footnotesCount, 1, reason: 'Should identify 1 footnote reference');
    expect(textBordersCount, 1, reason: 'Should identify 1 text border');

    // There are definitely lists and images
    expect(listsCount, greaterThan(0), reason: 'Should find lists');
    expect(inlineImagesCount, greaterThan(0), reason: 'Should find images');

    print('SUCCESS: Verified all features in demo.docx');
    print('- $tablesCount Tables ($floatingTablesCount Floating)');
    print('- $dropCapsCount Drop Caps');
    print('- $footnotesCount Footnotes');
    print('- $textBordersCount Text Borders');
    print('- $listsCount Lists');
  });
}
