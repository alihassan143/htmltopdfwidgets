import 'dart:io';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Uint8List? _demoBytes;
  bool _enableSearch = true;
  bool _enableZoom = true;
  bool _darkMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDemoFile();
  }

  Future<void> _loadDemoFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to load demo.docx from the package directory
      final demoPath = '${Directory.current.path}/../demo.docx';
      final demoFile = File(demoPath);

      if (await demoFile.exists()) {
        setState(() {
          _selectedFile = demoFile;
          _isLoading = false;
        });
        debugPrint('Demo file loaded from: $demoPath');
      } else {
        // Try alternative paths
        final altPaths = [
          '${Directory.current.path}/demo.docx',
          '/Users/mac/Desktop/htmltopdfwidgets/packages/docx_viewer/demo.docx',
        ];

        for (final path in altPaths) {
          final file = File(path);
          if (await file.exists()) {
            setState(() {
              _selectedFile = file;
              _isLoading = false;
            });
            debugPrint('Demo file loaded from: $path');
            return;
          }
        }

        setState(() {
          _isLoading = false;
          _errorMessage = 'Demo file not found. Please select a file manually.';
        });
        debugPrint('Demo file not found at any location');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading demo: $e';
      });
      debugPrint('Error loading demo file: $e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _demoBytes = null;
        _errorMessage = null;
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading demo document...'),
          ],
        ),
      );
    }

    if (_selectedFile == null && _demoBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
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
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadDemoFile,
              child: const Text('Try loading demo again'),
            ),
          ],
        ),
      );
    }

    return DocxView(
      file: _selectedFile,
      bytes: _demoBytes,
      config: DocxViewConfig(
        enableSearch: _enableSearch,
        enableZoom: _enableZoom,
        theme: _darkMode ? DocxViewTheme.dark() : DocxViewTheme.light(),
        backgroundColor: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        showDebugInfo: true, // Enable debug info to see unsupported elements
      ),
      onLoaded: () {
        debugPrint('Document loaded successfully');
      },
      onError: (error) {
        debugPrint('Document loading error: $error');
        setState(() {
          _errorMessage = 'Error: $error';
        });
      },
    );
  }
}
