// Import the necessary dependencies from the 'htmltopdfwidgets.dart' file.
import '../../htmltopdfwidgets.dart';

// This function creates a bullet list child widget with a bullet icon and content.
// It takes a 'childValue' widget and 'customStyles' for styling.
Widget buildBulletwidget(Widget childValue,
    {required HtmlTagStyle customStyles}) {
  // Create a container to hold the child elements.
  Widget child = Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BulletedListIcon(style: customStyles), // Include the bullet icon.
        Flexible(child: childValue), // Include the main content child widget.
      ],
    ),
  );
  return child; // Return the resulting child widget.
}

// This private class represents the bullet list icon.
class _BulletedListIcon extends StatelessWidget {
  final HtmlTagStyle style;

  // Constructor to initialize the 'style' property.
  _BulletedListIcon({required this.style});

  @override
  Widget build(Context context) {
    return SizedBox(
      width: style.bulletIconContainerDimension,
      height: style.bulletIconContainerDimension,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Center(
          child: SizedBox(
            width: style.bulletListIconSize,
            height: style.bulletListIconSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle, // Bullet icon is circular.
                color: style.bulletListIconColor ??
                    PdfColors.black, // Apply custom color.
              ),
            ),
          ),
        ),
      ),
    );
  }
}
