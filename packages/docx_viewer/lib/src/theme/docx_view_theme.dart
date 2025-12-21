import 'package:flutter/material.dart';

/// Theme configuration for DocxView.
class DocxViewTheme {
  /// Default text style for paragraphs.
  final TextStyle defaultTextStyle;

  /// Heading text styles (H1-H6).
  final Map<int, TextStyle> headingStyles;

  /// Code block background color.
  final Color codeBlockBackground;

  /// Code block text style.
  final TextStyle codeTextStyle;

  /// Blockquote background color.
  final Color blockquoteBackground;

  /// Blockquote border color.
  final Color blockquoteBorderColor;

  /// Table border color.
  final Color tableBorderColor;

  /// Table header background.
  final Color tableHeaderBackground;

  /// Link text style.
  final TextStyle linkStyle;

  /// List bullet color.
  final Color bulletColor;

  const DocxViewTheme({
    this.defaultTextStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black87,
      height: 1.5,
    ),
    this.headingStyles = const {},
    this.codeBlockBackground = const Color(0xFFF5F5F5),
    this.codeTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFF333333),
    ),
    this.blockquoteBackground = const Color(0xFFF9F9F9),
    this.blockquoteBorderColor = const Color(0xFFCCCCCC),
    this.tableBorderColor = const Color(0xFFDDDDDD),
    this.tableHeaderBackground = const Color(0xFFEEEEEE),
    this.linkStyle = const TextStyle(
      color: Color(0xFF1976D2),
      decoration: TextDecoration.underline,
    ),
    this.bulletColor = const Color(0xFF333333),
  });

  /// Light theme preset.
  factory DocxViewTheme.light() {
    return DocxViewTheme(
      defaultTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        height: 1.5,
      ),
      headingStyles: {
        1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
        2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        3: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        4: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        5: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
        6: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
      },
    );
  }

  /// Dark theme preset.
  factory DocxViewTheme.dark() {
    return DocxViewTheme(
      defaultTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.white70,
        height: 1.5,
      ),
      headingStyles: {
        1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
        3: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white70),
        4: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
        5: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
        6: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
      },
      codeBlockBackground: const Color(0xFF2D2D2D),
      codeTextStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: Color(0xFFE0E0E0),
      ),
      blockquoteBackground: const Color(0xFF2D2D2D),
      blockquoteBorderColor: const Color(0xFF555555),
      tableBorderColor: const Color(0xFF555555),
      tableHeaderBackground: const Color(0xFF3D3D3D),
      linkStyle: const TextStyle(
        color: Color(0xFF64B5F6),
        decoration: TextDecoration.underline,
      ),
      bulletColor: const Color(0xFFCCCCCC),
    );
  }
}
