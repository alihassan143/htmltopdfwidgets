import '../../htmltopdfwidgets.dart';


class NumberListItemWidget extends StatelessWidget {
  // Number list item widget with a number index and content.
  final Widget child;
  final int index;
  final HtmlTagStyle customStyles;
  final bool withIndicator;

  NumberListItemWidget({
    required this.child,
    required this.index,
    required this.customStyles,
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
            _NumberListIndicator(
              style: customStyles,
              index: index
            )
          else
            SizedBox(width: customStyles.listItemIndicatorWidth),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _NumberListIndicator extends StatelessWidget {
  final HtmlTagStyle style;
  final int index;

  _NumberListIndicator({required this.style, required this.index});

  @override
  Widget build(Context context) {
    return SizedBox(
      width: style.listItemIndicatorWidth,
      height: style.bulletListIconSize,
      child: Padding(
        padding: style.listItemIndicatorPadding,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
              '$index.',
              style: style.listIndexStyle,
          )
        ),
      ),
    );
  }
}