# docx_creator - Complete Documentation

This document provides in-depth technical documentation for all features of the `docx_creator` package.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AST Node Types](#ast-node-types)
3. [HTML Parser - Complete Guide](#html-parser---complete-guide)
4. [Markdown Parser - Complete Guide](#markdown-parser---complete-guide)
5. [DOCX Reader & Editor - Complete Guide](#docx-reader--editor---complete-guide)
6. [PDF Reader - Complete Guide](#pdf-reader---complete-guide)
7. [PDF Export - Complete Guide](#pdf-export---complete-guide)
8. [Drawing & Shapes - Complete Guide](#drawing--shapes---complete-guide)
9. [Advanced Features](#advanced-features)
10. [OpenXML Internals](#openxml-internals)
11. [Advanced Examples](#advanced-examples)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
docx_creator/
├── lib/src/
│   ├── ast/                    # Abstract Syntax Tree nodes
│   │   ├── docx_node.dart      # Base node & visitor
│   │   ├── docx_block.dart     # Block elements (paragraph)
│   │   ├── docx_inline.dart    # Inline elements (text, images)
│   │   ├── docx_list.dart      # List structures
│   │   ├── docx_table.dart     # Table structures
│   │   ├── docx_drawing.dart   # Shape/drawing elements
│   │   ├── docx_image.dart     # Image blocks
│   │   └── docx_section.dart   # Section properties
│   ├── builder/                # Fluent API builder
│   ├── core/                   # Enums, colors, exceptions
│   ├── exporters/              # DOCX/HTML exporters
│   ├── parsers/                # HTML/Markdown parsers
│   ├── reader/                 # DOCX reader/editor
│   └── utils/                  # Image resolution, helpers
```

### Document Pipeline

```
Input Source          Parser              AST                   Exporter
─────────────   →   ─────────────   →   ─────────────   →   ─────────────
HTML String         DocxParser          DocxNode[]           DocxExporter
Markdown String     MarkdownParser      DocxParagraph        → .docx file
Builder API         DocxBuilder         DocxTable            → Uint8List
Existing DOCX       DocxReader          DocxList             
                                        DocxShape
```

---

## AST Node Types

### Node Hierarchy

```
DocxNode (abstract)
├── DocxBlock (abstract) - Block-level elements
│   ├── DocxParagraph - Text paragraphs with inline children
│   ├── DocxTable - Tables with rows and cells
│   ├── DocxList - Ordered/unordered lists
│   ├── DocxImage - Block-level images
│   ├── DocxShapeBlock - Block-level shapes
│   ├── DocxSectionBreakBlock - Section breaks
│   └── DocxDropCap - Drop cap paragraph
│
├── DocxInline (abstract) - Inline elements
│   ├── DocxText - Formatted text runs
│   ├── DocxInlineImage - Inline images
│   ├── DocxTab - Tab character
│   ├── DocxFootnoteRef - Footnote reference
│   ├── DocxEndnoteRef - Endnote reference
│   └── DocxRawInline - Raw XML passthrough
│
└── DocxListItem - List item wrapper
└── DocxFootnote - Footnote definition
└── DocxEndnote - Endnote definition
```

### DocxText Properties

| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | The text content |
| `fontWeight` | `DocxFontWeight` | `normal`, `bold` |
| `fontStyle` | `DocxFontStyle` | `normal`, `italic` |
| `decoration` | `DocxTextDecoration` | `none`, `underline`, `strikethrough` |
| `color` | `DocxColor?` | Text color |
| `shadingFill` | `String?` | Background color (hex) |
| `fontSize` | `double?` | Size in points |
| `fontFamily` | `String?` | Font family name |
| `highlight` | `DocxHighlight` | Highlight color enum |
| `href` | `String?` | Hyperlink URL |
| `isSuperscript` | `bool` | Superscript text |
| `isSubscript` | `bool` | Subscript text |
| `isAllCaps` | `bool` | ALL CAPS effect |
| `isSmallCaps` | `bool` | Small caps effect |
| `isDoubleStrike` | `bool` | Double strikethrough |
| `isOutline` | `bool` | Outline effect |
| `isShadow` | `bool` | Shadow effect |
| `isEmboss` | `bool` | Emboss effect |
| `isImprint` | `bool` | Imprint effect |
| `textBorder` | `DocxBorderSide?` | Text border |
| `themeColor` | `String?` | Theme color reference (e.g. 'accent1') |
| `themeTint` | `String?` | Theme color tint (hex) |
| `themeShade` | `String?` | Theme color shade (hex) |
| `characterSpacing` | `int?` | Character spacing in twips |

### DocxParagraph Properties

| Property | Type | Description |
|----------|------|-------------|
| `children` | `List<DocxInline>` | Inline content |
| `align` | `DocxAlign` | `left`, `center`, `right`, `justify` |
| `spacing` | `DocxSpacing?` | Before/after spacing |
| `lineSpacing` | `int?` | Line spacing amount (twips) |
| `lineRule` | `String?` | `auto`, `exact`, `atLeast` |
| `pageBreakBefore` | `bool` | Page break before paragraph |
| `shadingFill` | `String?` | Background shading |

---

## HTML Parser - Complete Guide

### Usage

```dart
import 'package:docx_creator/docx_creator.dart';

Future<void> parseHtml() async {
  final html = '<h1>Title</h1><p>Content</p>';
  final nodes = await DocxParser.fromHtml(html);
  final doc = DocxBuiltDocument(elements: nodes);
  await DocxExporter().exportToFile(doc, 'output.docx');
}
```

### Complete Tag Support

#### Block Elements

| HTML Tag | DOCX Output | Notes |
|----------|-------------|-------|
| `<h1>` - `<h6>` | Heading styles | Font sizes: 24, 20, 16, 14, 12, 11pt |
| `<p>` | `DocxParagraph` | With style inheritance |
| `<div>` | `DocxParagraph` | With background support |
| `<blockquote>` | Indented paragraph | Left indent 720 twips |
| `<pre>` | Code block | Monospace, gray background |
| `<ul>` | Bullet list | Supports nesting |
| `<ol>` | Numbered list | Supports nesting |
| `<table>` | `DocxTable` | With styling |
| `<hr>` | Horizontal rule | Bottom border |

#### Inline Elements

| HTML Tag | DOCX Output | Notes |
|----------|-------------|-------|
| `<b>`, `<strong>` | Bold | `fontWeight: bold` |
| `<i>`, `<em>` | Italic | `fontStyle: italic` |
| `<u>` | Underline | `decoration: underline` |
| `<s>`, `<del>`, `<strike>` | Strikethrough | `decoration: strikethrough` |
| `<mark>` | Highlight | Yellow background |
| `<sup>` | Superscript | `isSuperscript: true` |
| `<sub>` | Subscript | `isSubscript: true` |
| `<code>` | Inline code | Monospace, gray shading |
| `<a href="">` | Hyperlink | Blue, underlined |
| `<br>` | Line break | `DocxLineBreak` |
| `<img>` | Image | Fetches remote images |
| `<span>` | Styled text | CSS property inheritance |

### CSS Property Support

#### Text Properties

```css
/* Colors */
color: red;                    /* Named color */
color: #FF5722;               /* Hex (6-digit) */
color: rgb(255, 87, 34);      /* RGB */

/* Background */
background-color: yellow;
background-color: #FFFF00;

/* Font */
font-size: 16px;              /* Converted to points */
font-size: 12pt;              /* Direct points */
font-weight: bold;
font-style: italic;
font-family: Arial;

/* Text decoration */
text-decoration: underline;
text-decoration: line-through;
```

#### Layout Properties

```css
text-align: left;
text-align: center;
text-align: right;
text-align: justify;

/* Table cells */
vertical-align: top;
vertical-align: middle;
vertical-align: bottom;
```

### All 141 CSS Named Colors

The parser supports all W3C CSS3 Extended Color Keywords:

**Basic Colors:**
`black`, `white`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`

**Extended Colors (sample):**
`aliceblue`, `antiquewhite`, `aqua`, `aquamarine`, `azure`, `beige`, `bisque`, `blanchedalmond`, `blueviolet`, `brown`, `burlywood`, `cadetblue`, `chartreuse`, `chocolate`, `coral`, `cornflowerblue`, `cornsilk`, `crimson`, `darkblue`, `darkcyan`, `darkgoldenrod`, `darkgray`, `darkgreen`, `darkkhaki`, `darkmagenta`, `darkolivegreen`, `darkorange`, `darkorchid`, `darkred`, `darksalmon`, `darkseagreen`, `darkslateblue`, `darkslategray`, `darkturquoise`, `darkviolet`, `deeppink`, `deepskyblue`, `dimgray`, `dodgerblue`, `firebrick`, `floralwhite`, `forestgreen`, `fuchsia`, `gainsboro`, `ghostwhite`, `gold`, `goldenrod`, `gray`, `greenyellow`, `honeydew`, `hotpink`, `indianred`, `indigo`, `ivory`, `khaki`, `lavender`, `lavenderblush`, `lawngreen`, `lemonchiffon`, `lightblue`, `lightcoral`, `lightcyan`, `lightgoldenrodyellow`, `lightgray`, `lightgreen`, `lightpink`, `lightsalmon`, `lightseagreen`, `lightskyblue`, `lightslategray`, `lightsteelblue`, `lightyellow`, `lime`, `limegreen`, `linen`, `maroon`, `mediumaquamarine`, `mediumblue`, `mediumorchid`, `mediumpurple`, `mediumseagreen`, `mediumslateblue`, `mediumspringgreen`, `mediumturquoise`, `mediumvioletred`, `midnightblue`, `mintcream`, `mistyrose`, `moccasin`, `navajowhite`, `navy`, `oldlace`, `olive`, `olivedrab`, `orange`, `orangered`, `orchid`, `palegoldenrod`, `palegreen`, `paleturquoise`, `palevioletred`, `papayawhip`, `peachpuff`, `peru`, `pink`, `plum`, `powderblue`, `purple`, `rebeccapurple`, `rosybrown`, `royalblue`, `saddlebrown`, `salmon`, `sandybrown`, `seagreen`, `seashell`, `sienna`, `silver`, `skyblue`, `slateblue`, `slategray`, `snow`, `springgreen`, `steelblue`, `tan`, `teal`, `thistle`, `tomato`, `turquoise`, `violet`, `wheat`, `whitesmoke`, `yellowgreen`

**Grey/Gray Variations:**
Both spellings supported: `grey`/`gray`, `darkgrey`/`darkgray`, `lightgrey`/`lightgray`, etc.

### CSS Classes Support

```html
<style>
  .highlight { background-color: yellow; }
  .error { color: red; font-weight: bold; }
  .center { text-align: center; }
</style>

<p class="highlight">Highlighted text</p>
<p class="error">Error message</p>
<p class="center">Centered text</p>
```

### Color Synchronization

When using both foreground and background colors, ensure sufficient contrast:

```html
<!-- Good: Dark text on light background -->
<span style="background-color: yellow; color: black;">Visible</span>

<!-- Good: Light text on dark background -->
<span style="background-color: #333; color: white;">Visible</span>

<!-- Bad: Light on light (invisible) -->
<span style="background-color: white; color: yellow;">Hard to read</span>
```

### Image Handling

```html
<!-- Remote images (fetched via HTTP) -->
<img src="https://example.com/image.png" width="200" height="100" />

<!-- Base64 images -->
<img src="data:image/png;base64,iVBORw0KGgo..." />

<!-- Placeholder for missing images -->
<img src="invalid.png" alt="Missing image" />
```

---

## Markdown Parser - Complete Guide

### Usage

```dart
import 'package:docx_creator/docx_creator.dart';

Future<void> parseMarkdown() async {
  final md = '# Title\n\nParagraph with **bold**.';
  final nodes = await MarkdownParser.parse(md);
  final doc = DocxBuiltDocument(elements: nodes);
  await DocxExporter().exportToFile(doc, 'output.docx');
}
```

### Complete Syntax Support

#### Headings

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

#### Text Formatting

```markdown
**bold text**
__bold text__
*italic text*
_italic text_
***bold and italic***
~~strikethrough~~
`inline code`
```

#### Links

```markdown
[Link text](https://example.com)
[Link with title](https://example.com "Title")
```

#### Lists

```markdown
# Bullet Lists
- Item 1
- Item 2
  - Nested item
  - Another nested
    - Deep nested
- Item 3

# Numbered Lists
1. First
2. Second
3. Third

# Task Lists
- [ ] Unchecked task
- [x] Completed task
```

#### Nested List Export

Nested lists are converted to OOXML multi-level numbering:

```markdown
- Level 0
    - Level 1
        - Level 2
```

Becomes:

```xml
<w:p>
  <w:pPr>
    <w:numPr>
      <w:ilvl w:val="0"/>  <!-- Level 0 -->
      <w:numId w:val="1"/>
    </w:numPr>
  </w:pPr>
  ...
</w:p>
```

#### Code Blocks

````markdown
Inline: `code here`

Fenced block:
```dart
void main() {
  print('Hello');
}
```

Indented block:
    void main() {
      print('Hello');
    }
````

#### Blockquotes

```markdown
> Simple quote

> Multi-line
> blockquote

> > Nested quote
```

#### Tables

```markdown
| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |

# With alignment
| Left | Center | Right |
|:-----|:------:|------:|
| L    |   C    |     R |
```

#### Horizontal Rules

```markdown
---
***
___
```

---

## DOCX Reader & Editor - Complete Guide

### Loading Documents

```dart
import 'dart:io';
import 'package:docx_creator/docx_creator.dart';

Future<void> loadDocument() async {
  // Method 1: From file path
  final doc = await DocxReader.load('document.docx');
  
  // Method 2: From bytes
  final bytes = await File('document.docx').readAsBytes();
  final doc = await DocxReader.loadFromBytes(bytes);
}
```

### What Gets Preserved

| Element | Preserved | Notes |
|---------|-----------|-------|
| Paragraphs | ✅ | Full formatting |
| Text runs | ✅ | Bold, italic, colors, etc. |
| Hyperlinks | ✅ | URL and display text |
| Lists | ✅ | Bullet and numbered |
| Nested lists | ✅ | Multi-level support |
| Tables | ✅ | Rows, cells, styling |
| Images | ✅ | Embedded as bytes |
| Shapes | ✅ | Full DrawingML support |
| Headers/Footers | ✅ | Content preserved |
| Styles XML | ✅ | For round-trip |
| Numbering XML | ✅ | List definitions |
| Embedded Fonts | ✅ | Preserved with original filenames |
| Relationships | ✅ | Preserved for validity |
| Section properties | ✅ | Page layout |

### Accessing Document Elements

```dart
final doc = await DocxReader.load('document.docx');

for (final element in doc.elements) {
  switch (element) {
    case DocxParagraph paragraph:
      print('Paragraph: ${paragraph.align}');
      for (final inline in paragraph.children) {
        if (inline is DocxText) {
          print('  Text: "${inline.content}"');
          print('  Bold: ${inline.fontWeight == DocxFontWeight.bold}');
          print('  Color: ${inline.color?.hex}');
          print('  Link: ${inline.href}');
        } else if (inline is DocxShape) {
          print('  Shape: ${inline.preset}');
        } else if (inline is DocxInlineImage) {
          print('  Image: ${inline.extension}');
        }
      }
      break;
      
    case DocxTable table:
      print('Table: ${table.rows.length} rows');
      for (final row in table.rows) {
        for (final cell in row.cells) {
          print('  Cell content: ${cell.children.length} elements');
        }
      }
      break;
      
    case DocxList list:
      print('List: ${list.isOrdered ? "numbered" : "bullet"}');
      for (final item in list.items) {
        print('  Item level ${item.level}');
      }
      break;
      
    case DocxShapeBlock shape:
      print('Block shape: ${shape.shape.preset}');
      break;
  }
}
```

### Modifying Text Content

```dart
// Find and replace all occurrences
DocxBuiltDocument findReplace(DocxBuiltDocument doc, String find, String replace) {
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
    stylesXml: doc.stylesXml,
    numberingXml: doc.numberingXml,
  );
}
```

### Adding New Content

```dart
final doc = await DocxReader.load('template.docx');

// Create mutable list from elements
final elements = List<DocxNode>.from(doc.elements);

// Add new content
elements.add(DocxParagraph.heading2('New Section'));
elements.add(DocxParagraph.text('Added on ${DateTime.now()}'));
elements.add(DocxList.bullet(['Point 1', 'Point 2', 'Point 3']));

// Create new document
final output = DocxBuiltDocument(
  elements: elements,
  section: doc.section,
  stylesXml: doc.stylesXml,
  numberingXml: doc.numberingXml,
);

await DocxExporter().exportToFile(output, 'modified.docx');
```

### Extracting Text

```dart
String extractAllText(DocxBuiltDocument doc) {
  final buffer = StringBuffer();
  
  for (final element in doc.elements) {
    if (element is DocxParagraph) {
      for (final child in element.children) {
        if (child is DocxText) {
          buffer.write(child.content);
        }
      }
      buffer.writeln();
    } else if (element is DocxList) {
      for (final item in element.items) {
        buffer.write('• ');
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
```

### Complete Round-Trip Example

```dart
Future<void> roundTripExample() async {
  // 1. Load original document
  final original = await DocxReader.load('report.docx');
  print('Loaded ${original.elements.length} elements');
  
  // 2. Process elements
  final modified = <DocxNode>[];
  
  // Add header
  modified.add(DocxParagraph(children: [
    DocxText('MODIFIED DOCUMENT',
        fontWeight: DocxFontWeight.bold,
        color: DocxColor.red,
        fontSize: 18),
  ], align: DocxAlign.center));
  
  modified.add(DocxParagraph.text('Modified: ${DateTime.now()}'));
  modified.add(DocxParagraph(borderBottom: DocxBorder.single, children: []));
  
  // Keep original content
  modified.addAll(original.elements);
  
  // Add footer
  modified.add(DocxParagraph(borderBottom: DocxBorder.single, children: []));
  modified.add(DocxParagraph.text('End of document'));
  
  // 3. Create new document with preserved metadata
  final output = DocxBuiltDocument(
    elements: modified,
    section: original.section,
    stylesXml: original.stylesXml,
    numberingXml: original.numberingXml,
    settingsXml: original.settingsXml,
    fontTableXml: original.fontTableXml,
  );
  
  // 4. Export
  await DocxExporter().exportToFile(output, 'report_modified.docx');
  print('Saved modified document');
}
```

---

## PDF Reader - Complete Guide

### Overview

The `PdfReader` parses PDF documents and converts them into editable DOCX structures or extracts text and images for analysis. Version 1.2.0 includes major improvements for broader PDF compatibility including PDF 1.5+ features.

### Usage

```dart
import 'package:docx_creator/docx_creator.dart';

Future<void> convertPdf() async {
  // Load from file path
  final pdf = await PdfReader.load('input.pdf');
  
  // Or load from bytes
  final bytes = await File('input.pdf').readAsBytes();
  final pdf = await PdfReader.loadFromBytes(bytes);
  
  // Check for warnings
  if (pdf.warnings.isNotEmpty) {
    print('Warnings: ${pdf.warnings.join('\n')}');
  }
  
  // Convert to DOCX AST
  final doc = pdf.toDocx();
  
  // Save as DOCX or PDF
  await DocxExporter().exportToFile(doc, 'converted.docx');
  await PdfExporter().exportToFile(doc, 'converted.pdf');
}
```

### PdfDocument Properties

| Property | Type | Description |
|----------|------|-------------|
| `elements` | `List<DocxNode>` | Document structure (paragraphs, tables, images) |
| `images` | `List<PdfExtractedImage>` | Quick access to all extracted images |
| `text` | `String` | Plain text content of entire document |
| `pageCount` | `int` | Total pages in the PDF |
| `pageWidth` | `double` | Page width in points (612 for Letter) |
| `pageHeight` | `double` | Page height in points (792 for Letter) |
| `version` | `String` | PDF version (e.g., "1.4", "1.5") |
| `warnings` | `List<String>` | Any parsing warnings |

### Content Extraction

```dart
final pdf = await PdfReader.loadFromBytes(pdfBytes);

print('PDF ${pdf.version}, ${pdf.pageCount} pages');
print('Size: ${pdf.pageWidth} x ${pdf.pageHeight} points');

// Iterate over extracted elements
for (final element in pdf.elements) {
  if (element is DocxParagraph) {
    for (final child in element.children) {
      if (child is DocxText) {
        print('Text: ${child.content}');
        print('  Bold: ${child.fontWeight == DocxFontWeight.bold}');
        print('  Size: ${child.fontSize}');
        print('  Color: ${child.color?.hex}');
      }
    }
  } else if (element is DocxImage) {
    print('Image: ${element.bytes.length} bytes');
  } else if (element is DocxTable) {
    print('Table: ${element.rows.length} rows');
  }
}

// Get all text as plain string
final allText = pdf.text;
```

### Image Extraction

Images are automatically extracted and encoded as PNG for direct use in Flutter:

```dart
final pdf = await PdfReader.loadFromBytes(pdfBytes);

// Quick access to all images
for (final img in pdf.images) {
  print('${img.width}x${img.height}, ${img.format}');
  
  // Images are ready to use
  // In Flutter: Image.memory(img.bytes)
  
  // Save to file
  await File('image_${pdf.images.indexOf(img)}.png')
      .writeAsBytes(img.bytes);
}

// Images are also in elements list as DocxImage
for (final element in pdf.elements) {
  if (element is DocxImage) {
    // element.bytes contains PNG-encoded image data
    // element.extension is 'png' or 'jpeg'
  }
}
```

### Supported PDF Features

| Feature | Status | Notes |
|---------|--------|-------|
| **PDF Versions** | | |
| PDF 1.0-1.4 (traditional xref) | ✅ | Full support |
| PDF 1.5+ (xref streams) | ✅ | Added in v1.2.0 |
| PDF 1.5+ (object streams) | ✅ | Added in v1.2.0 |
| **Compression** | | |
| FlateDecode (zlib) | ✅ | Most common |
| LZWDecode | ✅ | Added in v1.2.0 |
| ASCII85Decode | ✅ | |
| ASCIIHexDecode | ✅ | |
| **Content** | | |
| Text extraction | ✅ | With font info |
| Bold/Italic detection | ✅ | From font name |
| Font sizes and colors | ✅ | |
| Paragraph grouping | ✅ | Position-based |
| Table detection | ✅ | Beta, grid-based |
| **Images** | | |
| JPEG (DCTDecode) | ✅ | Native format |
| Raw RGB (FlateDecode) | ✅ | Encoded as PNG |
| Inline images | ✅ | |
| **Error Handling** | | |
| Fallback object scanning | ✅ | For corrupt xref |

### Understanding PDF Extraction

Since PDF is a fixed-layout format, the reader performs several reconstruction steps:

1. **Text Extraction**: Character codes are decoded using font encodings (WinAnsi, ToUnicode CMap).
2. **Position Sorting**: Text is sorted top-to-bottom, left-to-right.
3. **Paragraph Grouping**: Vertically aligned text is grouped into paragraphs.
4. **Table Detection**: Grid lines are analyzed to detect table structures.
5. **Image Decoding**: XObject images are decompressed and encoded as PNG.

### Limitations

| Limitation | Description |
|------------|-------------|
| **Scanned/Image PDFs** | If pages contain only images with no text operators, no text is extracted. Use OCR separately. |
| **Encrypted PDFs** | Password-protected PDFs are not supported. |
| **Complex layouts** | Multi-column layouts may not preserve exact positioning. |
| **Vector graphics** | Complex paths/drawings are not converted to shapes. |
| **Form fields** | Interactive form data is ignored. |
| **Type 3 fonts** | Custom glyph definitions may not render correctly. |

### Example: PDF to DOCX Conversion

```dart
Future<void> convertPdfToDocx(String inputPath, String outputPath) async {
  try {
    // Load PDF
    final pdf = await PdfReader.load(inputPath);
    
    print('Loaded PDF ${pdf.version}');
    print('${pdf.pageCount} pages, ${pdf.elements.length} elements');
    print('${pdf.images.length} images extracted');
    
    // Check warnings
    for (final warning in pdf.warnings) {
      print('Warning: $warning');
    }
    
    // Convert to DOCX
    final doc = pdf.toDocx();
    
    // Export
    await DocxExporter().exportToFile(doc, outputPath);
    print('Saved to $outputPath');
    
  } on PdfParseException catch (e) {
    print('Failed to parse PDF: ${e.message}');
  }
}
```

---

## PDF Export - Complete Guide

### Overview

The `PdfExporter` class provides pure Dart PDF generation from DocxBuiltDocument objects. No native dependencies are required.

### Basic Usage

```dart
import 'package:docx_creator/docx_creator.dart';

Future<void> exportToPdf() async {
  // Create document
  final doc = docx()
    .h1('PDF Export Demo')
    .p('This document will be exported to PDF.')
    .build();

  // Export to file
  await PdfExporter().exportToFile(doc, 'output.pdf');
  
  // Or get as bytes
  final pdfBytes = PdfExporter().exportToBytes(doc);
}
```

### Architecture

```
PdfExporter
├── PdfLayoutEngine      # Page layout and positioning
├── PdfContentBuilder    # PDF content stream operations
└── PdfFontManager       # Font selection and text measurement
```

### Supported Elements

| Element | Support | Notes |
|---------|---------|-------|
| `DocxParagraph` | ✅ | Full text formatting |
| `DocxText` | ✅ | Bold, italic, underline, strikethrough |
| `DocxTable` | ✅ | Borders, cell backgrounds |
| `DocxList` | ✅ | Bullet and numbered |
| `DocxImage` | ✅ | PNG format |
| `DocxSectionBreak` | ✅ | Page breaks |

### Text Formatting

The PDF exporter supports all common text formatting:

```dart
DocxParagraph(children: [
  DocxText('Bold', fontWeight: DocxFontWeight.bold),
  DocxText('Italic', fontStyle: DocxFontStyle.italic),
  DocxText('Underline', decoration: DocxTextDecoration.underline),
  DocxText('Strikethrough', decoration: DocxTextDecoration.strikethrough),
  DocxText('Red text', color: DocxColor.red),
  DocxText('Background', shadingFill: 'FFFF00'),
  DocxText('Large', fontSize: 24),
  DocxText('2', isSuperscript: true),
  DocxText('2', isSubscript: true),
])
```

### Page Sizes

The exporter supports standard page sizes via section definitions:

```dart
final doc = docx()
  .section(pageSize: DocxPageSize.a4)
  .h1('A4 Document')
  .p('Content...')
  .build();
```

Supported sizes: `DocxPageSize.letter`, `DocxPageSize.a4`

### Font Metrics

The PDF exporter uses accurate Helvetica font metrics:

- Per-character width measurement (95+ ASCII characters)
- Bold font scaling (1.05x width factor)
- Proper space width (0.278 em)
- Mixed font size line height calculation

### Comparison with DocxExporter

| Feature | DocxExporter | PdfExporter |
|---------|--------------|-------------|
| Output Format | .docx (Word) | .pdf |
| Editable | ✅ | ❌ |
| Embedded Fonts | ✅ | ❌ (Helvetica only) |
| Shapes | ✅ | ❌ |
| Custom Styles | ✅ | ❌ |
| Page Layout | ✅ | ✅ |
| Tables | ✅ | ✅ |
| Lists | ✅ | ✅ |
| Images | ✅ | ✅ (PNG) |

---

## Drawing & Shapes - Complete Guide

### Shape Classes

```dart
// Block-level shape (own paragraph)
DocxShapeBlock.rectangle(...)

// Inline shape (within paragraph)
DocxShape.circle(...)
```

### All Factory Constructors

```dart
// Rectangles
DocxShapeBlock.rectangle(width, height, fillColor, outlineColor, text)
DocxShape.roundedRectangle(width, height, fillColor)

// Ellipses
DocxShapeBlock.ellipse(width, height, fillColor)
DocxShapeBlock.circle(diameter, fillColor)

// Polygons
DocxShapeBlock.triangle(width, height, fillColor)
DocxShapeBlock.diamond(width, height, fillColor)

// Stars
DocxShapeBlock.star(points: 4|5|6, width, height, fillColor)

// Arrows
DocxShapeBlock.rightArrow(width, height, fillColor)
DocxShapeBlock.leftArrow(width, height, fillColor)

// Lines
DocxShape.line(width, outlineColor, outlineWidth)
```

### Shape Preset Reference

All 70+ preset shapes from OOXML:

**Basic Shapes:**
`rect`, `roundRect`, `ellipse`, `triangle`, `rtTriangle`, `parallelogram`, `trapezoid`, `diamond`, `pentagon`, `hexagon`, `octagon`

**Stars & Banners:**
`star4`, `star5`, `star6`, `star8`, `star10`, `star12`, `star16`, `star24`, `star32`, `ribbon`, `ribbon2`, `wave`, `doubleWave`

**Arrows:**
`rightArrow`, `leftArrow`, `upArrow`, `downArrow`, `leftRightArrow`, `upDownArrow`, `bentArrow`, `curvedRightArrow`, `curvedLeftArrow`

**Flowchart:**
`flowChartProcess`, `flowChartDecision`, `flowChartTerminator`, `flowChartDocument`, `flowChartPreparation`, `flowChartManualInput`, `flowChartConnector`

**Callouts:**
`callout1`, `callout2`, `callout3`, `cloudCallout`, `wedgeRectCallout`, `wedgeRoundRectCallout`, `wedgeEllipseCallout`

### Shape Properties

```dart
DocxShape(
  width: 200,              // Points
  height: 100,             // Points
  preset: DocxShapePreset.rect,
  position: DocxDrawingPosition.inline,  // or .floating
  fillColor: DocxColor.blue,
  outlineColor: DocxColor.black,
  outlineWidth: 2,         // Points
  text: 'Label',           // Text inside shape
  rotation: 45,            // Degrees
  
  // Floating position properties
  horizontalFrom: DocxHorizontalPositionFrom.column,
  verticalFrom: DocxVerticalPositionFrom.paragraph,
  horizontalAlign: DrawingHAlign.center,
  verticalAlign: DrawingVAlign.top,
  textWrap: DocxTextWrap.square,
  behindDocument: false,
)
```

---

---

## Advanced Features

### Drop Caps

Create a paragraph with a large initial letter:

```dart
DocxDropCap(
  letter: 'O',
  lines: 3,  // Drop over 3 lines
  fontFamily: 'Algerian',
  restOfParagraph: [DocxText('nce upon a time...')],
)
```

### Floating Images

Position images anywhere on the page:

```dart
DocxParagraph(
  children: [
    DocxText('Text wrapping around...'),
    DocxInlineImage(
       bytes: imageBytes,
       extension: 'png',
       positionMode: DocxDrawingPosition.floating,
       x: 100, // Points from left column
       y: 50,  // Points from paragraph top
       textWrap: DocxTextWrap.square,
    ),
  ]
)
```

### Footnotes & Endnotes

Docs can now include footnotes and endnotes programmatically or preserve them from existing documents.

#### Programmatic Creation

```dart
final doc = docx()
  .p('Main text content.')
  
  // Add a footnote
  .addFootnote(DocxFootnote(
    footnoteId: 1, // Unique internal ID
    content: [
      DocxParagraph.text('This is a footnote at the bottom of the page.'),
    ],
  ))
  
  // Add an endnote
  .addEndnote(DocxEndnote(
    endnoteId: 1, // Unique internal ID
    content: [
      DocxParagraph.text('This is an endnote at the end of the document.'),
    ],
  ))
  .build();
```

#### Round-Trip Preservation

When reading an existing DOCX file, `footnotes.xml` and `endnotes.xml` are parsed into `DocxFootnote` and `DocxEndnote` objects. These are preserved and re-exported when saving the document, ensuring no data loss.

### Text Borders

Apply borders to specific text runs:

```dart
DocxText(
  'Boxed Text',
  textBorder: DocxBorderSide(style: DocxBorder.single, color: DocxColor.red),
)
```

### Table Styles & Conditionals

Apply named styles and conditional formatting:

```dart
DocxTable(
  rows: [...],
  styleId: 'GridTable4-Accent1',
  look: DocxTableLook(
    firstRow: true,
    lastRow: true,
    firstColumn: true,
    noHBand: false,
  ),
)
```

The parser provides **High-Fidelity Resolution** for these properties. It correctly resolves complex conflicts between:
- Cell-level borders/shading
- Table-level borders/shading
- Named Table Style definitions (including conditional formatting)
- Document defaults

This ensures that tables render exactly as they appear in Microsoft Word during read/edit operations, preserving all visual styling details.

---

## OpenXML Internals

### DOCX Structure

A DOCX file is a ZIP archive containing:

```
document.docx/
├── [Content_Types].xml        # File type declarations
├── _rels/
│   └── .rels                  # Root relationships
├── word/
│   ├── document.xml           # Main content
│   ├── styles.xml             # Style definitions
│   ├── numbering.xml          # List definitions
│   ├── settings.xml           # Document settings
│   ├── fontTable.xml          # Font declarations
│   ├── header1.xml            # Header content
│   ├── footer1.xml            # Footer content
│   ├── _rels/
│   │   └── document.xml.rels  # Document relationships
│   └── media/                 # Embedded images
│       ├── image1.png
│       └── font1.odttf        # Obfuscated fonts
└── docProps/
    ├── core.xml               # Metadata
    └── app.xml                # Application info
```

### Font Obfuscation

Per the OpenXML ECMA-376 specification, embedded fonts must be obfuscated:

```dart
// The first 32 bytes are XOR'd with a GUID-based key
String obfuscate(Uint8List fontBytes, String guidKey) {
  final key = _parseGuidToBytes(guidKey);
  for (var i = 0; i < 32; i++) {
    fontBytes[i] ^= key[i % 16];
  }
  return fontBytes;
}
```

### List Numbering

Lists use abstract numbering definitions with multi-level support:

```xml
<w:abstractNum w:abstractNumId="0">
  <w:multiLevelType w:val="hybridMultilevel"/>
  <w:lvl w:ilvl="0">
    <w:start w:val="1"/>
    <w:numFmt w:val="bullet"/>
    <w:lvlText w:val="•"/>
  </w:lvl>
  <w:lvl w:ilvl="1">
    <w:start w:val="1"/>
    <w:numFmt w:val="bullet"/>
    <w:lvlText w:val="◦"/>
  </w:lvl>
  <!-- Levels 2-8 -->
</w:abstractNum>
```

---

## Advanced Examples

### Kitchen Sink Example

```dart
import 'dart:io';
import 'package:docx_creator/docx_creator.dart';

Future<void> kitchenSinkExample() async {
  // Load custom font
  final fontBytes = await File('fonts/Roboto.ttf').readAsBytes();
  
  // Parse HTML content
  final htmlSection = await DocxParser.fromHtml('''
    <div style="background-color: #f0f8ff;">
      <h2 style="color: navy;">HTML Section</h2>
      <p>This is <span style="color: dodgerblue;">parsed from HTML</span>.</p>
      <table border="1">
        <tr style="background: #4472C4; color: white;">
          <th>Feature</th><th>Status</th>
        </tr>
        <tr><td>Tables</td><td style="color: green;">✓</td></tr>
        <tr><td>Colors</td><td style="color: green;">✓</td></tr>
      </table>
    </div>
  ''');
  
  // Build complete document
  final doc = DocxDocumentBuilder()
    // Custom font
    .addFont('Roboto', fontBytes)
    
    // Section settings
    .section(
      orientation: DocxPageOrientation.portrait,
      pageSize: DocxPageSize.a4,
      backgroundColor: DocxColor('#FAFAFA'),
      header: DocxHeader(children: [
        DocxParagraph.text('Company Report 2024', align: DocxAlign.right),
      ]),
    )
    
    // Title
    .h1('Complete Document Example')
    .p('Demonstrating all docx_creator features.')
    
    // Text formatting
    .h2('Text Formatting')
    .add(DocxParagraph(children: [
      DocxText('Bold, ', fontWeight: DocxFontWeight.bold),
      DocxText('Italic, ', fontStyle: DocxFontStyle.italic),
      DocxText('Color, ', color: DocxColor.red),
      DocxText('Highlight, ', highlight: DocxHighlight.yellow),
      DocxText('Custom Font', fontFamily: 'Roboto'),
    ]))
    
    // Nested list
    .h2('Complex Lists')
    .add(DocxList(
      style: DocxListStyle.disc,
      items: [
        DocxListItem.text('Main Topic 1', level: 0),
        DocxListItem.text('Subtopic 1.1', level: 1),
        DocxListItem.text('Detail 1.1.1', level: 2),
        DocxListItem.text('Detail 1.1.2', level: 2),
        DocxListItem.text('Subtopic 1.2', level: 1),
        DocxListItem.text('Main Topic 2', level: 0),
      ],
    ))
    
    // Shapes
    .h2('Shapes & Drawings')
    .add(DocxParagraph(children: [
      DocxShape.circle(diameter: 40, fillColor: DocxColor.red),
      DocxText(' '),
      DocxShape.star(points: 5, fillColor: DocxColor.gold),
      DocxText(' '),
      DocxShape.rightArrow(width: 60, height: 30, fillColor: DocxColor.blue),
    ]))
    
    // Page break before HTML section
    .pageBreak()
    .build();
  
  // Add HTML section
  final elements = List<DocxNode>.from(doc.elements);
  elements.addAll(htmlSection);
  
  // Create final document
  final finalDoc = DocxBuiltDocument(
    elements: elements,
    section: doc.section,
    fonts: doc.fonts,
  );
  
  await DocxExporter().exportToFile(finalDoc, 'kitchen_sink.docx');
}
```

---

## Troubleshooting

### Font Issues

**Problem:** Custom fonts don't display in Word

**Solution:**
1. Ensure font is embedded with `addFont()`
2. Reference the exact family name in `fontFamily`
3. Font files must be `.ttf` or `.otf`

```dart
final fontBytes = await File('fonts/CustomFont-Regular.ttf').readAsBytes();
docx()
  .addFont('CustomFont', fontBytes)
  .add(DocxParagraph(children: [
    DocxText('Custom text', fontFamily: 'CustomFont'),
  ]))
  .build();
```

### Image Issues

**Problem:** Images don't appear

**Solutions:**
1. Verify bytes are valid image data
2. Use correct extension (`png`, `jpg`, `gif`)
3. For remote images in HTML, ensure network access

```dart
// Debug: Check image bytes
print('Image size: ${imageBytes.length} bytes');
print('First bytes: ${imageBytes.take(8).toList()}');
// PNG starts with: [137, 80, 78, 71, 13, 10, 26, 10]
// JPEG starts with: [255, 216, 255, ...]
```

### List Issues

**Problem:** Lists don't have bullets/numbers

**Solution:** Use proper list construction:

```dart
// Correct: Using factory constructors
DocxList.bullet(['Item 1', 'Item 2'])
DocxList.numbered(['Step 1', 'Step 2'])

// Correct: Manual with proper style
DocxList(
  style: DocxListStyle.disc,  // Not just DocxListStyle()
  items: [DocxListItem.text('Item')],
)
```

### Color Issues

**Problem:** Background color makes text invisible

**Solution:** Always pair background with contrasting text color:

```dart
// Wrong: Light text on light background
DocxText('Invisible', shadingFill: 'FFFFFF', color: DocxColor.white)

// Right: Dark text on light background
DocxText('Visible', shadingFill: 'FFFF00', color: DocxColor.black)
```

### Round-Trip Issues

**Problem:** Formatting lost after load/save

**Solution:** Preserve all metadata fields:

```dart
final doc = await DocxReader.load('input.docx');

final output = DocxBuiltDocument(
  elements: modifiedElements,
  section: doc.section,          // ← Important
  stylesXml: doc.stylesXml,      // ← Important
  numberingXml: doc.numberingXml, // ← Important
  settingsXml: doc.settingsXml,  // ← Important
);
```

---

## Version History

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT License - see [LICENSE](LICENSE) for details.
