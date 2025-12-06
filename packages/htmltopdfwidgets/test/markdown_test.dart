import 'dart:io';

import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  const markdown = '''
# Markdown Test
## Subheading
This is a paragraph with **bold** and *italic* text.

- List item 1
- List item 2

1. Ordered item 1
2. Ordered item 2

> Blockquote

```
Code block
```

[Link](https://example.com)
![Image](https://via.placeholder.com/150)
''';

  test('Markdown Test - New Browser Engine', () async {
    final widgets =
        await HTMLToPdf().convertMarkdown(markdown, useNewEngine: true);
    expect(widgets, isNotEmpty);

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (c) => widgets));
    final bytes = await pdf.save();
    expect(bytes.length, greaterThan(0));

    final file = File('test_output_markdown.pdf');
    await file.writeAsBytes(bytes);
  });
}
