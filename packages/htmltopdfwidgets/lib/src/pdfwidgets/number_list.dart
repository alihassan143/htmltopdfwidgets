// Import the necessary dependencies from the 'htmltopdfwidgets.dart' file.
import '../../htmltopdfwidgets.dart';

// This function creates a default index (number) widget for a numbered list.
// It takes an 'index' (the current number), a 'font', a list of 'fontFallback' fonts,
// and 'customStyles' for styling.
Widget defaultIndex(int index,
    {required TextStyle baseTextStyle, required HtmlTagStyle customStyles}) {
  return Container(
    width: 20,
    padding: const EdgeInsets.only(right: 5.0),
    child: Text('$index.', // Display the index as text.
        style: baseTextStyle.merge(
            customStyles.listIndexStyle)), // Apply custom styles for the index.
  );
}

// This function creates a numbered list child widget with its current number and properties.
// It takes a 'childValue' widget, 'index' (the current number), a 'font',
// a list of 'fontFallback' fonts, and 'customStyles' for styling.
Widget buildNumberwdget(Widget childValue,
    {required int index,
    required TextStyle baseTextStyle,
    required HtmlTagStyle customStyles}) {
  Widget child = Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        defaultIndex(index,
            baseTextStyle: baseTextStyle, customStyles: customStyles),
        // Include the default index widget with specified properties.
        Flexible(child: childValue), // Include the main content child widget.
      ],
    ),
  );
  return child; // Return the resulting child widget.
}
