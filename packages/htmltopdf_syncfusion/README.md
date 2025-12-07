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

### 1. Simple Usage (Generate Bytes)

Directly convert HTML string to PDF bytes.

```dart
import 'dart:io';
import 'package:htmltopdf_syncfusion/htmltopdf_syncfusion.dart';

void main() async {
  const String htmlContent = '''
    <h1>Hello, PDF!</h1>
    <p>This is a paragraph with <b>bold</b> and <i>italic</i> text.</p>
  ''';

  // Converts HTML directly to PDF bytes
  final List<int> bytes = await HtmlToPdf().convert(htmlContent);

  final File file = File('output.pdf');
  await file.writeAsBytes(bytes);
}
```

### 2. Advanced Usage (Add to existing PdfDocument)

Useful if you want to add pages or content to an existing Syncfusion `PdfDocument`.

```dart
import 'dart:io';
import 'package:htmltopdf_syncfusion/htmltopdf_syncfusion.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  // Create a new PDF document or load an existing one
  final PdfDocument document = PdfDocument();
  
  // Add some initial content manually if needed
  document.pages.add().graphics.drawString(
      'Document Header', PdfStandardFont(PdfFontFamily.helvetica, 18));

  const String htmlContent = '''
    <h2>HTML Section</h2>
    <ul>
      <li>Item 1</li>
      <li>Item 2</li>
    </ul>
  ''';

  final HtmlToPdf converter = HtmlToPdf();
  
  // Convert and add to the existing document
  await converter.convert(htmlContent, targetDocument: document);

  // Save the document
  final List<int> bytes = await document.save();
  document.dispose();

  await File('combined.pdf').writeAsBytes(bytes);
}
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
