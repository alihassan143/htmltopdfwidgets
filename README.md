# HTMLtoPDFWidgets


HTMLtoPDFWidgets is a Flutter package that allows you to convert HTML content into PDF documents with support for various Rich Text Editor formats. With this package, you can effortlessly generate PDF files that include elements such as lists, paragraphs, images, quotes, and headings.

## Features

- Convert HTML content to PDF documents in Flutter apps
- Support for Rich Text Editor formats
- Seamless integration with your Flutter project
- Lightweight and easy to use

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  htmltopdfwidgets: ^0.0.9+1
```

## Usage

To use HTMLtoPDFWidgets in your Flutter project, follow these simple steps:

1. Import the package:

```dart
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
```

2. Convert HTML to PDF:

```dart
final htmlContent = '''
  <h1>Heading Example</h1>
  <p>This is a paragraph.</p>
  <img src="image.jpg" alt="Example Image" />
  <blockquote>This is a quote.</blockquote>
  <ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
  </ul>
''';

f var filePath = 'test/example.pdf';
  var file = File(filePath);
  final newpdf = Document();
  List<Widget> widgets = await HTMLToPdf().convert(htmlText);
  newpdf.addPage(MultiPage(
      maxPages: 200,
      build: (context) {
        return widgets;
      }));
  await file.writeAsBytes(await newpdf.save());
```

For more details on usage and available options, please refer to the [API documentation](https://pub.dev/documentation/htmltopdfwidgets/latest).

## Example

You can find a complete example in the [example](https://github.com/alihassan143/htmltopdfwidgets/tree/main/example) directory of this repository.

## License

This package is licensed under the [MIT License](https://github.com/alihassan143/htmltopdfwidgets/blob/main/LICENSE).

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please feel free to open an issue or submit a pull request on the [GitHub repository](https://github.com/alihassan143/htmltopdfwidgets).

## Acknowledgments

Special thanks to the Appflowy editor:
I use their Html To Document plugin as reference

- Appflowy ([@AppFlowy-IO](https://github.com/AppFlowy-IO/appflowy-editor))



Happy PDF generation with HTMLtoPDFWidgets in your Flutter apps!
