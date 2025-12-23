import 'package:xml/xml.dart';

/// Stores unknown XML attributes and child elements for round-trip preservation.
///
/// This "Shadow Model" ensures that when reading a DOCX file, any XML
/// attributes or elements that aren't formally modeled are preserved and
/// written back exactly as they were found.
///
/// Example usage:
/// ```dart
/// // When parsing an anchor element, extract unknown attributes
/// final extensions = XmlExtensionMap.extractFromElement(
///   anchorElement,
///   knownAttributes: {'distT', 'distB', 'simplePos'},
/// );
///
/// // Later, when writing back
/// extensions.writeAttributesTo(builder);
/// ```
class XmlExtensionMap {
  /// Unknown attributes: qualified name -> value
  final Map<String, String> attributes;

  /// Unknown child elements as raw XML strings
  final List<String> childElements;

  const XmlExtensionMap({
    this.attributes = const {},
    this.childElements = const [],
  });

  /// Returns true if there's no extension data to preserve.
  bool get isEmpty => attributes.isEmpty && childElements.isEmpty;

  /// Returns true if there is extension data to preserve.
  bool get isNotEmpty => !isEmpty;

  /// Extract unknown attributes from an element, given a set of known attribute names.
  ///
  /// [element] - The XML element to extract from
  /// [knownAttributes] - Set of attribute names (qualified) that are formally modeled
  ///
  /// Returns an [XmlExtensionMap] containing only the unknown attributes.
  static XmlExtensionMap extractFromElement(
    XmlElement element, {
    required Set<String> knownAttributes,
  }) {
    final unknownAttrs = <String, String>{};

    for (var attr in element.attributes) {
      final qualifiedName = attr.name.qualified;
      if (!knownAttributes.contains(qualifiedName)) {
        unknownAttrs[qualifiedName] = attr.value;
      }
    }

    return XmlExtensionMap(attributes: unknownAttrs);
  }

  /// Extract unknown child elements from an element, given a set of known element names.
  ///
  /// [element] - The XML element to extract from
  /// [knownChildren] - Set of element names (local names) that are formally modeled
  ///
  /// Returns an [XmlExtensionMap] containing only the unknown child elements.
  static XmlExtensionMap extractFromChildren(
    XmlElement element, {
    required Set<String> knownChildren,
  }) {
    final unknownChildren = <String>[];

    for (var child in element.children) {
      if (child is XmlElement) {
        if (!knownChildren.contains(child.name.local)) {
          unknownChildren.add(child.toXmlString());
        }
      }
    }

    return XmlExtensionMap(childElements: unknownChildren);
  }

  /// Extract both unknown attributes and children.
  static XmlExtensionMap extractFull(
    XmlElement element, {
    required Set<String> knownAttributes,
    required Set<String> knownChildren,
  }) {
    final attrs = extractFromElement(element, knownAttributes: knownAttributes);
    final children = extractFromChildren(element, knownChildren: knownChildren);

    return XmlExtensionMap(
      attributes: attrs.attributes,
      childElements: children.childElements,
    );
  }

  /// Writes the unknown attributes to an [XmlBuilder].
  void writeAttributesTo(XmlBuilder builder) {
    for (var entry in attributes.entries) {
      builder.attribute(entry.key, entry.value);
    }
  }

  /// Writes the unknown child elements to an [XmlBuilder].
  ///
  /// Note: This inserts raw XML strings, which requires the builder
  /// to support raw content insertion.
  void writeChildrenTo(XmlBuilder builder) {
    for (var childXml in childElements) {
      try {
        final fragment = XmlDocumentFragment.parse(childXml);
        for (var node in fragment.children) {
          builder.xml(node.toXmlString());
        }
      } catch (_) {
        // If parsing fails, skip this element
      }
    }
  }

  /// Merges this extension map with another, preferring values from [other].
  XmlExtensionMap merge(XmlExtensionMap other) {
    return XmlExtensionMap(
      attributes: {...attributes, ...other.attributes},
      childElements: [...childElements, ...other.childElements],
    );
  }

  @override
  String toString() {
    return 'XmlExtensionMap(attributes: $attributes, childElements: ${childElements.length} items)';
  }
}
