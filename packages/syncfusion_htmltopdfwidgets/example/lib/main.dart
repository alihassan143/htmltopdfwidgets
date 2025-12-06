import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:htmltopdfwidgets_syncfusion/htmltopdfwidgets_syncfusion.dart'
    as lib;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML to PDF Syncfusion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HTML to PDF Syncfusion Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  Uint8List? _pdfBytes;

  final String _htmlContent = '''
    <h1 style="color: #4a148c; text-align: center;">Welcome to HTML to PDF!</h1>
    <p style="font-size: 14px;">
      This is a demonstration of the <b>htmltopdfwidgets_syncfusion</b> package.
      It converts HTML content into native Syncfusion PDF widgets.
    </p>
    <div style="background-color: #e0f2f1; padding: 15px; border: 1px solid #00695c;">
      <h2>Features:</h2>
      <ul>
        <li>Headings (H1-H6)</li>
        <li>Paragraphs with custom styling</li>
        <li><b>Bold</b>, <i>Italic</i>, <u>Underline</u> text</li>
        <li>Lists (Unordered & Ordered)</li>
        <li>Images (Network & Assets)</li>
        <li>Tables</li>
      </ul>
    </div>
    <br/>
    <p>Enjoy generating PDFs!</p>
  ''';

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await lib.HtmlToPdf().convert(_htmlContent);

      setState(() {
        _pdfBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _pdfBytes = null;
                });
              },
            ),
        ],
      ),
      body: _pdfBytes != null
          ? SfPdfViewer.memory(_pdfBytes!)
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Input HTML:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: SingleChildScrollView(
                        child: Text(_htmlContent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    FilledButton.icon(
                      onPressed: _generatePdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate PDF'),
                    ),
                ],
              ),
            ),
    );
  }
}
