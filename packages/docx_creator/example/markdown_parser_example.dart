/// Comprehensive Markdown Parser Example
///
/// This example demonstrates ALL features of parsing Markdown to DOCX
/// using the MarkdownParser.parse() method.
///
/// Run with: dart run example/markdown_parser_example.dart
library;

import 'package:docx_creator/docx_creator.dart';

Future<void> main() async {
  print('='.padRight(60, '='));
  print('DocxCreator - Markdown Parser Complete Example');
  print('='.padRight(60, '='));

  // ============================================================
  // Comprehensive Markdown with ALL supported features
  // ============================================================

  const markdownContent = '''
# Markdown to DOCX - Complete Feature Demo

This document demonstrates all Markdown features supported by the docx_creator package.

## Headings

# Heading 1 (Title Level)
## Heading 2 (Chapter Level)
### Heading 3 (Section Level)
#### Heading 4 (Subsection Level)
##### Heading 5 (Minor Section)
###### Heading 6 (Smallest Heading)

---

## Text Formatting

### Basic Formatting

**Bold text** using double asterisks.
__Bold text__ using double underscores.

*Italic text* using single asterisks.
_Italic text_ using single underscores.

***Bold and italic*** combined.
___Bold and italic___ with underscores.

~~Strikethrough text~~ using double tildes.

### Combined Formatting

This paragraph has **bold**, *italic*, and ***bold-italic*** text all together.
You can also do ~~strikethrough~~ and combine it with **~~bold strikethrough~~**.

---

## Links

### Inline Links

Visit [Google](https://www.google.com) for searching.
Check out [GitHub](https://github.com) for code repositories.
Learn [Flutter](https://flutter.dev) for mobile development.

### Links with Title

[Dart](https://dart.dev "The Dart Programming Language") is great for building apps.

---

## Lists

### Unordered Lists (Bullets)

- First bullet item
- Second bullet item
- Third bullet item with **bold** and *italic*
- Fourth item with [a link](https://google.com)

Alternative syntax:

* Asterisk bullet
* Another asterisk bullet
* Yet another

### Ordered Lists (Numbered)

1. First numbered item
2. Second numbered item
3. Third numbered item
4. Fourth numbered item

### Nested Lists

- Level 1 - Item A
    - Level 2 - Item A.1
        - Level 3 - Item A.1.a
        - Level 3 - Item A.1.b
    - Level 2 - Item A.2
- Level 1 - Item B
- Level 1 - Item C
    1. Numbered sub-item 1
    2. Numbered sub-item 2

### Task Lists (Checkboxes)

- [ ] Unchecked task
- [x] Checked/completed task
- [ ] Another pending task
- [x] Another completed task

---

## Code

### Inline Code

Use `print()` to output text in Dart.
Variables like `myVariable` and methods like `calculateTotal()` should use code formatting.

### Code Blocks (Fenced)

```
// Plain code block without language
void main() {
  print('Hello, World!');
}
```

```dart
// Dart code block
void main() {
  final greeting = 'Hello from Markdown!';
  print(greeting);
  
  for (var i = 0; i < 5; i++) {
    print('Iteration: \$i');
  }
}
```

```python
# Python code block
def greet(name):
    return f"Hello, {name}!"

print(greet("World"))
```

```javascript
// JavaScript code block
const greet = (name) => {
  return `Hello, \${name}!`;
};

console.log(greet("World"));
```

---

## Blockquotes

> This is a simple blockquote.
> It can span multiple lines.

> **Note:** Blockquotes are commonly used for:
> - Important notes
> - Quotations
> - Callouts

---

## Tables

### Simple Table

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
| Cell 7   | Cell 8   | Cell 9   |

### Aligned Table

| Left Aligned | Center Aligned | Right Aligned |
|:-------------|:--------------:|--------------:|
| Left         | Center         | Right         |
| Data         | Data           | Data          |
| More         | More           | More          |

### Table with Formatting

| Feature | Support | Notes |
|---------|---------|-------|
| **Bold** | Yes | Works in cells |
| *Italic* | Yes | Also works |
| `Code` | Yes | Inline code too |
| [Links](https://example.com) | Yes | Links work |

---

## Horizontal Rules

Content above the horizontal rule.

---

Content below the horizontal rule.

***

Alternative horizontal rule syntax.

___

Another alternative.

---

## Complex Document Example

### Project Overview

This is a comprehensive project document that demonstrates how Markdown
can be used to create professional documents.

#### Key Features

1. **Easy to Write**
    - Simple syntax
    - Readable source
    - Version control friendly

2. **Powerful Output**
    - Converts to DOCX
    - Preserves formatting
    - Supports complex structures

3. **Flexible**
    - Works with tables
    - Supports code blocks
    - Handles nested content

#### Technical Specifications

| Specification | Value |
|--------------|-------|
| Format | .docx |
| Compatibility | Word 2007+ |
| Max File Size | Unlimited |
| Encoding | UTF-8 |

#### Sample Code

```dart
import 'package:docx_creator/docx_creator.dart';

Future<void> createDocument() async {
  final markdown = "# My Document";
  
  final elements = await MarkdownParser.parse(markdown);
  final doc = DocxBuiltDocument(elements: elements);
  
  await DocxExporter().exportToFile(doc, 'output.docx');
}
```

> **Success!** The document has been created successfully.

---

## Summary

This document has demonstrated:

- [x] All heading levels (H1-H6)
- [x] Text formatting (bold, italic, strikethrough)
- [x] Links (inline and reference)
- [x] Lists (ordered, unordered, nested, tasks)
- [x] Code (inline and blocks with syntax)
- [x] Blockquotes (simple and nested)
- [x] Tables (simple and aligned)
- [x] Horizontal rules
- [x] Complex nested structures

**Thank you for using DocxCreator!**

''';

  print('\n📝 Parsing comprehensive Markdown content...');

  // Parse Markdown to DocxNodes
  final nodes = await MarkdownParser.parse(markdownContent);

  print('✅ Parsed ${nodes.length} document elements');

  // Create document and export
  final doc = DocxBuiltDocument(elements: nodes);
  final exporter = DocxExporter();
  await exporter.exportToFile(doc, 'markdown_parser_complete.docx');

  print('✅ Created: markdown_parser_complete.docx');

  print('\nFeatures demonstrated:');
  print('  • Headings (# to ######)');
  print('  • Bold (**text** and __text__)');
  print('  • Italic (*text* and _text_)');
  print('  • Bold-italic (***text***)');
  print('  • Strikethrough (~~text~~)');
  print('  • Inline links [text](url)');
  print('  • Unordered lists (- and *)');
  print('  • Ordered lists (1. 2. 3.)');
  print('  • Nested lists (multi-level)');
  print('  • Task lists ([ ] and [x])');
  print('  • Inline code (`code`)');
  print('  • Fenced code blocks (```)');
  print('  • Code blocks with language');
  print('  • Blockquotes (>)');
  print('  • Tables with pipes');
  print('  • Table alignment (:---, :---:, ---:)');
  print('  • Horizontal rules (---, ***, ___)');
  print('  • Complex nested structures');
}
