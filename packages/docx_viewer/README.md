# docx_viewer

[![pub package](https://img.shields.io/pub/v/docx_viewer.svg)](https://pub.dev/packages/docx_viewer)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue)](https://flutter.dev)

A **native Flutter DOCX viewer** that renders Word documents using Flutter widgets. No WebView, no PDF conversion—just pure Flutter rendering for maximum performance.

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎯 **Native Rendering** | Pure Flutter widgets, no WebView or PDF |
| 📖 **Full DOCX Support** | Paragraphs, tables, lists, images, shapes |
| 🔍 **Search** | Find and highlight text in documents |
| 🔎 **Zoom** | Pinch-to-zoom with InteractiveViewer |
| ✂️ **Selection** | Select and copy text |
| 🎨 **Theming** | Light/dark themes, customizable |
| 🔤 **Fonts** | Embedded font loading with OOXML deobfuscation |

## 📦 Installation

```yaml
dependencies:
  docx_viewer: ^1.0.0
```

## 🚀 Quick Start

```dart
import 'package:docx_viewer/docx_viewer.dart';

// From file
DocxView.file(myFile)

// From bytes
DocxView.bytes(docxBytes)

// From path
DocxView.path('/path/to/document.docx')

// With configuration
DocxView(
  file: myFile,
  config: DocxViewConfig(
    enableSearch: true,
    enableZoom: true,
    theme: DocxViewTheme.light(),
    customFontFallbacks: ['Roboto', 'Arial'],
  ),
)
```

## 📖 Usage

### Basic Viewer

```dart
Scaffold(
  body: DocxView.file(
    File('document.docx'),
    config: DocxViewConfig(
      enableZoom: true,
      backgroundColor: Colors.white,
    ),
  ),
)
```

### With Search Bar

```dart
Scaffold(
  body: DocxViewWithSearch(
    file: myDocxFile,
    config: DocxViewConfig(
      enableSearch: true,
      searchHighlightColor: Colors.yellow,
    ),
  ),
)
```

### Dark Theme

```dart
DocxView(
  bytes: docxBytes,
  config: DocxViewConfig(
    theme: DocxViewTheme.dark(),
    backgroundColor: Color(0xFF1E1E1E),
  ),
)
```

### With Search Controller

```dart
final searchController = DocxSearchController();

// Widget
DocxView(
  file: myFile,
  searchController: searchController,
)

// Programmatic control
searchController.search('keyword', textIndex);
searchController.nextMatch();
searchController.previousMatch();
searchController.clear();
```

## ⚙️ Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableSearch` | `bool` | `true` | Enable search |
| `enableZoom` | `bool` | `true` | Enable pinch-to-zoom |
| `enableSelection` | `bool` | `true` | Enable text selection |
| `minScale` | `double` | `0.5` | Minimum zoom scale |
| `maxScale` | `double` | `4.0` | Maximum zoom scale |
| `customFontFallbacks` | `List<String>` | `['Roboto', 'Arial', 'Helvetica']` | Font fallbacks |
| `theme` | `DocxViewTheme?` | Light | Rendering theme |
| `padding` | `EdgeInsets` | `16.0` | Document padding |
| `backgroundColor` | `Color?` | White | Background color |
| `searchHighlightColor` | `Color` | Yellow | Search highlight |

## 🎨 Theming

```dart
DocxViewTheme(
  defaultTextStyle: TextStyle(fontSize: 14, color: Colors.black87),
  headingStyles: {
    1: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    2: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    // ...
  },
  codeBlockBackground: Color(0xFFF5F5F5),
  codeTextStyle: TextStyle(fontFamily: 'monospace'),
  tableBorderColor: Color(0xFFDDDDDD),
  linkStyle: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
)

// Presets
DocxViewTheme.light()
DocxViewTheme.dark()
```

## 🔗 Integration with docx_creator

This package uses [docx_creator](https://pub.dev/packages/docx_creator) for parsing:

```dart
import 'package:docx_creator/docx_creator.dart';

// Create document
final doc = docx()
  .h1('Title')
  .p('Content')
  .build();

// Export to bytes
final bytes = await DocxExporter().exportToBytes(doc);

// View immediately
DocxView.bytes(bytes)
```

## 📋 Supported Elements

| Element | Support |
|---------|---------|
| Headings (H1-H6) | ✅ |
| Paragraphs | ✅ |
| Bold, Italic, Underline | ✅ |
| Colors & Backgrounds | ✅ |
| Hyperlinks | ✅ |
| Bullet Lists | ✅ |
| Numbered Lists | ✅ |
| Nested Lists | ✅ |
| Tables | ✅ |
| Images | ✅ |
| Shapes | ✅ |
| Code Blocks | ✅ |
| Embedded Fonts | ✅ |

## License

MIT License - see [LICENSE](LICENSE) for details.
