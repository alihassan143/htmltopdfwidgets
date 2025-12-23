import 'dart:math';

/// Generates unique IDs for DOCX document elements.
///
/// DOCX documents require unique IDs for various elements:
/// - Document ID (w14:docId) - unique document identifier
/// - Drawing IDs (wp:docPr/@id) - unique per drawing element
/// - Relationship IDs (rId*) - unique per relationship
/// - Bookmark IDs - unique per bookmark
/// - Comment IDs - unique per comment
///
/// This class provides methods to generate these IDs in a way that's
/// compatible with Microsoft Word.
class DocxIdGenerator {
  /// Random number generator for document IDs.
  static final _random = Random();

  /// Counter for sequential IDs.
  int _counter;

  /// Starting value for relationship IDs.
  int _rIdCounter;

  /// Creates an ID generator with optional starting values.
  DocxIdGenerator({
    int startFrom = 1,
    int rIdStartFrom = 1,
  })  : _counter = startFrom,
        _rIdCounter = rIdStartFrom;

  // ===========================================================================
  // Sequential IDs (for drawings, bookmarks, etc.)
  // ===========================================================================

  /// Gets the next unique integer ID.
  int nextId() => _counter++;

  /// Gets the current ID without incrementing.
  int get currentId => _counter;

  /// Peeks at what the next ID will be.
  int get peekNextId => _counter;

  /// Resets the counter to a specific value.
  void reset({int startFrom = 1}) {
    _counter = startFrom;
  }

  // ===========================================================================
  // Relationship IDs
  // ===========================================================================

  /// Gets the next relationship ID (rId1, rId2, etc.).
  String nextRId() => 'rId${_rIdCounter++}';

  /// Gets the current rId counter value.
  int get currentRIdCounter => _rIdCounter;

  /// Resets the relationship ID counter.
  void resetRId({int startFrom = 1}) {
    _rIdCounter = startFrom;
  }

  /// Creates a relationship ID for a specific purpose.
  String rIdFor(String purpose) {
    // Standard relationship IDs used by Word
    return switch (purpose) {
      'styles' => 'rId1',
      'settings' => 'rId2',
      'webSettings' => 'rId3',
      'fontTable' => 'rId4',
      'numbering' => 'rId5',
      'footnotes' => 'rId6',
      'endnotes' => 'rId7',
      _ => nextRId(),
    };
  }

  // ===========================================================================
  // Document ID (w14:docId)
  // ===========================================================================

  /// Generates a unique document ID in Word 2010+ format.
  ///
  /// The docId is an 8-character hexadecimal string (e.g., "3B9AC9FF").
  static String generateDocId() {
    // Generate 32-bit random number and convert to hex
    final value = _random.nextInt(0xFFFFFFFF);
    return value.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  /// Generates a GUID-style document ID.
  ///
  /// Format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
  static String generateGuid() {
    String hex(int length) {
      var result = '';
      for (var i = 0; i < length; i++) {
        result += _random.nextInt(16).toRadixString(16);
      }
      return result.toUpperCase();
    }

    return '{${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}}';
  }

  // ===========================================================================
  // Revision ID (w14:rsid*)
  // ===========================================================================

  /// Generates a revision save ID (rsid).
  ///
  /// RSIDs are 8-character hexadecimal strings used to track revisions.
  static String generateRsid() {
    final value = _random.nextInt(0xFFFFFFFF);
    return value.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  // ===========================================================================
  // Named ID Generators
  // ===========================================================================

  /// Creates a unique ID for an image drawing.
  String nextImageId() => nextId().toString();

  /// Creates a unique ID for a shape drawing.
  String nextShapeId() => nextId().toString();

  /// Creates a unique ID for a bookmark.
  int nextBookmarkId() => nextId();

  /// Creates a unique ID for a comment.
  int nextCommentId() => nextId();

  /// Creates a unique ID for a footnote.
  int nextFootnoteId() => nextId();

  /// Creates a unique ID for an endnote.
  int nextEndnoteId() => nextId();
}

/// Tracks and validates document IDs to prevent duplicates.
class DocxIdTracker {
  final Set<int> _usedIds = {};
  final Set<String> _usedRIds = {};
  final Set<String> _usedDocIds = {};

  /// Registers an ID as used.
  void registerUsedId(int id) => _usedIds.add(id);

  /// Registers a relationship ID as used.
  void registerUsedRId(String rId) => _usedRIds.add(rId);

  /// Registers a document ID as used.
  void registerUsedDocId(String docId) => _usedDocIds.add(docId);

  /// Checks if an ID is already used.
  bool isIdUsed(int id) => _usedIds.contains(id);

  /// Checks if a relationship ID is already used.
  bool isRIdUsed(String rId) => _usedRIds.contains(rId);

  /// Checks if a document ID is already used.
  bool isDocIdUsed(String docId) => _usedDocIds.contains(docId);

  /// Gets the next available ID starting from a value.
  int nextAvailableId({int from = 1}) {
    var id = from;
    while (_usedIds.contains(id)) {
      id++;
    }
    registerUsedId(id);
    return id;
  }

  /// Gets the next available relationship ID.
  String nextAvailableRId({int from = 1}) {
    var num = from;
    var rId = 'rId$num';
    while (_usedRIds.contains(rId)) {
      num++;
      rId = 'rId$num';
    }
    registerUsedRId(rId);
    return rId;
  }

  /// Generates a unique document ID.
  String generateUniqueDocId() {
    var docId = DocxIdGenerator.generateDocId();
    var attempts = 0;
    while (_usedDocIds.contains(docId) && attempts < 100) {
      docId = DocxIdGenerator.generateDocId();
      attempts++;
    }
    registerUsedDocId(docId);
    return docId;
  }

  /// Clears all tracked IDs.
  void clear() {
    _usedIds.clear();
    _usedRIds.clear();
    _usedDocIds.clear();
  }

  /// Gets all used IDs.
  Set<int> get usedIds => Set.unmodifiable(_usedIds);

  /// Gets all used relationship IDs.
  Set<String> get usedRIds => Set.unmodifiable(_usedRIds);

  /// Gets all used document IDs.
  Set<String> get usedDocIds => Set.unmodifiable(_usedDocIds);
}
