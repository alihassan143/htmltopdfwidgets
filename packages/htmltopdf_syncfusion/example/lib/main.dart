import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:htmltopdf_syncfusion/htmltopdf_syncfusion.dart' as lib;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML to PDF Syncfusion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HTML to PDF Syncfusion Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum EditorMode { html, markdown }

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  EditorMode _mode = EditorMode.html;

  String _htmlContent = '''
<h1>AppFlowyEditor</h1>
<h2>👋 <strong>Welcome to</strong> <strong><em><a href="appflowy.io">AppFlowy Editor</a></em></strong></h2>
  <p>AppFlowy Editor is a <strong>highly customizable</strong> <em>rich-text editor</em></p>
<hr />
<p><u>Here</u> is an example <del>your</del> you can give a try</p>
<br>
<span style="font-weight: bold;background-color: #cccccc;font-style: italic;">Span element</span>
<span style="font-weight: medium;text-decoration: underline;">Span element two</span>
</br>
<span style="font-weight: 900;text-decoration: line-through;">Span element three</span>
<a href="https://appflowy.io">This is an anchor tag!</a>
<img src="https://images.squarespace-cdn.com/content/v1/617f6f16b877c06711e87373/c3f23723-37f4-44d7-9c5d-6e2a53064ae7/Asset+10.png?format=1500w" />
<h3>Features!</h3>
<ul>
  <li>[x] Customizable</li>
  <li>[x] Test-covered</li>
  <li>[ ] more to come!</li>
</ul>
<ol>
  <li>First item</li>
  <li>Second item</li>
</ol>
<li>List element</li>
<blockquote>
  <p>This is a quote!</p>
</blockquote>
<code>
  Code block
</code>
<em>Italic one</em> <i>Italic two</i>
<b>Bold tag</b>
<img src="http://appflowy.io" alt="AppFlowy">
<p>You can also use <strong><em>AppFlowy Editor</em></strong> as a component to build your own app.</p>
<h3>Awesome features</h3>

<p>If you have questions or feedback, please submit an issue on Github or join the community along with 1000+ builders!</p>
  <h3>Checked Boxes</h3>
 <input type="checkbox" id="option2" checked> 
  <label for="option2">Option 2</label>
  <input type="checkbox" id="option3"> 
  <label for="option3">Option 3</label>
''';

  String _markdownContent = '''
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

  bool _isLoading = false;
  Uint8List? _pdfBytes;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _textController.text = _htmlContent;
    _generatePdf();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onModeChanged(Set<EditorMode> newSelection) {
    if (newSelection.isEmpty) return;
    final newMode = newSelection.first;
    if (_mode != newMode) {
      setState(() {
        _mode = newMode;
        _textController.text =
            _mode == EditorMode.html ? _htmlContent : _markdownContent;
      });
      _generatePdf();
    }
  }

  void _onContentChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_mode == EditorMode.html) {
        if (value != _htmlContent) {
          _htmlContent = value;
          _generatePdf();
        }
      } else {
        if (value != _markdownContent) {
          _markdownContent = value;
          _generatePdf();
        }
      }
    });
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final converter = lib.HtmlToPdf();
      Uint8List bytes;

      if (_mode == EditorMode.html) {
        // Use current text controller value to ensure sync
        bytes = await converter.convert(_textController.text);
      } else {
        bytes = await converter.convertMarkdown(_textController.text);
      }

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          // Left Side: Editor
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _mode == EditorMode.html
                            ? 'HTML Editor'
                            : 'Markdown Editor',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SegmentedButton<EditorMode>(
                        segments: const [
                          ButtonSegment(
                              value: EditorMode.html,
                              label: Text('HTML'),
                              icon: Icon(Icons.code)),
                          ButtonSegment(
                              value: EditorMode.markdown,
                              label: Text('Markdown'),
                              icon: Icon(Icons.description)),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _onModeChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      onChanged: _onContentChanged,
                      style:
                          const TextStyle(fontFamily: 'Courier', fontSize: 14),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: _mode == EditorMode.html
                            ? 'Enter HTML here...'
                            : 'Enter Markdown here...',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical Divider
          const VerticalDivider(width: 1, color: Colors.grey),
          // Right Side: Preview
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  if (_pdfBytes != null)
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      key: ValueKey(_pdfBytes.hashCode),
                    )
                  else
                    const Center(child: Text('Generate PDF to view preview')),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
