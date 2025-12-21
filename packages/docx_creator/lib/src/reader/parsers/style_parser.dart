import 'package:xml/xml.dart';

import '../models/docx_style.dart';
import '../reader_context.dart';

/// Parses and manages document styles from styles.xml.
class StyleParser {
  final ReaderContext context;

  StyleParser(this.context);

  /// Parse styles.xml and populate the context's styles map.
  void parse(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);
      for (var styleElem in xml.findAllElements('w:style')) {
        final styleId = styleElem.getAttribute('w:styleId');
        final type = styleElem.getAttribute('w:type');
        if (styleId != null) {
          final basedOn =
              styleElem.getElement('w:basedOn')?.getAttribute('w:val');
          final pPr = styleElem.getElement('w:pPr');
          final rPr = styleElem.getElement('w:rPr');

          context.styles[styleId] = DocxStyle.fromXml(
            styleId,
            type: type,
            basedOn: basedOn,
            pPr: pPr,
            rPr: rPr,
          );
        }
      }
    } catch (e) {
      // Ignore style parsing errors - graceful degradation
      print('Error parsing styles: $e');
    }
  }

  /// Resolve a style by ID with inheritance support.
  /// Delegates to context.resolveStyle for centralized resolution.
  DocxStyle resolve(String? styleId) => context.resolveStyle(styleId);
}
