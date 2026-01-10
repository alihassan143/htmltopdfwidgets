import 'pdf_parser.dart';

class PdfLayer {
  final String name;
  final bool visible;
  final int refId;

  PdfLayer({
    required this.name,
    required this.visible,
    required this.refId,
  });

  /// Extracts layers (OCGs) from the Catalog's OCProperties dictionary.
  static List<PdfLayer> extract(PdfParser parser, int rootRef) {
    final rootObj = parser.getObject(rootRef);
    if (rootObj == null) return [];

    // Find OCProperties reference or dict
    // Catalog entry: /OCProperties 10 0 R
    final ocPropsMatch =
        RegExp(r'/OCProperties\s+(\d+)\s+\d+\s+R').firstMatch(rootObj.content);
    String? ocPropsContent;

    if (ocPropsMatch != null) {
      final obj = parser.getObject(int.parse(ocPropsMatch.group(1)!));
      ocPropsContent = obj?.content;
    } else {
      // Inline dict?
      final inlineMatch =
          RegExp(r'/OCProperties\s*<<').firstMatch(rootObj.content);
      // Parsing inline nested dicts via regex is risky, skipping for now unless needed.
      // Most generators use indirect objects for complex structures like OCProperties.
      if (inlineMatch != null) {
        // TODO: Parse inline structure if found in wild
      }
    }

    if (ocPropsContent == null) return [];

    // 1. Get List of OCGs
    // /OCGs [ 11 0 R 12 0 R ... ]
    final ocgsMatch =
        RegExp(r'/OCGs\s*\[(.*?)\]', dotAll: true).firstMatch(ocPropsContent);
    if (ocgsMatch == null) return [];

    final ocgRefs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(ocgsMatch.group(1)!);

    // 2. Get Default View Configuration (D) for visibility
    // /D << /ON [ ... ] /OFF [ ... ] /Order [ ... ] >>
    // Defaults: if /ON is missing, typically default is ON.
    // This is complex; simplified: assuming all ON unless specified OFF?
    // Actually, distinct OCGs define the semantic layers.

    final layers = <PdfLayer>[];

    for (final match in ocgRefs) {
      final refId = int.parse(match.group(1)!);
      final ocgObj = parser.getObject(refId);
      if (ocgObj == null) continue;

      final nameMatch = RegExp(r'/Name\s*\((.*?)\)').firstMatch(ocgObj.content);
      final name = nameMatch?.group(1) ?? 'Layer $refId';

      // Determine visibility uses /D dictionary in OCProperties.
      // For now, default to true. Full OCG configuration parsing is very complex.
      // docx_creator parity check: pypdf primarily LISTS layers.

      layers.add(PdfLayer(name: name, visible: true, refId: refId));
    }

    return layers;
  }
}
