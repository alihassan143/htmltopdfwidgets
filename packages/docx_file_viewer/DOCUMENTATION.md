# docx_file_viewer Documentation

Complete technical documentation for the `docx_file_viewer` Flutter package.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Configuration](#configuration)
5. [Theming](#theming)
6. [Search Functionality](#search-functionality)
7. [View Modes](#view-modes)
8. [Widget Generation](#widget-generation)
9. [Font Handling](#font-handling)
10. [Advanced Usage](#advanced-usage)
11. [Performance Considerations](#performance-considerations)
12. [Troubleshooting](#troubleshooting)

---

## Overview

`docx_file_viewer` is a native Flutter package for rendering Microsoft Word DOCX documents. It converts DOCX files into Flutter widgets without relying on WebView or PDF conversion, providing:

- **High Fidelity** - Accurate rendering of text formatting, tables, lists, and images
- **Cross-Platform** - Works on iOS, Android, Web, macOS, Windows, and Linux
- **Performance** - Optimized widget generation with lazy building
- **Interactivity** - Search, zoom, selection, and hyperlink support

---

## Architecture

### Package Structure

```
lib/
├── docx_file_viewer.dart         # Public API exports
└── src/
    ├── docx_view.dart            # Main widget
    ├── docx_view_config.dart     # Configuration classes
    ├── font_loader/
    │   └── embedded_font_loader.dart
    ├── search/
    │   └── docx_search_controller.dart
    ├── theme/
    │   └── docx_view_theme.dart
    ├── utils/
    │   ├── block_index_counter.dart
    │   └── docx_units.dart
    ├── widget_generator/
    │   ├── docx_widget_generator.dart  # Core generator
    │   ├── paragraph_builder.dart
    │   ├── table_builder.dart
    │   ├── list_builder.dart
    │   ├── image_builder.dart
    │   └── shape_builder.dart
    └── widgets/
        └── drop_cap_text.dart
```

### Data Flow

```
DOCX File (bytes)
      ↓
DocxReader.loadFromBytes()     [docx_creator package]
      ↓
DocxBuiltDocument (AST)
      ↓
DocxWidgetGenerator.generateWidgets()
      ↓
List<Widget> (Flutter widgets)
      ↓
DocxView (renders to screen)
```

---

## Core Components

### DocxView

The main widget for displaying DOCX documents.

```dart
class DocxView extends StatefulWidget {
  final File? file;
  final Uint8List? bytes;
  final String? path;
  final DocxViewConfig config;
  final DocxSearchController? searchController;
  final VoidCallback? onLoaded;
  final void Function(Object error)? onError;
}
```

#### Factory Constructors

```dart
// From File object
DocxView.file(File file, {DocxViewConfig config, DocxSearchController? searchController})

// From raw bytes
DocxView.bytes(Uint8List bytes, {DocxViewConfig config, DocxSearchController? searchController})

// From file path
DocxView.path(String path, {DocxViewConfig config, DocxSearchController? searchController})
```

### DocxViewWithSearch

A convenience widget that wraps `DocxView` with a built-in search bar:

```dart
DocxViewWithSearch(
  file: myFile,
  config: DocxViewConfig(enableSearch: true),
)
```

Features:
- Floating action button to toggle search
- Text input with submit handler
- Previous/Next navigation buttons
- Match count display
- Close button to dismiss search

---

## Configuration

### DocxViewConfig

Complete configuration for the viewer:

```dart
const DocxViewConfig({
  bool enableSearch = true,
  bool enableZoom = true,
  bool enableSelection = true,
  double minScale = 0.5,
  double maxScale = 4.0,
  List<String> customFontFallbacks = const ['Roboto', 'Arial', 'Helvetica'],
  DocxViewTheme? theme,
  EdgeInsets padding = const EdgeInsets.all(16.0),
  Color? backgroundColor,
  bool showPageBreaks = true,
  bool showDebugInfo = false,
  Color searchHighlightColor = const Color(0xFFFFEB3B),
  Color currentSearchHighlightColor = const Color(0xFFFF9800),
  double? pageWidth,
  double? pageHeight,
  DocxPageMode pageMode = DocxPageMode.paged,
})
```

### DocxPageMode

```dart
enum DocxPageMode {
  /// Single continuous scroll (web/mobile style)
  continuous,
  
  /// Distinct page blocks (print layout style)
  paged,
}
```

### Configuration Copy

Use `copyWith` for immutable updates:

```dart
final updatedConfig = config.copyWith(
  enableZoom: false,
  pageMode: DocxPageMode.continuous,
);
```

---

## Theming

### DocxViewTheme

Comprehensive theme for document styling:

```dart
class DocxViewTheme {
  final Color? backgroundColor;
  final TextStyle defaultTextStyle;
  final Map<int, TextStyle> headingStyles;  // H1-H6
  final Color codeBlockBackground;
  final TextStyle codeTextStyle;
  final Color blockquoteBackground;
  final Color blockquoteBorderColor;
  final Color tableBorderColor;
  final Color tableHeaderBackground;
  final TextStyle linkStyle;
  final Color bulletColor;
}
```

### Preset Themes

```dart
// Light theme (default)
DocxViewTheme.light()

// Dark theme
DocxViewTheme.dark()
```

### Custom Theme Example

```dart
final customTheme = DocxViewTheme(
  backgroundColor: Color(0xFFFAFAFA),
  defaultTextStyle: TextStyle(
    fontSize: 16,
    color: Color(0xFF333333),
    fontFamily: 'Georgia',
    height: 1.6,
  ),
  headingStyles: {
    1: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
    2: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2A2A2A)),
    3: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A)),
  },
  tableBorderColor: Color(0xFFE0E0E0),
  tableHeaderBackground: Color(0xFFF5F5F5),
  linkStyle: TextStyle(
    color: Color(0xFF0066CC),
    decoration: TextDecoration.underline,
  ),
);
```

---

## Search Functionality

### DocxSearchController

A `ChangeNotifier` that manages search state:

```dart
class DocxSearchController extends ChangeNotifier {
  // Properties
  String get query;
  List<SearchMatch> get matches;
  int get matchCount;
  int get currentMatchIndex;
  SearchMatch? get currentMatch;
  bool get isSearching;
  
  // Methods
  void setDocument(List<String> texts);
  void search(String query);
  void nextMatch();
  void previousMatch();
  void clear();
  String getBlockText(int index);
}
```

### SearchMatch

Represents a single search match:

```dart
class SearchMatch {
  final int blockIndex;    // Block containing the match
  final int startOffset;   // Start position in block text
  final int endOffset;     // End position in block text
  final String text;       // The matched text
}
```

### Search Integration Example

```dart
class MyDocumentViewer extends StatefulWidget {
  @override
  _MyDocumentViewerState createState() => _MyDocumentViewerState();
}

class _MyDocumentViewerState extends State<MyDocumentViewer> {
  final _searchController = DocxSearchController();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom search bar
        TextField(
          controller: _textController,
          onSubmitted: (value) => _searchController.search(value),
          decoration: InputDecoration(
            hintText: 'Search...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_up),
                  onPressed: _searchController.previousMatch,
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down),
                  onPressed: _searchController.nextMatch,
                ),
                ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) => Text(
                    '${_searchController.currentMatchIndex + 1}/${_searchController.matchCount}',
                  ),
                ),
              ],
            ),
          ),
        ),
        // Document view
        Expanded(
          child: DocxView.bytes(
            myDocxBytes,
            searchController: _searchController,
          ),
        ),
      ],
    );
  }
}
```

---

## View Modes

### Continuous Mode

Content flows in a single scrollable view:

```dart
DocxView(
  bytes: docxBytes,
  config: DocxViewConfig(
    pageMode: DocxPageMode.continuous,
  ),
)
```

**Characteristics:**
- Single scroll container
- Responsive width
- No page boundaries
- Best for reading on mobile devices

### Paged Mode

Content is divided into distinct pages:

```dart
DocxView(
  bytes: docxBytes,
  config: DocxViewConfig(
    pageMode: DocxPageMode.paged,
    pageWidth: 794,   // A4 width at 96 DPI
    pageHeight: 1123, // A4 height at 96 DPI
  ),
)
```

**Characteristics:**
- Discrete page containers with shadows
- Fixed page dimensions
- Content-aware page breaks
- Headers/footers on each page
- Best for print preview

### Page Dimensions

Common page sizes at 96 DPI:

| Paper Size | Width (px) | Height (px) |
|------------|------------|-------------|
| A4 | 794 | 1123 |
| Letter | 816 | 1056 |
| Legal | 816 | 1344 |

---

## Widget Generation

### DocxWidgetGenerator

The core class that transforms DOCX elements into Flutter widgets:

```dart
class DocxWidgetGenerator {
  final DocxViewConfig config;
  final DocxViewTheme theme;
  final DocxTheme? docxTheme;
  final DocxSearchController? searchController;
  final void Function(int)? onFootnoteTap;
  final void Function(int)? onEndnoteTap;
  
  List<Widget> generateWidgets(DocxBuiltDocument doc);
  List<String> extractTextForSearch(DocxBuiltDocument doc);
  Map<int, GlobalKey> get keys;  // For search navigation
}
```

### Builder Classes

Each element type has a dedicated builder:

#### ParagraphBuilder
Handles text paragraphs with:
- Text spans with formatting
- Drop caps
- Floating images (left/right)
- Paragraph borders and shading
- Search highlighting

#### TableBuilder
Handles tables with:
- Cell borders and shading
- Merged cells (horizontal/vertical)
- Conditional formatting (first row, last row, etc.)
- Banded rows/columns

#### ListBuilder
Handles lists with:
- Bullet styles (disc, circle, square, etc.)
- Numbering formats (decimal, roman, alpha, etc.)
- Multi-level nesting
- Custom markers (including images)

#### ImageBuilder
Handles images with:
- Inline positioning
- Sizing and aspect ratio
- Border radius

#### ShapeBuilder
Handles vector shapes with:
- Rectangles and text boxes
- Fill colors
- Border styles

---

## Font Handling

### EmbeddedFontLoader

Loads fonts embedded in DOCX files:

```dart
class EmbeddedFontLoader {
  static Future<void> loadFont(
    String familyName,
    Uint8List bytes, {
    String? obfuscationKey,
  });
}
```

### OOXML Font Deobfuscation

Some embedded fonts are obfuscated using OOXML specification. The loader handles:
- GUID-based key extraction
- XOR deobfuscation of first 32 bytes
- Font family registration

### Font Fallbacks

Configure fallback fonts when embedded fonts are unavailable:

```dart
DocxViewConfig(
  customFontFallbacks: ['Roboto', 'Arial', 'Helvetica', 'sans-serif'],
)
```

---

## Advanced Usage

### Custom Note Handlers

Handle footnote and endnote taps:

```dart
// The DocxView internally handles notes with dialogs,
// but you can access the generator for custom behavior:

final generator = DocxWidgetGenerator(
  config: config,
  theme: theme,
  onFootnoteTap: (id) {
    // Custom footnote handling
    print('Footnote $id tapped');
  },
  onEndnoteTap: (id) {
    // Custom endnote handling
    print('Endnote $id tapped');
  },
);
```

### Debug Mode

Enable debug placeholders for unsupported elements:

```dart
DocxViewConfig(
  showDebugInfo: true,  // Shows colored boxes for unsupported elements
)
```

### Document Reload

Documents automatically reload when source changes:

```dart
// This triggers a reload
setState(() {
  _currentFile = newFile;
});

// Widget automatically detects the change
DocxView(file: _currentFile)
```

### Widget Key Access

Access widget keys for custom navigation:

```dart
final generator = DocxWidgetGenerator(...);
final widgets = generator.generateWidgets(doc);

// Access keys for any block index
final key = generator.keys[blockIndex];
if (key?.currentContext != null) {
  Scrollable.ensureVisible(key!.currentContext!);
}
```

---

## Performance Considerations

### Large Documents

For documents with many pages:

1. **Use Paged Mode** - Content is batched into pages
2. **Lazy Loading** - Only visible pages are fully rendered
3. **Disable Features** - Turn off search if not needed

```dart
DocxViewConfig(
  pageMode: DocxPageMode.paged,
  enableSearch: false,  // Reduces initial processing
)
```

### Image Optimization

- Embedded images are decoded once and cached
- Large images are scaled to fit available width
- Consider pre-processing images before embedding

### Memory Management

- Dispose controllers when done:
  ```dart
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  ```
- Avoid keeping multiple large documents in memory

---

## Troubleshooting

### Common Issues

#### Document Won't Load

```dart
DocxView(
  bytes: docxBytes,
  onError: (error) {
    // Check error details
    print('Load error: $error');
  },
)
```

**Possible causes:**
- Corrupted DOCX file
- Unsupported DOCX format (strict mode)
- Missing required parts in the archive

#### Fonts Not Rendering

1. Check if fonts are embedded in the DOCX
2. Verify font fallbacks are available
3. Check console for font loading errors

```dart
DocxViewConfig(
  customFontFallbacks: ['Roboto', 'Arial', 'Helvetica'],
)
```

#### Search Not Working

1. Ensure `enableSearch: true`
2. Verify `searchController` is properly attached
3. Check if document text was indexed

```dart
searchController.addListener(() {
  print('Matches: ${searchController.matchCount}');
});
```

#### Page Breaks Not Showing

```dart
DocxViewConfig(
  showPageBreaks: true,  // Enable visual separators
  pageMode: DocxPageMode.paged,  // Use paged mode
)
```

### Debug Output

Enable Flutter debug prints for troubleshooting:

```dart
// In development, debug prints show:
// - Search navigation details
// - Widget generation info
// - Key registration
```

---

## API Reference

### Main Classes

| Class | Description |
|-------|-------------|
| `DocxView` | Main viewer widget |
| `DocxViewWithSearch` | Viewer with built-in search bar |
| `DocxViewConfig` | Configuration options |
| `DocxViewTheme` | Theming configuration |
| `DocxSearchController` | Search state management |
| `DocxPageMode` | View mode enum |
| `SearchMatch` | Search result data |

### Exported Utilities

| Class | Description |
|-------|-------------|
| `BlockIndexCounter` | Tracks block indices for search |
| `DocxUnits` | Unit conversion utilities |

---

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

---

## License

MIT License - see [LICENSE](LICENSE) for full text.
