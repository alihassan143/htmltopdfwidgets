import '../../htmltopdfwidgets.dart';

Widget buildQuotewidget(Widget childValue,
    {required HtmlTagStyle customStyles}) {
  Widget child = Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            width: 20,
            height: 20,
            child: VerticalDivider(
                color: customStyles.quoteBarColor ?? PdfColors.black)),
        Flexible(child: childValue),
      ],
    ),
  );
  return child;
}
