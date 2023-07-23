import 'dart:io';

import 'package:flutter/material.dart';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' as htmltopdfwidgets;
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
  final htmlText = '''<h1>Heading Example</h1>
  <p>This is a paragraph.</p>
  <img src="image.jpg" alt="Example Image" />
  <blockquote>This is a quote.</blockquote>
  <ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
  </ul>
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
