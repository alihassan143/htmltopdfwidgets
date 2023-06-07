import 'dart:io';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' as htmltopdfwidgets;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final htmlText =
      '''<p>This gives us a tooltip on mouse hover, just like link titles:</p><p>asa</p><p><img src="https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Images_in_HTML/image-with-title.png" alt="The dinosaur image, with a tooltip title on top of it that reads A T-Rex on display at the Manchester University Museum " height="341" width="400"></p><p>However, this is not recommended —&nbsp;<code>title</code>&nbsp;has a number of accessibility problems, mainly based around the fact that screen reader support is very unpredictable and most browsers won't show it unless you are hovering with a mouse (so e.g. no access to keyboard users). If you are interested in more information about this, read&nbsp;<a href="https://www.24a11y.com/2017/the-trials-and-tribulations-of-the-title-attribute/" rel="noopener noreferrer" target="_blank" style="color: var(--text-link);">The Trials and Tribulations of the Title Attribute</a>&nbsp;by Scott O'Hara.</p><p>It is better to include such supporting information in the main article text, rather than attached to the image.</p>

 
 ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Html To Pdf"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: () {
                  createDocument();
                },
                child: const Text("Create Pdf"))
          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  createDocument() async {
    var directory = await getApplicationDocumentsDirectory();
    var filePath = '${directory.path}/example.pdf';
    var file = File(filePath);
    final newpdf = htmltopdfwidgets.Document();
    List<htmltopdfwidgets.Widget> widgets =
        await htmltopdfwidgets.HTMLToPdf().convert(htmlText);
    newpdf.addPage(htmltopdfwidgets.MultiPage(
        maxPages: 200,
        build: (context) {
          return widgets;
        }));
    await file.writeAsBytes(await newpdf.save());
    print('File created: $filePath');
  }
}
