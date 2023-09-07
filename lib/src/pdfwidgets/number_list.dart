import '../../htmltopdfwidgets.dart';

Widget defaultIndex(int index,
    {Font? font,
    required List<Font> fontFallback,
    required HtmlTagStyle customStyles}) {
  return Container(
    width: 20,
    padding: const EdgeInsets.only(right: 5.0),
    child: Text('$index.',
        style: TextStyle(
          font: font,
          fontFallback: fontFallback,
        )..merge(customStyles.listIndexStyle)),
  );
}

//return the number list child with its current number and its all properties
Widget buildNumberwdget(Widget childValue,
    {required int index,
    Font? font,
    required List<Font> fontFallback,
    required HtmlTagStyle customStyles}) {
  Widget child = Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        defaultIndex(index,
            fontFallback: fontFallback, font: font, customStyles: customStyles),
        Flexible(child: childValue),
      ],
    ),
  );
  return child;
}
