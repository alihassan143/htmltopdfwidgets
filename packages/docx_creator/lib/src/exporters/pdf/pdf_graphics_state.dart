/// Tracks PDF graphics state to minimize redundant output.
///
/// The graphics state includes stroke/fill colors, line width, and other
/// parameters that only need to be written when they change.
class PdfGraphicsState {
  String? _strokeColor;
  String? _fillColor;
  double? _lineWidth;
  String? _lineCap;
  String? _lineJoin;
  List<double>? _dashPattern;
  double? _dashPhase;

  /// Sets stroke color (RGB hex).
  /// Returns the PDF command if state changed, empty string otherwise.
  String setStrokeColor(String hex) {
    if (_strokeColor == hex) return '';
    _strokeColor = hex;
    final rgb = _hexToRgb(hex);
    return '${rgb[0]} ${rgb[1]} ${rgb[2]} RG\n';
  }

  /// Sets fill color (RGB hex).
  /// Returns the PDF command if state changed, empty string otherwise.
  String setFillColor(String hex) {
    if (_fillColor == hex) return '';
    _fillColor = hex;
    final rgb = _hexToRgb(hex);
    return '${rgb[0]} ${rgb[1]} ${rgb[2]} rg\n';
  }

  /// Sets line width.
  /// Returns the PDF command if state changed, empty string otherwise.
  String setLineWidth(double width) {
    if (_lineWidth == width) return '';
    _lineWidth = width;
    return '${width.toStringAsFixed(3)} w\n';
  }

  /// Sets line cap style.
  /// - 0: Butt cap (default)
  /// - 1: Round cap
  /// - 2: Projecting square cap
  String setLineCap(int style) {
    final key = style.toString();
    if (_lineCap == key) return '';
    _lineCap = key;
    return '$style J\n';
  }

  /// Sets line join style.
  /// - 0: Miter join (default)
  /// - 1: Round join
  /// - 2: Bevel join
  String setLineJoin(int style) {
    final key = style.toString();
    if (_lineJoin == key) return '';
    _lineJoin = key;
    return '$style j\n';
  }

  /// Sets dash pattern.
  String setDashPattern(List<double> pattern, double phase) {
    final patternStr = pattern.map((d) => d.toStringAsFixed(3)).join(' ');
    if (_dashPattern?.length == pattern.length &&
        _dashPhase == phase &&
        _dashPattern != null) {
      var same = true;
      for (var i = 0; i < pattern.length; i++) {
        if (_dashPattern![i] != pattern[i]) {
          same = false;
          break;
        }
      }
      if (same) return '';
    }
    _dashPattern = List.from(pattern);
    _dashPhase = phase;
    return '[$patternStr] ${phase.toStringAsFixed(3)} d\n';
  }

  /// Resets dash to solid line.
  String resetDash() {
    if (_dashPattern == null || _dashPattern!.isEmpty) return '';
    _dashPattern = [];
    _dashPhase = 0;
    return '[] 0 d\n';
  }

  /// Resets all state (for save/restore tracking).
  void reset() {
    _strokeColor = null;
    _fillColor = null;
    _lineWidth = null;
    _lineCap = null;
    _lineJoin = null;
    _dashPattern = null;
    _dashPhase = null;
  }

  /// Converts hex color to RGB values (0-1 range).
  List<String> _hexToRgb(String hex) {
    // Remove # if present
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return ['0', '0', '0'];

    final r = int.parse(h.substring(0, 2), radix: 16) / 255;
    final g = int.parse(h.substring(2, 4), radix: 16) / 255;
    final b = int.parse(h.substring(4, 6), radix: 16) / 255;

    return [
      r.toStringAsFixed(3),
      g.toStringAsFixed(3),
      b.toStringAsFixed(3),
    ];
  }
}
