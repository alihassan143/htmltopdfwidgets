import '../../htmltopdfwidgets.dart';


class NumberListItemWidget extends StatelessWidget {

  final Widget child;
  final int index;
  final HtmlTagStyle customStyles;
  final bool withIndicator;
  final TextStyle baseTextStyle;

  NumberListItemWidget({
    required this.child,
    required this.index,
    required this.customStyles,
    this.withIndicator = true,
    required this.baseTextStyle
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
              index: index,
              baseTextStyle: baseTextStyle
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
  final TextStyle baseTextStyle;

  _NumberListIndicator({required this.style, required this.index, required this.baseTextStyle});

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
            style: style.listIndexStyle??baseTextStyle,
          )
        ),
      ),
    );
  }
}