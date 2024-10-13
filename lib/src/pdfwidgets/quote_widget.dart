import '../../htmltopdfwidgets.dart';

Widget buildQuoteWidget(Widget child, {required HtmlTagStyle customStyles}) {
  return Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: VerticalDivider(
            color: customStyles.quoteBarColor ?? PdfColors.black,
          ),
        ),
        Flexible(child: child),
      ],
    ),
  );
}
