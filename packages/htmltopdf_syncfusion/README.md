# htmltopdf_syncfusion

A robust Flutter package that simplifies the process of converting HTML and Markdown content into high-quality PDFs using the **Syncfusion Flutter PDF** library. This package handles complex text layouts, multi-language support (including Arabic RTL), and basic CSS styling.

## Features

-   **HTML to PDF**: Convert raw HTML strings into Syncfusion PDF widgets.
-   **Markdown Support**: Parse and render Markdown content.
-   **Multi-Language Support**:
    -   Full support for **Arabic** (Right-to-Left text direction and character reshaping).
    -   Support for **Chinese/Japanese/Korean (CJK)** characters.
    -   **Emoji** rendering support.
-   **Rich Text Formatting**:
    -   Headings (`h1`-`h6`), Paragraphs (`p`), Blockquotes.
    -   Bold (`b`/`strong`), Italic (`i`/`em`), Underline, Strikethrough.
    -   Ordered (`ol`) and Unordered (`ul`) lists with proper markers.
-   **Styling**:
    -   Supports inline CSS (`style="..."`).
    -   Supports basic CSS classes and tag-based styling.
    -   Customizable font sizes, colors, and alignments.
-   **Images**: Render images from **Network** URLs and **Asset** paths.
-   **Tables**: Render HTML tables with borders and background colors.
-   **Checkboxes**: Render `<input type="checkbox">` as visual elements.

## Installation

1.  Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  htmltopdf_syncfusion:
    path: ./ # Or git url/pub version
  syncfusion_flutter_pdf: ^24.1.41
```

2.  Import the package:

```dart
import 'package:htmltopdf_syncfusion/htmltopdf_syncfusion.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
```

## Usage

### Basic Example

```dart
// 1. Create a new PDF document
final PdfDocument document = PdfDocument();

// 2. Define your HTML content
const String htmlContent = '''
  <h1>Hello, PDF!</h1>
  <p>This is a paragraph with <b>bold</b> and <i>italic</i> text.</p>
  <ul>
    <li>First item</li>
    <li>Second item</li>
  </ul>
''';

// 3. Convert and draw HTML to the document
// The `HTMLToPdf` widget handles the parsing and drawing.
// Note: This package currently provides a builder pattern internally.
// Use the `HTMLToPdf` class to convert:

final HTMLToPdf converter = HTMLToPdf(
  htmlContent: htmlContent,
  defaultFontSize: 12,
);

// Draw content onto the page
await converter.convert(document);

// 4. Save the document
final List<int> bytes = await document.save();
document.dispose();
```

### Handling Assets/Fonts
Ensure you have the required fonts declared in your `pubspec.yaml` if you need specific fallbacks, although the package includes Noto fonts for Arabic and Emoji support internally.

## Supported HTML Tags
-   `div`, `span`, `p`, `br`
-   `h1`, `h2`, `h3`, `h4`, `h5`, `h6`
-   `b`, `strong`, `i`, `em`, `u`, `del`, `s`, `strike`
-   `ul`, `ol`, `li`
-   `table`, `tr`, `td`, `th`, `thead`, `tbody`
-   `img` (src attributes)
-   `blockquote`
-   `input` (type="checkbox")

## License
MIT License. See [LICENSE](LICENSE) for details.
