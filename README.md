<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
Strinng htmlText='''<p>&nbsp;</p>
<h2>Is it Important to Remove Grammatical Errors?<br />It's definitely important to remove all the grammatical errors and make your content grammatically fit. There are many factors involved with grammar including spelling, punctuation, use of articles, and more.<br />It is not wrong to say that you need to eliminate grammatical errors if you want to get benefited from your content because it is tough to rank the content which is not grammatically perfect. If you want to complete this task in less time, you can opt for this grammar checker.</h2>
<h2>What Factors Make a Grammar Checker the Best?<br /><br /></h2>
<p>Here are a lot of different factors. Some are important and major, while some can be a bit overlooked by a lot of people. However, these should</p>
<h2>Steps to create a PDF document programmatically in Web platform<br /><br /></h2>
<ol>
<li>Create a new Flutter application project.</li>
</ol>
<p><br />1.1Open Visual Studio Code (After installing the Dart and Flutter extensions as stated in this&nbsp;<a href="https://flutter.dev/docs/get-started/editor?tab=vscode" target="_blank" rel="noopener">setup editor</a>&nbsp;page)<br />1.2Click View -&gt; Command Palette&hellip;<br /><br /><img class="ql-image" src="https://www.syncfusion.com/uploads/user/kb/flut/flut-2327/flut-2327_img1.png" width="469" /><br />1.3Type&nbsp;Flutter&nbsp;and choose&nbsp;Flutter: New Project.<br /><br /><img class="ql-image" src="https://www.syncfusion.com/uploads/user/kb/flut/flut-2327/flut-2327_img2.png" width="535" /><br />1.4Enter the project name and press the Enter button </p>''';
    final newpdf = pw.Document();
    List<pw.Widget> widgets = await HTMLToNodesConverter(htmlText).toNodes();
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
