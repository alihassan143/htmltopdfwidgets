import 'package:flutter/foundation.dart';

/// Controller for document search functionality.
class DocxSearchController extends ChangeNotifier {
  String _query = '';
  List<SearchMatch> _matches = [];
  int _currentMatchIndex = -1;
  bool _isSearching = false;
  List<String> _documentTexts = [];

  /// Current search query.
  String get query => _query;

  /// All found matches.
  List<SearchMatch> get matches => List.unmodifiable(_matches);

  /// Number of matches found.
  int get matchCount => _matches.length;

  /// Index of the currently highlighted match.
  int get currentMatchIndex => _currentMatchIndex;

  /// Whether a search is currently active.
  bool get isSearching => _isSearching;

  /// Current match (if any).
  SearchMatch? get currentMatch =>
      _currentMatchIndex >= 0 && _currentMatchIndex < _matches.length
          ? _matches[_currentMatchIndex]
          : null;

  /// Set the document text for searching.
  void setDocument(List<String> texts) {
    _documentTexts = texts;
    // If we have a query, re-run search? Or just clear?
    // Let's clear for now to avoid unexpected state
    clear();
  }

  /// Search for text in the document.
  void search(String query) {
    _query = query;
    _matches = [];
    _currentMatchIndex = -1;

    if (query.isEmpty) {
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    final lowerQuery = query.toLowerCase();

    for (int blockIndex = 0; blockIndex < _documentTexts.length; blockIndex++) {
      final text = _documentTexts[blockIndex].toLowerCase();
      int startIndex = 0;

      while (true) {
        final index = text.indexOf(lowerQuery, startIndex);
        if (index == -1) break;

        _matches.add(SearchMatch(
          blockIndex: blockIndex,
          startOffset: index,
          endOffset: index + query.length,
          text:
              _documentTexts[blockIndex].substring(index, index + query.length),
        ));

        startIndex = index + 1;
      }
    }

    if (_matches.isNotEmpty) {
      _currentMatchIndex = 0;
    }

    notifyListeners();
  }

  /// Move to the next match.
  void nextMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    notifyListeners();
  }

  /// Move to the previous match.
  void previousMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex =
        (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    notifyListeners();
  }

  /// Get text for a specific block index.
  String getBlockText(int index) {
    if (index >= 0 && index < _documentTexts.length) {
      return _documentTexts[index];
    }
    return '';
  }

  /// Clear search.
  void clear() {
    _query = '';
    _matches = [];
    _currentMatchIndex = -1;
    _isSearching = false;
    notifyListeners();
  }
}

/// Represents a search match in the document.
class SearchMatch {
  /// Index of the block containing the match.
  final int blockIndex;

  /// Start offset within the block text.
  final int startOffset;

  /// End offset within the block text.
  final int endOffset;

  /// The matched text.
  final String text;

  const SearchMatch({
    required this.blockIndex,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });
}
