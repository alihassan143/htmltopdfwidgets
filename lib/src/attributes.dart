/// This class defines various constants for supported rendering types
/// and attributes in a text processing system. It categorizes them into
/// partial rendering types and global rendering types.

class BuiltInAttributeKey {

  // Partial rendering types
  static String bold = 'bold';
  static String italic = 'italic';
  static String underline = 'underline';
  static String strikethrough = 'strikethrough';
  static String color = 'color';
  static String backgroundColor = 'backgroundColor';
  static String font = 'font';
  static String href = 'href';

  // Global rendering types
  static String subtype = 'subtype';
  static String heading = 'heading';
  static String h1 = 'h1';
  static String h2 = 'h2';
  static String h3 = 'h3';
  static String h4 = 'h4';
  static String h5 = 'h5';
  static String h6 = 'h6';

  static String bulletedList = 'bulleted-list';
  static String numberList = 'number-list';

  static String quote = 'quote';
  static String checkbox = 'checkbox';
  static String code = 'code';
  static String number = 'number';

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
