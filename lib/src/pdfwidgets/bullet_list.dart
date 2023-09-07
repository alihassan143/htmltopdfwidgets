import '../../htmltopdfwidgets.dart';

Widget buildBulletwidget(Widget childValue,
    {required HtmlTagStyle customStyles}) {
  Widget child = Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BulletedListIcon(style: customStyles),
        Flexible(child: childValue),
      ],
    ),
  );
  return child;
}

class _BulletedListIcon extends StatelessWidget {
  final HtmlTagStyle style;
  _BulletedListIcon({required this.style});

  @override
  Widget build(Context context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Center(
            child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.bulletListIconColor ?? PdfColors.black))),
      ),
    );
  }
}
