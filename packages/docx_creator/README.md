# docx_creator

[![pub package](https://img.shields.io/pub/v/docx_creator.svg)](https://pub.dev/packages/docx_creator)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A **developer-first** Dart package for creating professional DOCX documents with a fluent API, Markdown/HTML parsing, and comprehensive formatting options.

---

## ✨ Features

- 🚀 **Fluent API** - Chain methods for clean, readable code
- 📝 **Full Formatting** - Bold, italic, colors, superscript, and more
- 📊 **Tables** - Multiple styles (grid, zebra, professional)
- 📋 **Lists** - Bullet and numbered with custom styling
- 🎨 **Colors** - Predefined + custom hex colors
- 📄 **Headers/Footers** - Page numbers, styled text
- 🖼️ **Images** - Embed images with alignment
- 🔄 **Parsers** - Convert Markdown & HTML to DOCX
- 🎭 **Page Backgrounds** - Custom background colors

---

## 📦 Installation

```yaml
dependencies:
  docx_creator: ^1.0.0
```

---

## 🚀 Quick Start

```dart
import 'package:docx_creator/docx_creator.dart';

void main() async {
  final doc = docx()
    .h1('My Document')
    .p('Hello, World!')
    .bullet(['Feature 1', 'Feature 2', 'Feature 3'])
    .table([
      ['Name', 'Score'],
      ['Alice', '95'],
      ['Bob', '87'],
    ])
    .build();

  await DocxExporter().exportToFile(doc, 'output.docx');
}
```

---

## 📖 API Reference

### Document Builder

| Method | Description |
|--------|-------------|
| `.h1(text)` | Heading level 1 |
| `.h2(text)` | Heading level 2 |
| `.h3(text)` | Heading level 3 |
| `.p(text)` | Paragraph |
| `.bullet([...])` | Bullet list |
| `.numbered([...])` | Numbered list |
| `.table(data)` | Table from 2D array |
| `.quote(text)` | Blockquote |
| `.code(text)` | Code block |
| `.hr()` | Horizontal rule / divider |
| `.divider()` | Divider (alias for hr) |
| `.pageBreak()` | Page break |
| `.section(...)` | Page settings |
| `.build()` | Build document |

### Text Styling

```dart
DocxText('Normal text')
DocxText.bold('Bold text')
DocxText.italic('Italic text')
DocxText.underline('Underlined')
DocxText.strike('Strikethrough')
DocxText.superscript('²')
DocxText.subscript('n')
DocxText.code('inline code')
DocxText.link('URL', href: 'https://...')
DocxText('Custom', color: DocxColor('#4285F4'))
```

### Colors

```dart
// Predefined
DocxColor.red
DocxColor.blue
DocxColor.green

// Custom hex
DocxColor('#FF5722')
DocxColor('4285F4')
```

### Tables

```dart
.table(data, style: DocxTableStyle.grid)
.table(data, style: DocxTableStyle.zebra)
.table(data, style: DocxTableStyle.professional)
.table(data, style: DocxTableStyle.plain)
```

### Headers & Footers

```dart
.section(
  header: DocxHeader.text('My Document'),
  footer: DocxFooter.pageNumbers(),
  backgroundColor: DocxColor('#F5F5F5'),
)
```

### Parsing

```dart
// From Markdown
final nodes = DocxParser.fromMarkdown('''
# Title
This is **bold** and *italic*.
- Item 1
- Item 2
''');

// From HTML
final nodes = DocxParser.fromHtml('''
<h1>Title</h1>
<p><strong>Bold</strong> text</p>
''');

// Add to document
for (var node in nodes) {
  builder.add(node);
}
```

---

## 📄 Complete Example

```dart
import 'package:docx_creator/docx_creator.dart';

void main() async {
  final doc = docx()
    .section(
      header: DocxHeader.styled('Report', color: DocxColor.blue, bold: true),
      footer: DocxFooter.pageNumbers(),
      backgroundColor: DocxColor('#FAFAFA'),
    )
    .h1('Annual Report 2024')
    .p('Executive summary with key findings.')
    
    .h2('Highlights')
    .bullet([
      'Revenue increased 25%',
      'Customer base grew 40%',
      'Launched 3 new products',
    ])
    
    .h2('Financial Summary')
    .table([
      ['Quarter', 'Revenue', 'Growth'],
      ['Q1', '\$1.2M', '+15%'],
      ['Q2', '\$1.5M', '+25%'],
      ['Q3', '\$1.8M', '+20%'],
      ['Q4', '\$2.1M', '+17%'],
    ], style: DocxTableStyle.professional)
    
    .pageBreak()
    .h1('Appendix')
    .paragraph(DocxParagraph(children: [
      DocxText('For questions, contact '),
      DocxText.link('support@company.com', href: 'mailto:support@company.com'),
    ]))
    .build();

  await DocxExporter().exportToFile(doc, 'annual_report.docx');
  print('Document created!');
}
```

---

## 🔧 Advanced Usage

### Rich Text Paragraphs

```dart
DocxParagraph(children: [
  DocxText('Normal '),
  DocxText.bold('bold '),
  DocxText('and '),
  DocxText('colored', color: DocxColor.red),
])
```

### Custom Table Styling

```dart
DocxTable.fromData(data, style: DocxTableStyle(
  border: DocxBorder.double,
  headerFill: '4472C4',
  evenRowFill: 'F5F5F5',
  cellPadding: 150,
))
```

### Images

```dart
DocxImage(
  bytes: imageBytes,
  extension: 'png',
  width: 400,
  height: 300,
  align: DocxAlign.center,
  altText: 'Company Logo',
)
```

---

## 📋 Supported Elements

| Element | Status |
|---------|--------|
| Paragraphs | ✅ |
| Headings (H1-H6) | ✅ |
| Bold/Italic/Underline | ✅ |
| Superscript/Subscript | ✅ |
| Colors (predefined + hex) | ✅ |
| Bullet Lists | ✅ |
| Numbered Lists | ✅ |
| Tables | ✅ |
| Images | ✅ |
| Headers/Footers | ✅ |
| Page Numbers | ✅ |
| Page Breaks | ✅ |
| Horizontal Rules | ✅ |
| Blockquotes | ✅ |
| Code Blocks | ✅ |
| Hyperlinks | ✅ |
| Page Backgrounds | ✅ |
| Markdown Parsing | ✅ |
| HTML Parsing | ✅ |

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

---

Made with ❤️ for the Dart community
