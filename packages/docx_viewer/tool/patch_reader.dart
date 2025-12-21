import 'dart:io';

void main() {
  final file = File('../docx_creator/lib/src/reader/docx_reader.dart');
  if (!file.existsSync()) {
    print('Error: docx_reader.dart not found');
    exit(1);
  }

  var content = file.readAsStringSync();

  // --- 1. Replace _parseTable ---
  // Use flexible signature matching
  content = _replaceBlock(content, 'DocxTable _parseTable(XmlElement', r'''
  DocxTable _parseTable(XmlElement node) {
    // 1. Parse Properties
    final rawRows = <List<_TempCell>>[];
    
    for (var child in node.children) {
      if (child is XmlElement && child.name.local == 'tr') {
        final row = <_TempCell>[];
        for (var cellNode in child.children) {
           if (cellNode is XmlElement && cellNode.name.local == 'tc') {
             // Parse cell properties
             final tcPr = cellNode.getElement('w:tcPr');
             int gridSpan = 1;
             String? vMergeVal;
             String? shadingFill;
             
             if (tcPr != null) {
               final gs = tcPr.getElement('w:gridSpan');
               if (gs != null) gridSpan = int.tryParse(gs.getAttribute('w:val') ?? '1') ?? 1;
               
               final vm = tcPr.getElement('w:vMerge');
               if (vm != null) vMergeVal = vm.getAttribute('w:val') ?? 'continue';
               
               final shd = tcPr.getElement('w:shd');
               if (shd != null) {
                 shadingFill = shd.getAttribute('w:fill');
                 if (shadingFill == 'auto') shadingFill = null;
               }
             }
             
             final children = <DocxNode>[];
             for (var c in cellNode.children) {
               if (c is XmlElement && c.name.local == 'p') {
                 children.add(_parseParagraph(c));
               } else if (c is XmlElement && c.name.local == 'tbl') {
                 children.add(_parseTable(c));
               }
             }
             
             row.add(_TempCell(
               children: children,
               gridSpan: gridSpan,
               vMerge: vMergeVal,
               shadingFill: shadingFill,
             ));
           }
        }
        if (row.isNotEmpty) rawRows.add(row);
      }
    }
    
    final grid = _resolveRowSpans(rawRows);
    final finalRows = <DocxTableRow>[];

    for (var r in grid) {
      final cells = r.map((c) => DocxTableCell(
        children: c.children,
        colSpan: c.gridSpan,
        rowSpan: c.finalRowSpan,
        shadingFill: c.shadingFill,
      )).toList();
      finalRows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(rows: finalRows);
  }
''');

  // Replace _parseRun
  content = _replaceBlock(content, 'DocxInline _parseRun(XmlElement', r'''
  DocxInline _parseRun(XmlElement run) {
    // Check for drawings (Images or Shapes)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      // 1. Try VML Shape
      final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
      if (wsp != null) {
        return _readShape(drawing, wsp);
      }

      // 2. Try Image (a:blip)
      final blip = drawing.findAllElements('a:blip').firstOrNull ??
          drawing.findAllElements('v:imagedata').firstOrNull;
      if (blip != null) {
        final embedId =
            blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
        if (embedId != null && _documentRelationships.containsKey(embedId)) {
          return _readImage(embedId, drawing);
        }
      }
      
      // 3. DrawingML Shape (fallback)
      final prstGeom = drawing.findAllElements('a:prstGeom').firstOrNull;
      if (prstGeom != null) {
          return DocxShape(
            width: 100, height: 100, preset: DocxShapePreset.rect, text: 'Shape'
          );
      }
    }

    // Check for line break
    if (run.findAllElements('w:br').isNotEmpty) {
      return const DocxLineBreak();
    }
    // Check for tab
    if (run.findAllElements('w:tab').isNotEmpty) {
      return const DocxTab();
    }

    // Parse formatting
    var fontWeight = DocxFontWeight.normal;
    var fontStyle = DocxFontStyle.normal;
    var decoration = DocxTextDecoration.none;
    DocxColor? color;
    String? shadingFill;
    double? fontSize;
    String? fontFamily;
    var highlight = DocxHighlight.none;
    bool isSuperscript = false;
    bool isSubscript = false;
    bool isAllCaps = false;
    bool isSmallCaps = false;
    bool isDoubleStrike = false;
    bool isOutline = false;
    bool isShadow = false;
    bool isEmboss = false;
    bool isImprint = false;

    final rPr = run.getElement('w:rPr');
    if (rPr != null) {
      if (rPr.getElement('w:b') != null) fontWeight = DocxFontWeight.bold;
      if (rPr.getElement('w:i') != null) fontStyle = DocxFontStyle.italic;
      if (rPr.getElement('w:u') != null) decoration = DocxTextDecoration.underline;
      if (rPr.getElement('w:strike') != null) decoration = DocxTextDecoration.strikethrough;

      final colorElem = rPr.getElement('w:color');
      if (colorElem != null) {
        final val = colorElem.getAttribute('w:val');
        if (val != null && val != 'auto') color = DocxColor('#$val');
      }

      final shdElem = rPr.getElement('w:shd');
      if (shdElem != null) {
        shadingFill = shdElem.getAttribute('w:fill');
        if (shadingFill == 'auto') shadingFill = null;
      }

      final szElem = rPr.getElement('w:sz');
      if (szElem != null) {
        final val = szElem.getAttribute('w:val');
        if (val != null) {
          final halfPoints = int.tryParse(val);
          if (halfPoints != null) fontSize = halfPoints / 2.0;
        }
      }

      final rFonts = rPr.getElement('w:rFonts');
      if (rFonts != null) fontFamily = rFonts.getAttribute('w:ascii');

      final highlightElem = rPr.getElement('w:highlight');
      if (highlightElem != null) {
        final val = highlightElem.getAttribute('w:val');
        if (val != null) {
          for (var h in DocxHighlight.values) {
            if (h.name == val) { highlight = h; break; }
          }
        }
      }

      if (rPr.getElement('w:caps') != null) isAllCaps = true;
      if (rPr.getElement('w:smallCaps') != null) isSmallCaps = true;
      if (rPr.getElement('w:dstrike') != null) isDoubleStrike = true;
      if (rPr.getElement('w:outline') != null) isOutline = true;
      if (rPr.getElement('w:shadow') != null) isShadow = true;
      if (rPr.getElement('w:emboss') != null) isEmboss = true;
      if (rPr.getElement('w:imprint') != null) isImprint = true;

      final vertAlignElem = rPr.getElement('w:vertAlign');
      if (vertAlignElem != null) {
        final val = vertAlignElem.getAttribute('w:val');
        if (val == 'superscript') isSuperscript = true;
        if (val == 'subscript') isSubscript = true;
      }
    }

    final textElem = run.getElement('w:t');
    if (textElem != null) {
      return DocxText(
        textElem.innerText,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: decoration,
        color: color,
        shadingFill: shadingFill,
        fontSize: fontSize,
        fontFamily: fontFamily,
        highlight: highlight,
        isSuperscript: isSuperscript,
        isSubscript: isSubscript,
        isAllCaps: isAllCaps,
        isSmallCaps: isSmallCaps,
        isDoubleStrike: isDoubleStrike,
        isOutline: isOutline,
        isShadow: isShadow,
        isEmboss: isEmboss,
        isImprint: isImprint,
      );
    }

    return DocxRawInline(run.toXmlString());
  }
''');

  // --- 2. Add Helper Class and Method ---
  // Insert before the last closing brace of the class DocxReader
  // Actually, helper class _TempCell should be outside DocxReader or at file level.
  // And _resolveRowSpans inside or outside.

  // I will add them at the END of the file.

  final helperCode = r'''

class _TempCell {
  final List<DocxNode> children;
  final int gridSpan;
  final String? vMerge;
  final String? shadingFill;
  
  int finalRowSpan = 1;
  bool isMerged = false; // If true, this cell is part of a merge but NOT the start (should be skipped or hidden?)
  // Actually, for DocxViewer/Table, we usually want the start cell to have rowSpan > 1, 
  // and subsequent cells to NOT EXIST in the row? 
  // CustomTableLayout expects them to exist? 
  // No, CustomTableLayout expects "cells" list. 
  // If use "Table", we need to emit correct number of cells (ghost cells).
  // But DocxTableCell definition implies we return the structure.
  // I will keep the cells but mark them? 
  // If DocxViewer's TableBuilder ignores cells that are "covered", we should provide them?
  // My new CustomTableWidget handles occupied cells.
  // So I should return ALL cells, but correct rowSpan.
  // Wait, if rowSpan is 2, the cell in the next row at that col should exist?
  // In HTML tables, spanning cells cover slots. The slots in next row are implicit?
  // In CustomTableWidget logic: "Track which cells span...". It expects the *next* row to NOT have a cell definition for that slot?
  // Or it effectively skips them.
  // Whatever logic I implemented in CustomTableWidget, I should match.
  // CustomTableWidget: "for (final cell in cells) ... if (cell.rowSpan > 1) ... spanningCells".
  // ... "while (currentCol < columnCount) ... if (occupiedCols.contains) ... empty spacer".
  // So CustomTableWidget handles it.
  // So _DocxReader should produce cells with correct span.
  // For "continued" cells (vMerge=continue), should they have rowSpan=0? Or -1?
  // Or should they be REMOVED from the row?
  // If I remove them, CustomTableLayout needs to know they are missing.
  // CustomTableLayout iterates input cells.
  // So if I have row 1: Cell(span=2)
  // Row 2: (Empty because covered).
  // Then Row 2 in AST should have NO cell for that column?
  // Yes.
  // So my _resolveRowSpans should filtering out "continued" cells?
  // Let's implement that.
  
  _TempCell({
    required this.children,
    required this.gridSpan,
    this.vMerge,
    this.shadingFill,
  });
}

List<List<_TempCell>> _resolveRowSpans(List<List<_TempCell>> rawRows) {
  // Track active merge starts per column index
  // ColIndex -> _TempCell (the start of the merge)
  final activeMerges = <int, _TempCell>{};
  
  // We need to map visual columns.
  // Since gridSpan affects column index.
  
  for (int r = 0; r < rawRows.length; r++) {
    final row = rawRows[r];
    int colIndex = 0;
    
    for (int c = 0; c < row.length; c++) {
      final cell = row[c];
      
      // Calculate current range of columns
      final startCol = colIndex;
      final endCol = colIndex + cell.gridSpan;
      
      if (cell.vMerge == 'restart') {
        // Start a new merge
        // Close previous if any (shouldn't happen for restart unless nested, but key is colIndex)
        // For gridSpan > 1, we track the FIRST col index.
        activeMerges[startCol] = cell;
        cell.finalRowSpan = 1; 
      } else if (cell.vMerge == 'continue' || (cell.vMerge != null && cell.vMerge!.isEmpty)) {
        // Continue merge
        final startCell = activeMerges[startCol];
        if (startCell != null) {
          startCell.finalRowSpan++;
          cell.isMerged = true; // Mark to remove
        }
      } else {
         // No merge. 
         activeMerges.remove(startCol);
      }
      
      colIndex += cell.gridSpan;
    }
  }
  
  // Filter out merged cells (continue)
  // We recreate the rows  // Filter out merged cells (continue)
  final result = <List<_TempCell>>[];
  for (final row in rawRows) {
    result.add(row.where((c) => !(c as _TempCell).isMerged).toList());
  }
  return result;
}
''';

  // Insert helper code at end
  content += helperCode;

  // --- 3. Replace _parseRun for Shapes ---
  // To verify if it works, I'll attempt to parse DrawingML generic structure.
  // If w:drawing is found, try to extract image OR shape.
  // Currently _parseRun handles it. I'll make it robust.

  final parseRunOriginal = '_parseRun(XmlElement run)';
  final parseRunNew = r'''_parseRun(XmlElement run) {
    // Check for drawings (Images or Shapes)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
       // 1. Try VML Shape
       final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
       if (wsp != null) return _readShape(drawing, wsp);
       
       // 2. Try Image (a:blip)
       // Improve search to be deeper if needed, or use existing logic.
       final blip = drawing.findAllElements('a:blip').firstOrNull ??
           drawing.findAllElements('v:imagedata').firstOrNull;
           
       if (blip != null) {
         final embedId = blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
         if (embedId != null && _documentRelationships.containsKey(embedId)) {
           return _readImage(embedId, drawing);
         }
       }
       
       // 3. Fallback: Shape without wsp:wsp? (DrawingML Shape)
       // Look for w:drawing -> wp:inline -> a:graphic -> a:graphicData -> wps:wsp?
       // For now, if we found a drawing but no image/shape, return a placeholder?
       // Or return DocxRawInline. 
    }
''';

  // Detecting the start of _parseRun and replacing just the drawing logic?
  // It's safer to replace the whole method if I can match it.
  // Or just modify the existing block.
  // _parseRun in original:
  /*
  DocxInline _parseRun(XmlElement run) {
    // Check for drawings (Images or Shapes)
    final drawing = ...
  */
  // I will replace the start of the method to inject better logic.

  // Replacing _parseTable
  // I need to locate the start and end of _parseTable.
  // I'll implementation a helper to find balanced braces.

  content =
      _replaceBlock(content, 'DocxTable _parseTable(XmlElement node) {', r'''
  DocxTable _parseTable(XmlElement node) {
    // 1. Parse Rows and Cells into temporary structure
    final rawRows = <List<_TempCell>>[];
    
    for (var child in node.children) {
      if (child is XmlElement && child.name.local == 'tr') {
        final row = <_TempCell>[];
        for (var cellNode in child.children) {
           if (cellNode is XmlElement && cellNode.name.local == 'tc') {
             // Parse cell properties
             final tcPr = cellNode.getElement('w:tcPr');
             int gridSpan = 1;
             String? vMergeVal;
             String? shadingFill;
             
             if (tcPr != null) {
               final gs = tcPr.getElement('w:gridSpan');
               if (gs != null) gridSpan = int.tryParse(gs.getAttribute('w:val') ?? '1') ?? 1;
               
               final vm = tcPr.getElement('w:vMerge');
               if (vm != null) vMergeVal = vm.getAttribute('w:val') ?? 'continue';
               
               final shd = tcPr.getElement('w:shd');
               if (shd != null) {
                 shadingFill = shd.getAttribute('w:fill');
                 if (shadingFill == 'auto') shadingFill = null;
               }
             }
             
             final children = <DocxNode>[];
             for (var c in cellNode.children) {
               if (c is XmlElement && c.name.local == 'p') {
                 children.add(_parseParagraph(c));
               } else if (c is XmlElement && c.name.local == 'tbl') {
                 children.add(_parseTable(c));
               }
             }
             
             row.add(_TempCell(
               children: children,
               gridSpan: gridSpan,
               vMerge: vMergeVal,
               shadingFill: shadingFill,
             ));
           }
        }
        if (row.isNotEmpty) rawRows.add(row);
      }
    }
    
    final grid = _resolveRowSpans(rawRows);
    final finalRows = <DocxTableRow>[];

    for (var r in grid) {
      final cells = r.map((c) => DocxTableCell(
        children: c.children,
        colSpan: c.gridSpan,
        rowSpan: c.finalRowSpan,
        shadingFill: c.shadingFill,
      )).toList();
      finalRows.add(DocxTableRow(cells));
    }

    return DocxTable(rows: finalRows);
  }
''');

  file.writeAsStringSync(content);
  print('Successfully patched docx_reader.dart');
}

String _replaceMethod(String content, String signature, String newCode) {
  // Simple replace if signature is unique and usage is clean
  // But need to handle the whole body.
  // This function is placeholder. Use _replaceBlock.
  return content;
}

String _replaceBlock(String content, String startSignature, String newCode) {
  final startIndex = content.indexOf(startSignature);
  if (startIndex == -1) {
    print('Error: Could not find signature: $startSignature');
    return content;
  }

  // Find closing brace
  int openBraces = 0;
  int index = startIndex + startSignature.length - 1; // Assuming ends with {

  // Advance to {
  while (index < content.length && content[index] != '{') {
    index++;
  }

  if (index >= content.length) return content;

  openBraces = 1;
  index++;

  while (index < content.length && openBraces > 0) {
    if (content[index] == '{') openBraces++;
    if (content[index] == '}') openBraces--;
    index++;
  }

  final replacement = newCode;
  return content.substring(0, startIndex) +
      replacement +
      content.substring(index);
}
