/// This class defines various constants for supported rendering types
/// and attributes in a text processing system. It categorizes them into
/// partial rendering types and global rendering types.

class BuiltInAttributeKey {
  // Partial rendering types
  static String bold = 'bold'; // Text should be displayed in bold.
  static String italic = 'italic'; // Text should be displayed in italic.
  static String underline = 'underline'; // Text should be underlined.
  static String strikethrough =
      'strikethrough'; // Text should have a strikethrough line.
  static String color = 'color'; // Text color customization.
  static String backgroundColor =
      'backgroundColor'; // Background color customization.
  static String font = 'font'; // Font customization.
  static String href = 'href'; // Hyperlink attribute for text.

  // Global rendering types
  static String subtype =
      'subtype'; // Subtype for customizing rendering behavior.
  static String heading =
      'heading'; // Text should be treated as a heading (h1, h2, h3, etc.).
  static String h1 = 'h1'; // Heading level 1.
  static String h2 = 'h2'; // Heading level 2.
  static String h3 = 'h3'; // Heading level 3.
  static String h4 = 'h4'; // Heading level 4.
  static String h5 = 'h5'; // Heading level 5.
  static String h6 = 'h6'; // Heading level 6.

  static String bulletedList =
      'bulleted-list'; // Text should be displayed in a bulleted list.
  static String numberList =
      'number-list'; // Text should be displayed in a numbered list.

  static String quote = 'quote'; // Text should be displayed as a blockquote.
  static String checkbox =
      'checkbox'; // Text should be displayed as a checkbox.
  static String code = 'code'; // Text should be displayed as code.
  static String number =
      'number'; // Text should be displayed as a numbered item.

  // Lists of partial style keys and global style keys
  static List<String> partialStyleKeys = [
    bold,
    italic,
    underline,
    strikethrough,
    backgroundColor,
    color,
    href,
    code,
  ];

  static List<String> globalStyleKeys = [
    subtype,
    heading,
    checkbox,
    bulletedList,
    numberList,
    quote,
  ];
}
