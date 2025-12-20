import 'dart:io';

import 'package:docx_creator/docx_creator.dart';

/// This example demonstrates the complete workflow:
/// 1. Parse Markdown content to DOCX AST
/// 2. Export to a DOCX file
/// 3. Read the DOCX file back
/// 4. Edit the content programmatically
/// 5. Save the edited version
void main() async {
  // Step 1: Create comprehensive markdown test content
  final markdown = '''
# 1. Document Architecture and Typography
## 1.2 Heading Level 2
### 1.2.1 Heading Level 3
#### 1.2.1.1 Heading Level 4

This paragraph tests standard body text. It includes **bold text**, *italicized text*, and ***bold-italic combinations***. You should also check for ~~strikethrough text~~ and `inline code blocks` like `System.out.println("Hello World");`.

> **Note:** This is a blockquote. In a .docx file, this is typically rendered as an indented paragraph with a distinct left-side border or background shading to set it apart from the main body text.

---

# 2. Structured Data and Comparisons

Tables are often the most difficult part of a document conversion. This section tests cell alignment, header rows, and multi-line cell content.

| Feature ID | Attribute Name | Capability Status | Implementation Priority |
| :--- | :--- | :--- | :--- |
| **REQ-001** | Bold/Italic Parsing | Supported | Critical |
| **REQ-002** | Nested Bullet Points | Partial | High |
| **REQ-003** | Table Cell Spanning | Not Tested | Medium |
| **REQ-004** | Hyperlink Integration | Supported | Low |

---

# 3. List Structures (Nesting Test)

* **Primary Level Item**
    * Secondary Level Item (Bullet)
        * Tertiary Level with more detail.
* **Ordered List Test**
    1. First step in the process.
    2. Second step with a sub-list:
        * Verify configuration.
        * Check logs.
    3. Final validation step.

---

# 4. Technical Implementation Details (Code Blocks)

```dart
import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio = Dio();
  
  Future<void> performTest() async {
    try {
      final response = await _dio.get('https://api.example.com/v1/test');
      print('Status: \${response.statusCode}');
    } catch (e) {
      print('Error encountered: \$e');
    }
  }
}
```
''';

  print('📝 Step 1: Parsing Markdown to DOCX AST...');
  // Parse markdown to DOCX AST
  final nodes = await MarkdownParser.parse(markdown);
  print('✅ Parsed ${nodes.length} nodes from markdown');

  print('\n📦 Step 2: Creating DOCX document...');
  // Create a document with the parsed nodes
  final document = DocxBuiltDocument(
    elements: nodes,
    section: DocxSectionDef(
      pageSize: DocxPageSize.a4,
      orientation: DocxPageOrientation.portrait,
    ),
  );

  print('\n💾 Step 3: Exporting to file (original.docx)...');
  // Export to file
  final exporter = DocxExporter();
  final originalPath = 'example/output/original.docx';

  // Create output directory if it doesn't exist
  final outputDir = Directory('example/output');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }

  await exporter.exportToFile(document, originalPath);
  print('✅ Saved original document to: $originalPath');

  print('\n📖 Step 4: Reading the DOCX file back...');
  // Read the DOCX file back
  final loadedDoc = await DocxReader.load(originalPath);
  print('✅ Loaded document with ${loadedDoc.elements.length} elements');

  print('\n✏️  Step 5: Editing the document content...');
  // Edit the content - let's modify some paragraphs
  final editedElements = <DocxNode>[];

  for (var element in loadedDoc.elements) {
    if (element is DocxParagraph) {
      // Add a new heading at the beginning
      if (element == loadedDoc.elements.first) {
        editedElements.add(
          DocxParagraph.heading1(
            'EDITED DOCUMENT - Comprehensive Test Report',
          ),
        );
        editedElements.add(
          DocxParagraph(
            children: [
              DocxText.italic(
                'This document has been programmatically edited and re-saved.',
              ),
            ],
          ),
        );
        editedElements.add(DocxParagraph(children: [])); // Empty line
      }

      // Modify headings to add "[EDITED]" prefix
      if (element.styleId != null && element.styleId!.contains('Heading')) {
        // Preserve the original formatting by keeping the original children
        // and just prepending the [EDITED] prefix
        final newChildren = <DocxInline>[
          DocxText('[EDITED] '),
          ...element.children,
        ];

        editedElements.add(
          DocxParagraph(
            styleId: element.styleId,
            children: newChildren,
            align: element.align,
            spacingBefore: element.spacingBefore,
            spacingAfter: element.spacingAfter,
            lineSpacing: element.lineSpacing,
            indentLeft: element.indentLeft,
            indentRight: element.indentRight,
            indentFirstLine: element.indentFirstLine,
            borderBottom: element.borderBottom,
            shadingFill: element.shadingFill,
            outlineLevel: element.outlineLevel,
            pageBreakBefore: element.pageBreakBefore,
            numId: element.numId,
            ilvl: element.ilvl,
          ),
        );
      } else {
        // Keep other paragraphs as is
        editedElements.add(element);
      }
    } else if (element is DocxTable) {
      // Add a note before tables
      editedElements.add(
        DocxParagraph(
          children: [
            DocxText.bold('Note: '),
            DocxText(
                'The following table has been preserved from the original document.'),
          ],
        ),
      );
      editedElements.add(element);
    } else {
      // Keep other elements as is
      editedElements.add(element);
    }
  }

  print('✅ Modified ${editedElements.length} elements');

  print('\n💾 Step 6: Saving edited document (edited.docx)...');
  // Create edited document
  final editedDoc = DocxBuiltDocument(
    elements: editedElements,
    section: loadedDoc.section,
    // Preserve the raw XML from original document
    stylesXml: loadedDoc.stylesXml,
    numberingXml: loadedDoc.numberingXml,
    settingsXml: loadedDoc.settingsXml,
    fontTableXml: loadedDoc.fontTableXml,
    contentTypesXml: loadedDoc.contentTypesXml,
    rootRelsXml: loadedDoc.rootRelsXml,
  );

  // Export edited document
  final editedPath = 'example/output/edited.docx';
  await exporter.exportToFile(editedDoc, editedPath);
  print('✅ Saved edited document to: $editedPath');

  print('\n🎉 Workflow Complete!');
  print('───────────────────────────────────────');
  print('Original document: $originalPath');
  print('Edited document:   $editedPath');
  print('───────────────────────────────────────');
  print('\nYou can now open both files in Microsoft Word or LibreOffice');
  print('to verify the content and formatting.');
}
