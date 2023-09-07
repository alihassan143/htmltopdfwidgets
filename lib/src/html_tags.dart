class HTMLTags {
  static const h1 = 'h1';
  static const h2 = 'h2';
  static const h3 = 'h3';
  static const h4 = 'h4';
  static const h5 = 'h5';
  static const h6 = 'h6';
  static const orderedList = 'ol';
  static const unorderedList = 'ul';
  static const list = 'li';
  static const paragraph = 'p';
  static const image = 'img';
  static const anchor = 'a';
  static const italic = 'i';
  static const em = 'em';
  static const bold = 'b';
  static const underline = 'u';
  static const strikethrough = 's';
  static const del = 'del';
  static const strong = 'strong';
  static const checkbox = 'input';
  static const span = 'span';
  static const code = 'code';
  static const blockQuote = 'blockquote';
  static const div = 'div';
  static const divider = 'hr';
  static const table = 'table';
  static const tableRow = 'tr';
  static const br = 'br';
  static const tableheader = "th";
  static const tabledata = "td";

  static List<String> formattingElements = [
    HTMLTags.anchor,
    HTMLTags.italic,
    HTMLTags.em,
    HTMLTags.bold,
    HTMLTags.underline,
    HTMLTags.del,
    HTMLTags.strong,
    HTMLTags.span,
    HTMLTags.code,
    HTMLTags.strikethrough,
  ];

  static List<String> specialElements = [
    HTMLTags.h1,
    HTMLTags.h2,
    HTMLTags.h3,
    HTMLTags.h4,
    HTMLTags.h5,
    HTMLTags.h6,
    HTMLTags.table,
    HTMLTags.div,
    HTMLTags.br,
    HTMLTags.unorderedList,
    HTMLTags.orderedList,
    HTMLTags.list,
    HTMLTags.paragraph,
    HTMLTags.blockQuote,
    HTMLTags.checkbox,
    HTMLTags.image
  ];

  static bool isTopLevel(String tag) {
    return tag == h1 ||
        tag == h2 ||
        tag == h3 ||
        tag == h4 ||
        tag == h5 ||
        tag == h6 ||
        tag == table ||
        tag == checkbox ||
        tag == paragraph ||
        tag == div ||
        tag == blockQuote;
  }
}

enum AttributeType { table, tablerow, none }
