import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:docx_viewer/docx_viewer.dart';

void main() {
  runApp(const DocxViewerExampleApp());
}

class DocxViewerExampleApp extends StatelessWidget {
  const DocxViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOCX Viewer Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedFile;
  bool _enableSearch = true;
  bool _enableZoom = true;
  bool _darkMode = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DOCX Viewer'),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _darkMode = !_darkMode),
            tooltip: 'Toggle theme',
          ),
          // Settings
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              setState(() {
                if (value == 'search') _enableSearch = !_enableSearch;
                if (value == 'zoom') _enableZoom = !_enableZoom;
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'search',
                checked: _enableSearch,
                child: const Text('Enable Search'),
              ),
              CheckedPopupMenuItem(
                value: 'zoom',
                checked: _enableZoom,
                child: const Text('Enable Zoom'),
              ),
            ],
          ),
        ],
      ),
      body: _selectedFile == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No document selected',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open DOCX File'),
                  ),
                ],
              ),
            )
          : DocxViewWithSearch(
              file: _selectedFile,
              config: DocxViewConfig(
                enableSearch: _enableSearch,
                enableZoom: _enableZoom,
                theme: _darkMode ? DocxViewTheme.dark() : DocxViewTheme.light(),
                backgroundColor: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
              ),
            ),
      floatingActionButton: _selectedFile != null
          ? FloatingActionButton(
              onPressed: _pickFile,
              child: const Icon(Icons.folder_open),
            )
          : null,
    );
  }
}
