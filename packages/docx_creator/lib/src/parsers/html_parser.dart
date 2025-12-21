import 'package:docx_creator/docx_creator.dart';
import 'package:html/parser.dart' as html_parser;

import 'html/block_parser.dart';
import 'html/parser_context.dart';

// Re-export for backward compatibility
export 'html/style_context.dart' show HtmlStyleContext;

/// Parses HTML content into [DocxNode] elements.
///
/// This is the main entry point for HTML parsing. It uses a modular
/// architecture with separate parsers for different element types:
///
/// - [HtmlBlockParser] - Paragraphs, headings, code blocks
/// - [HtmlInlineParser] - Text runs, links, formatting
/// - [HtmlTableParser] - Tables
/// - [HtmlListParser] - Lists
/// - [HtmlImageParser] - Images
///
/// ## HTML Parsing
/// ```dart
/// final elements = await DocxParser.fromHtml('<p>Hello <b>World</b></p>');
/// ```
class DocxParser {
  DocxParser._();

  /// Parses HTML string into DocxNode elements with async image fetching.
  ///
  /// This method properly handles:
  /// - Remote images (http/https URLs): fetched via HTTP
  /// - Base64/data URI images: decoded from inline data
  /// - Local images (if file path access allows)
  /// - Checkboxes (<input type="checkbox">)
  static Future<List<DocxNode>> fromHtml(String html) async {
    try {
      final document = html_parser.parse(html);
      final context = HtmlParserContext.fromDocument(document);
      final blockParser = HtmlBlockParser(context);

      final body = document.body;
      if (body == null) return [];
      return blockParser.parseChildren(body.nodes);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse HTML: $e',
        sourceFormat: 'HTML',
      );
    }
  }

  /// Parses Markdown string into DocxNode elements.
  static Future<List<DocxNode>> fromMarkdown(String markdown) async {
    try {
      return await MarkdownParser.parse(markdown);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse Markdown: $e',
        sourceFormat: 'Markdown',
      );
    }
  }
}

// Backward compatibility alias
typedef DocxStyleContext = HtmlStyleContext;
