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
      '''<h3>Tutorial Series:&nbsp;How To Build a Website with HTML</h3><p>This tutorial series will guide you through creating and further customizing&nbsp;<a href="http://html.sammy-codes.com/" rel="noopener noreferrer" target="_blank" style="color: rgb(0, 105, 255); background-color: transparent;"><strong><em><u>this website</u></em></strong></a><strong><em><u>&nbsp;</u></em></strong>using HTML, the standard markup language used to display documents in a web browser. No prior coding experience is necessary but we recommend you start at the&nbsp;<a href="https://www.digitalocean.com/community/tutorial_series/how-to-build-a-website-with-html" rel="noopener noreferrer" target="_blank" style="color: rgb(0, 105, 255); background-color: transparent;">beginning of the series</a>&nbsp;if you wish to recreate the demonstration website.</p><p>At the end of this series, you should have a website ready to deploy to the cloud and a basic familiarity with HTML. Knowing how to write HTML will provide a strong foundation for learning additional front-end web development skills, such as CSS and JavaScript.</p><p>Subscribe<a href="https://www.digitalocean.com/community/tags/html" rel="noopener noreferrer" target="_blank" style="color: rgb(77, 91, 124); background-color: rgb(239, 242, 251);">HTML</a></p><p><a href="https://www.digitalocean.com/community/tags/spin-up" rel="noopener noreferrer" target="_blank" style="color: rgb(77, 91, 124); background-color: rgb(239, 242, 251);">Spin Up</a></p><p>Browse Series: 23 articles</p><ul><li><a href="https://www.digitalocean.com/community/tutorials/how-to-set-up-your-html-project" rel="noopener noreferrer" target="_blank" style="color: rgb(138, 150, 181); background-color: transparent;">1/23 How To Set Up Your HTML Project With VS Code</a></li><li><a href="https://www.digitalocean.com/community/tutorials/how-to-view-the-source-code-of-an-html-document" rel="noopener noreferrer" target="_blank" style="color: rgb(138, 150, 181); background-color: transparent;">2/23 How To View the Source Code of an HTML Document</a></li><li><a href="https://www.digitalocean.com/community/tutorials/how-to-use-and-understand-html-elements" rel="noopener noreferrer" target="_blank" style="color: rgb(138, 150, 181); background-color: transparent;">3/23 How To Use and Understand HTML Elements</a></li></ul><p><span style="color: rgb(206, 145, 120);"><img src="https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Images_in_HTML/image-with-title.png" alt="The dinosaur image, with a tooltip title on top of it that reads A T-Rex on display at the Manchester University Museum " height="341" width="400"></span></p>"''';

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
