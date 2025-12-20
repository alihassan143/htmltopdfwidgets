import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxEditor Workflow', () {
    test('Markdown -> Docx -> Read -> Edit -> Docx -> Read', () async {
      final markdown = r'''
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

# 4. Technical and Mathematical Rendering

The Quadratic Formula is a classic test for multi-level superscript and square root rendering:

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$

The Standard Deviation formula:

$$\sigma = \sqrt{\frac{\sum_{i=1}^{n} (x_i - \mu)^2}{n}}$$

---

# 5. Technical Implementation Details (Code Blocks)

```dart
import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio = Dio();
  
  Future<void> performTest() async {
    try {
      final response = await _dio.get('[https://api.example.com/v1/test](https://api.example.com/v1/test)');
      print('Status: ${response.statusCode}');
    } catch (e) {
      print('Error encountered: $e');
    }
  }
}
```
''';

      // 1. Create from Markdown
      final elements = await MarkdownParser.parse(markdown);
      final doc1 = DocxBuiltDocument(elements: elements);

      // Verify initial parsing structure
      expect(doc1.elements.isNotEmpty, true);

      // Check Heading 1
      final h1 = doc1.elements.first as DocxParagraph;
      expect((h1.children.first as DocxText).content,
          '1. Document Architecture and Typography');

      // Check Table presence (approximate location)
      final table = doc1.elements.whereType<DocxTable>().first;
      expect(table.rows.length, 5); // Header + 4 rows

      // 2. Save (Export)
      final bytes1 = await DocxExporter().exportToBytes(doc1);

      // 3. Read
      final doc2 = await DocxReader.loadFromBytes(bytes1);

      // Verify Read content
      expect(doc2.elements.length, greaterThan(10));
      final readTable = doc2.elements.whereType<DocxTable>().first;
      expect(readTable.rows.length, 5);
      expect(
          (readTable.rows[0].cells[0].children.first as DocxParagraph)
              .children
              .first is DocxText,
          true);

      // 4. Edit: Add a new paragraph at the end and modify the first heading
      final newElements = List<DocxNode>.from(doc2.elements);

      // Modify first heading
      final oldH1 = newElements[0] as DocxParagraph;
      // We need to construct a new paragraph because DocxParagraph might be immutable-ish equivalent
      final newH1 = oldH1
          .copyWith(children: [DocxText('1. EDITED: Document Architecture')]);
      newElements[0] = newH1;

      // Add new paragraph
      newElements.add(DocxParagraph.text('--- End of Editor Test ---'));

      final doc3 = DocxBuiltDocument(
        elements: newElements,
        section: doc2.section,
        // Preserve raw parts
        stylesXml: doc2.stylesXml,
        numberingXml: doc2.numberingXml,
        settingsXml: doc2.settingsXml,
        fontTableXml: doc2.fontTableXml,
        contentTypesXml: doc2.contentTypesXml,
        rootRelsXml: doc2.rootRelsXml,
        headerBgXml: doc2.headerBgXml,
        headerBgRelsXml: doc2.headerBgRelsXml,
      );

      // 5. Save again
      final bytes2 = await DocxExporter().exportToBytes(doc3);

      // 6. Read again
      final doc4 = await DocxReader.loadFromBytes(bytes2);

      // 7. Verify Edits
      final finalH1 = doc4.elements[0] as DocxParagraph;
      expect((finalH1.children.first as DocxText).content,
          '1. EDITED: Document Architecture');

      final lastPara = doc4.elements.last as DocxParagraph;
      expect((lastPara.children.first as DocxText).content,
          '--- End of Editor Test ---');

      // Verify structure is still intact (Table still there)
      final finalTable = doc4.elements.whereType<DocxTable>().first;
      expect(finalTable.rows.length, 5);

      // Verify Raw Content was preserved (e.g. styles, numbering)
      expect(doc4.stylesXml, isNotNull);
      expect(doc4.numberingXml, isNotNull);
    });
  });
}
