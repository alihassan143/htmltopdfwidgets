# docx_creator

[![pub package](https://img.shields.io/pub/v/docx_creator.svg)](https://pub.dev/packages/docx_creator)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D2.19.0-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A **developer-first DOCX generation library** for Dart. Create, parse, read, and edit Microsoft Word documents with a fluent API, HTML/Markdown parsers, and full OpenXML compliance.

## ✨ Features

| Feature                        | Description                                         |
| ------------------------------ | --------------------------------------------------- |
| 🔧**Fluent Builder API** | Chain methods to create documents quickly           |
| 🌐**HTML Parser**        | Convert HTML to DOCX with 141 CSS named colors      |
| 📝**Markdown Parser**    | Parse Markdown including tables and nested lists    |
| 📖**DOCX Reader**        | Load and edit existing .docx files                  |
| 🎨**Drawing Shapes**     | 70+ preset shapes (rectangles, arrows, stars, etc.) |
| 🖼️**Images**           | Embed local, remote, or base64 images               |
| 📊**Tables**             | Styled tables with merged cells and borders         |
| 📋**Lists**              | Bullet, numbered, and nested lists (9 levels)       |
| 🔤**Fonts**              | Embed custom fonts with OOXML obfuscation           |
| 📄**Sections**           | Headers, footers, page orientation, backgrounds     |

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  docx_creator: ^1.0.0
```

Then run:

```bash
dart pub get
```

---

## 🚀 Quick Start

### Hello World

```dart
import 'package:docx_creator/docx_creator.dart';

void main() async {
  // Create a simple document
  final doc = docx()
    .h1('Hello, World!')
    .p('This is my first DOCX document.')
    .build();

  // Save to file
  await DocxExporter().exportToFile(doc, 'hello.docx');
}
```

### From HTML

```dart
final htmlContent = '''
<h1>Report Title</h1>
<p>This is a <b>bold</b> and <i>italic</i> paragraph.</p>
<ul>
  <li>Item 1</li>
  <li>Item 2</li>
</ul>
''';

final elements = await DocxParser.fromHtml(htmlContent);
final doc = DocxBuiltDocument(elements: elements);
await DocxExporter().exportToFile(doc, 'from_html.docx');
```

### From Markdown

```dart
final markdown = '''
# Project Report

## Summary
This is **important** information.

- Task 1: Complete
- Task 2: In Progress
''';

final elements = await MarkdownParser.parse(markdown);
final doc = DocxBuiltDocument(elements: elements);
await DocxExporter().exportToFile(doc, 'from_markdown.docx');
```

---

## 📖 Documentation

### Table of Contents

1. [Builder API](#builder-api)
2. [Text Formatting](#text-formatting)
3. [Lists](#lists)
4. [Tables](#tables)
5. [Images](#images)
6. [Shapes &amp; Drawings](#shapes--drawings)
7. [HTML Parser](#html-parser)
8. [Markdown Parser](#markdown-parser)
9. [DOCX Reader &amp; Editor](#docx-reader--editor)
10. [Sections &amp; Page Layout](#sections--page-layout)
11. [Font Embedding](#font-embedding)
12. [API Reference](#api-reference)

---

## Builder API

The `DocxDocumentBuilder` provides a fluent interface for document creation:

```dart
final doc = DocxDocumentBuilder()
  // Headings
  .h1('Title')
  .h2('Chapter')
  .h3('Section')
  
  // Paragraphs
  .p('Simple paragraph text')
  .p('Right-aligned', align: DocxAlign.right)
  
  // Lists
  .bullet(['Item 1', 'Item 2', 'Item 3'])
  .numbered(['Step 1', 'Step 2', 'Step 3'])
  
  // Tables
  .table([
    ['Header 1', 'Header 2'],
    ['Cell 1', 'Cell 2'],
  ])
  
  // Special elements
  .pageBreak()
  .hr()  // Horizontal rule
  .quote('Blockquote text')
  .code('print("Hello");')
  
  .build();
```

### Short vs Full Method Names

| Short               | Full                  | Description     |
| ------------------- | --------------------- | --------------- |
| `h1(text)`        | `heading1(text)`    | Heading level 1 |
| `h2(text)`        | `heading2(text)`    | Heading level 2 |
| `h3(text)`        | `heading3(text)`    | Heading level 3 |
| `p(text)`         | `text(content)`     | Paragraph       |
| `bullet(items)`   | `addList(DocxList)` | Bullet list     |
| `numbered(items)` | `addList(DocxList)` | Numbered list   |
| `hr()`            | `divider()`         | Horizontal rule |

---

## Text Formatting

Create rich text with `DocxText` and `DocxParagraph`:

```dart
final doc = DocxDocumentBuilder()
  .add(DocxParagraph(children: [
    // Basic formatting
    DocxText('Bold ', fontWeight: DocxFontWeight.bold),
    DocxText('Italic ', fontStyle: DocxFontStyle.italic),
    DocxText('Underline ', decoration: DocxTextDecoration.underline),
    DocxText('Strikethrough', decoration: DocxTextDecoration.strikethrough),
  
    // Colors
    DocxText('Red text ', color: DocxColor.red),
    DocxText('Custom color ', color: DocxColor('#FF6600')),
    DocxText('With background ', shadingFill: 'FFFF00'),
  
    // Font size
    DocxText('Large text', fontSize: 24),
  
    // Superscript/Subscript
    DocxText('E=mc'),
    DocxText('2', isSuperscript: true),
    DocxText(' H'),
    DocxText('2', isSubscript: true),
    DocxText('O'),
  
    // Highlighting
    DocxText('Highlighted', highlight: DocxHighlight.yellow),
  
    // Hyperlinks
    DocxText('Click here', 
      href: 'https://example.com',
      color: DocxColor.blue,
      decoration: DocxTextDecoration.underline),
  ]))
  .build();
```

### Available Colors

```dart
// Predefined colors
DocxColor.black, DocxColor.white, DocxColor.red, DocxColor.blue,
DocxColor.green, DocxColor.yellow, DocxColor.orange, DocxColor.purple,
DocxColor.gray, DocxColor.lightGray, DocxColor.darkGray, DocxColor.cyan,
DocxColor.magenta, DocxColor.pink, DocxColor.brown, DocxColor.navy,
DocxColor.teal, DocxColor.lime, DocxColor.gold, DocxColor.silver

// Custom hex colors
DocxColor('#FF5722')
DocxColor('4285F4')  // # is optional
```

---

## Lists

### Simple Lists

```dart
// Bullet list
.bullet(['First item', 'Second item', 'Third item'])

// Numbered list
.numbered(['Step 1', 'Step 2', 'Step 3'])
```

### Nested Lists

```dart
final nestedList = DocxList(
  style: DocxListStyle.disc,
  items: [
    DocxListItem.text('Level 0 - First', level: 0),
    DocxListItem.text('Level 1 - Nested', level: 1),
    DocxListItem.text('Level 2 - Deep', level: 2),
    DocxListItem.text('Level 1 - Back', level: 1),
    DocxListItem.text('Level 0 - Root', level: 0),
  ],
);

docx().add(nestedList).build();
```

### List Styles

```dart
DocxListStyle.disc       // • Solid disc (default)
DocxListStyle.circle     // ◦ Circle
DocxListStyle.square     // ▪ Square
DocxListStyle.dash       // - Dash
DocxListStyle.arrow      // → Arrow
DocxListStyle.check      // ✓ Checkmark
DocxListStyle.decimal    // 1, 2, 3
DocxListStyle.lowerAlpha // a, b, c
DocxListStyle.upperAlpha // A, B, C
DocxListStyle.lowerRoman // i, ii, iii
DocxListStyle.upperRoman // I, II, III
```

---

## Tables

### Simple Table

```dart
.table([
  ['Name', 'Age', 'City'],
  ['Alice', '25', 'New York'],
  ['Bob', '30', 'Los Angeles'],
])
```

### Styled Table

```dart
final styledTable = DocxTable(
  rows: [
    DocxTableRow(cells: [
      DocxTableCell(
        children: [DocxParagraph(children: [
          DocxText('Header', fontWeight: DocxFontWeight.bold, color: DocxColor.white)
        ])],
        shadingFill: '4472C4',  // Blue background
        verticalAlign: DocxVerticalAlign.center,
      ),
      // More cells...
    ]),
    // More rows...
  ],
);
```

---

## Images

```dart
import 'dart:io';

// From file
final imageBytes = await File('logo.png').readAsBytes();
final doc = docx()
  .add(DocxImage(
    bytes: imageBytes,
    extension: 'png',
    width: 200,
    height: 100,
    align: DocxAlign.center,
  ))
  .build();

// Inline image in paragraph
.add(DocxParagraph(children: [
  DocxText('See image: '),
  DocxInlineImage(bytes: imageBytes, extension: 'png', width: 50, height: 50),
  DocxText(' above.'),
]))
```

---

## Shapes & Drawings

Create DrawingML shapes with 70+ presets:

```dart
// Basic shapes
DocxShapeBlock.rectangle(
  width: 200,
  height: 60,
  fillColor: DocxColor.blue,
  outlineColor: DocxColor.black,
  outlineWidth: 2,
  text: 'Click Me',
  align: DocxAlign.center,
)

DocxShapeBlock.ellipse(width: 100, height: 100, fillColor: DocxColor.green)
DocxShapeBlock.circle(diameter: 80, fillColor: DocxColor.red)
DocxShapeBlock.triangle(width: 100, height: 100, fillColor: DocxColor.yellow)
DocxShapeBlock.star(points: 5, fillColor: DocxColor.gold)
DocxShapeBlock.diamond(width: 80, fillColor: DocxColor.purple)
DocxShapeBlock.rightArrow(width: 100, height: 40, fillColor: DocxColor.blue)
DocxShapeBlock.leftArrow(width: 100, height: 40, fillColor: DocxColor.red)

// Inline shapes in paragraph
.add(DocxParagraph(children: [
  DocxShape.circle(diameter: 30, fillColor: DocxColor.red),
  DocxText(' Red circle '),
  DocxShape.star(points: 5, fillColor: DocxColor.gold),
  DocxText(' Gold star'),
]))
```

### Shape Presets

Over 70 preset shapes including: `rect`, `ellipse`, `triangle`, `diamond`, `star4`, `star5`, `star6`, `rightArrow`, `leftArrow`, `upArrow`, `downArrow`, `heart`, `lightning`, `flowChartProcess`, `flowChartDecision`, and many more.

---

## HTML Parser

### Supported HTML Tags

| Tag                   | Output                 |
| --------------------- | ---------------------- |
| `<h1>` - `<h6>`   | Headings               |
| `<p>`               | Paragraph              |
| `<b>`, `<strong>` | Bold                   |
| `<i>`, `<em>`     | Italic                 |
| `<u>`               | Underline              |
| `<s>`, `<del>`    | Strikethrough          |
| `<mark>`            | Highlight              |
| `<sup>`             | Superscript            |
| `<sub>`             | Subscript              |
| `<a href="">`       | Hyperlink              |
| `<code>`            | Inline code            |
| `<pre>`             | Code block             |
| `<ul>`, `<ol>`    | Lists                  |
| `<table>`           | Tables                 |
| `<img>`             | Images                 |
| `<blockquote>`      | Blockquote             |
| `<hr>`              | Horizontal rule        |
| `<br>`              | Line break             |
| `<div>`, `<span>` | Containers with styles |

### Supported CSS Properties

```css
color: red;                    /* Text color */
color: #FF5722;               /* Hex color */
color: dodgerblue;            /* CSS named color (141 supported) */
background-color: yellow;      /* Background/shading */
font-size: 16px;              /* Font size */
font-weight: bold;            /* Bold */
font-style: italic;           /* Italic */
text-align: center;           /* Alignment */
text-decoration: underline;   /* Underline/strikethrough */
```

### CSS Named Colors

All **141 W3C CSS3 Extended Color Keywords** are supported:

```html
<span style="color: dodgerblue;">DodgerBlue</span>
<span style="color: mediumvioletred;">MediumVioletRed</span>
<span style="color: darkolivegreen;">DarkOliveGreen</span>
<span style="color: papayawhip;">PapayaWhip</span>
```

Including grey/gray variations: `grey`, `darkgrey`, `lightgrey`, etc.

### Example

```dart
final html = '''
<div style="background-color: #f0f0f0; padding: 10px;">
  <h1 style="color: navy;">Report Title</h1>
  <p>This is <span style="color: red; font-weight: bold;">important</span> text.</p>
  <table border="1">
    <tr style="background-color: #4472C4; color: white;">
      <th>Name</th>
      <th>Status</th>
    </tr>
    <tr>
      <td>Task 1</td>
      <td style="background-color: lightgreen;">Complete</td>
    </tr>
  </table>
</div>
''';

final elements = await DocxParser.fromHtml(html);
```

---

## Markdown Parser

### Supported Syntax

| Markdown          | Output          |
| ----------------- | --------------- |
| `# Heading`     | H1-H6           |
| `**bold**`      | Bold            |
| `*italic*`      | Italic          |
| `~~strike~~`    | Strikethrough   |
| `[text](url)`   | Links           |
| `` `code` ``      | Inline code     |
| `` ``` ``         | Code blocks     |
| `- item`        | Bullet list     |
| `1. item`       | Numbered list   |
| `> quote`       | Blockquote      |
| `---`           | Horizontal rule |
| `                 | a               |
| `[ ]` / `[x]` | Task lists      |

### Nested Lists

```markdown
- Level 1
    - Level 2
        - Level 3
    - Level 2
- Level 1
```

Nested lists are automatically converted to multi-level Word lists with proper indentation.

### Tables with Alignment

```markdown
| Left | Center | Right |
|:-----|:------:|------:|
| L    | C      | R     |
```

---

## DOCX Reader & Editor

### Loading an Existing Document

```dart
// From file path
final doc = await DocxReader.load('existing.docx');

// From bytes
final bytes = await File('existing.docx').readAsBytes();
final doc = await DocxReader.loadFromBytes(bytes);
```

### Accessing Elements

```dart
for (final element in doc.elements) {
  if (element is DocxParagraph) {
    for (final child in element.children) {
      if (child is DocxText) {
        print('Text: ${child.content}');
        print('Bold: ${child.fontWeight == DocxFontWeight.bold}');
        print('Color: ${child.color?.hex}');
      }
    }
  } else if (element is DocxTable) {
    print('Table with ${element.rows.length} rows');
  } else if (element is DocxList) {
    print('List with ${element.items.length} items');
  }
}
```

### Modifying and Re-Saving

```dart
// Load document
final doc = await DocxReader.load('report.docx');

// Modify elements
final modifiedElements = <DocxNode>[];
for (final element in doc.elements) {
  if (element is DocxParagraph) {
    // Find and replace text
    final newChildren = element.children.map((child) {
      if (child is DocxText) {
        return DocxText(
          child.content.replaceAll('OLD', 'NEW'),
          fontWeight: child.fontWeight,
          color: child.color,
        );
      }
      return child;
    }).toList();
    modifiedElements.add(DocxParagraph(children: newChildren));
  } else {
    modifiedElements.add(element);
  }
}

// Add new content
modifiedElements.add(DocxParagraph.text('Added on: ${DateTime.now()}'));

// Create new document preserving metadata
final editedDoc = DocxBuiltDocument(
  elements: modifiedElements,
  // Preserve original document properties
  section: doc.section,
  stylesXml: doc.stylesXml,
  numberingXml: doc.numberingXml,
);

// Save
await DocxExporter().exportToFile(editedDoc, 'report_edited.docx');
```

### Round-Trip Pipeline

```dart
// Load → Parse → Modify → Export
final original = await DocxReader.load('input.docx');

// All formatting, lists, tables, shapes are preserved
final elements = List<DocxNode>.from(original.elements);

// Add new content
elements.add(DocxParagraph.heading2('New Section'));
elements.add(DocxParagraph.text('Content added programmatically.'));

// Export with preserved metadata
final output = DocxBuiltDocument(
  elements: elements,
  stylesXml: original.stylesXml,
  numberingXml: original.numberingXml,
);

await DocxExporter().exportToFile(output, 'output.docx');
```

---

## Sections & Page Layout

```dart
final doc = DocxDocumentBuilder()
  .section(
    orientation: DocxPageOrientation.portrait,
    pageSize: DocxPageSize.a4,
    backgroundColor: DocxColor('#F0F8FF'),
    header: DocxHeader(children: [
      DocxParagraph.text('Company Name', align: DocxAlign.right),
    ]),
    footer: DocxFooter(children: [
      DocxParagraph.text('Page 1', align: DocxAlign.center),
    ]),
  )
  .h1('Document Title')
  .p('Content...')
  .build();
```

### Multi-Section Documents

```dart
docx()
  .p('Portrait section content')
  .addSectionBreak(DocxSectionDef(
    orientation: DocxPageOrientation.portrait,
  ))
  .p('Landscape section content')
  .addSectionBreak(DocxSectionDef(
    orientation: DocxPageOrientation.landscape,
  ))
  .build();
```

---

## Font Embedding

Embed custom fonts with OOXML-compliant obfuscation:

```dart
import 'dart:io';

final fontBytes = await File('fonts/Roboto-Regular.ttf').readAsBytes();

final doc = DocxDocumentBuilder()
  .addFont('Roboto', fontBytes)
  .add(DocxParagraph(children: [
    DocxText('Custom font text', fontFamily: 'Roboto'),
  ]))
  .build();
```

> **Note:** Fonts are automatically obfuscated per the OpenXML specification to ensure compatibility with Microsoft Word.

---

## API Reference

### DocxDocumentBuilder

| Method                              | Parameters                   | Description          |
| ----------------------------------- | ---------------------------- | -------------------- |
| `h1(text)`                        | `String text`              | Add H1 heading       |
| `h2(text)`                        | `String text`              | Add H2 heading       |
| `h3(text)`                        | `String text`              | Add H3 heading       |
| `heading(level, text)`            | `DocxHeadingLevel, String` | Add heading at level |
| `p(text, {align})`                | `String, DocxAlign?`       | Add paragraph        |
| `bullet(items)`                   | `List<String>`             | Add bullet list      |
| `numbered(items)`                 | `List<String>`             | Add numbered list    |
| `table(data, {hasHeader, style})` | `List<List<String>>`       | Add table            |
| `pageBreak()`                     | -                            | Add page break       |
| `hr()`                            | -                            | Add horizontal rule  |
| `quote(text)`                     | `String`                   | Add blockquote       |
| `code(code)`                      | `String`                   | Add code block       |
| `add(node)`                       | `DocxNode`                 | Add any node         |
| `addFont(name, bytes)`            | `String, Uint8List`        | Embed font           |
| `section({...})`                  | Various                      | Set page properties  |
| `build()`                         | -                            | Build document       |

### DocxExporter

| Method                      | Parameters                    | Description  |
| --------------------------- | ----------------------------- | ------------ |
| `exportToFile(doc, path)` | `DocxBuiltDocument, String` | Save to file |
| `exportToBytes(doc)`      | `DocxBuiltDocument`         | Get as bytes |

### DocxReader

| Method                   | Parameters    | Description         |
| ------------------------ | ------------- | ------------------- |
| `load(path)`           | `String`    | Load from file path |
| `loadFromBytes(bytes)` | `Uint8List` | Load from bytes     |

### DocxParser

| Method               | Parameters | Description             |
| -------------------- | ---------- | ----------------------- |
| `fromHtml(html)`   | `String` | Parse HTML to nodes     |
| `fromMarkdown(md)` | `String` | Parse Markdown to nodes |

### MarkdownParser

| Method              | Parameters | Description             |
| ------------------- | ---------- | ----------------------- |
| `parse(markdown)` | `String` | Parse Markdown to nodes |

---

## Troubleshooting

### Common Issues

**Q: Fonts don't display correctly in Word**

A: Ensure the font is embedded using `addFont()`. Embedded fonts are obfuscated per OpenXML spec.

**Q: Images don't appear**

A: Verify image bytes are valid and extension matches format (`png`, `jpg`, `gif`).

**Q: Lists don't have bullets/numbers**

A: Ensure you're using the fluent API (`bullet()`, `numbered()`) or properly structured `DocxList` with `DocxListItem`.

**Q: Colors look wrong**

A: Use 6-digit hex codes without # prefix for `shadingFill`. For `DocxColor`, you can use `#RRGGBB` or plain `RRGGBB`.

---

## Examples

See the `example/` directory for comprehensive examples:

- [`manual_builder_example.dart`](example/manual_builder_example.dart) - All builder API features
- [`html_parser_example.dart`](example/html_parser_example.dart) - HTML to DOCX
- [`markdown_parser_example.dart`](example/markdown_parser_example.dart) - Markdown to DOCX
- [`reader_editor_example.dart`](example/reader_editor_example.dart) - Read, edit, save workflow

---

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read our contributing guidelines and submit PRs to the main repository.
