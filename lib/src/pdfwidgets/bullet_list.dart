import '../../htmltopdfwidgets.dart';

class BulletListItemWidget extends StatelessWidget {
  
  // Bullet list item widget with a bullet icon and content.
  
  final Widget child;
  final HtmlTagStyle customStyles;
  final bool nestedList;
  final bool withIndicator;

  BulletListItemWidget({
    required this.child,
    required this.customStyles,
    required this.nestedList,
    this.withIndicator = true
  });

  @override
  Widget build(Context context) {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if(withIndicator)
            _BulletedListIndicator(style: customStyles, nestedList: nestedList)
          else
            SizedBox(width: customStyles.listItemIndicatorWidth),
          Flexible(child: child),
        ],
      ),
    );
  }
}


class _BulletedListIndicator extends StatelessWidget {

  final HtmlTagStyle style;
  final bool nestedList;

  _BulletedListIndicator({required this.style, required this.nestedList});

  @override
  Widget build(Context context) {
    return SizedBox(
      width: style.listItemIndicatorWidth,
      height: style.bulletListIconSize,
      child: Padding(
        padding: style.listItemIndicatorPadding,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: style.bulletListDotSize,
            height: style.bulletListDotSize,
            decoration:
            nestedList?
            BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: style.bulletListIconColor ?? PdfColors.black,
                width: 1.0,
              ),
            ):

            BoxDecoration(
              shape: BoxShape.circle,
              color: style.bulletListIconColor ??
                  PdfColors.black,
            ),
          ),
        ),
      )
    );
  }
}
