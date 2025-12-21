import 'package:flutter/material.dart';

import 'theme/docx_view_theme.dart';

/// Configuration for [DocxView] widget.
class DocxViewConfig {
  /// Enable search functionality with highlighting.
  final bool enableSearch;

  /// Enable pinch-to-zoom functionality.
  final bool enableZoom;

  /// Enable text selection for copy/paste.
  final bool enableSelection;

  /// Minimum zoom scale.
  final double minScale;

  /// Maximum zoom scale.
  final double maxScale;

  /// Font fallbacks when embedded fonts are unavailable.
  final List<String> customFontFallbacks;

  /// Theme for styling the document view.
  final DocxViewTheme? theme;

  /// Padding around the document content.
  final EdgeInsets padding;

  /// Background color for the viewer.
  final Color? backgroundColor;

  /// Show page breaks as visual separators.
  final bool showPageBreaks;

  /// Show debug info for unsupported elements (development mode).
  final bool showDebugInfo;

  /// Highlight color for search matches.
  final Color searchHighlightColor;

  /// Current search match highlight color.
  final Color currentSearchHighlightColor;

  const DocxViewConfig({
    this.enableSearch = true,
    this.enableZoom = true,
    this.enableSelection = true,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.customFontFallbacks = const ['Roboto', 'Arial', 'Helvetica'],
    this.theme,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor,
    this.showPageBreaks = true,
    this.showDebugInfo = false,
    this.searchHighlightColor = const Color(0xFFFFEB3B),
    this.currentSearchHighlightColor = const Color(0xFFFF9800),
  });

  DocxViewConfig copyWith({
    bool? enableSearch,
    bool? enableZoom,
    bool? enableSelection,
    double? minScale,
    double? maxScale,
    List<String>? customFontFallbacks,
    DocxViewTheme? theme,
    EdgeInsets? padding,
    Color? backgroundColor,
    bool? showPageBreaks,
    bool? showDebugInfo,
    Color? searchHighlightColor,
    Color? currentSearchHighlightColor,
  }) {
    return DocxViewConfig(
      enableSearch: enableSearch ?? this.enableSearch,
      enableZoom: enableZoom ?? this.enableZoom,
      enableSelection: enableSelection ?? this.enableSelection,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
      customFontFallbacks: customFontFallbacks ?? this.customFontFallbacks,
      theme: theme ?? this.theme,
      padding: padding ?? this.padding,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showPageBreaks: showPageBreaks ?? this.showPageBreaks,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      searchHighlightColor: searchHighlightColor ?? this.searchHighlightColor,
      currentSearchHighlightColor:
          currentSearchHighlightColor ?? this.currentSearchHighlightColor,
    );
  }
}
