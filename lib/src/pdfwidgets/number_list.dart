// Import the necessary dependencies from the 'htmltopdfwidgets.dart' file.
import '../../htmltopdfwidgets.dart';

// This function creates a default index (number) widget for a numbered list.
// It takes an 'index' (the current number), a 'font', a list of 'fontFallback' fonts,
// and 'customStyles' for styling.
Widget defaultIndex(int index,
    {Font? font,
    required List<Font> fontFallback,
    required HtmlTagStyle customStyles}) {
  return Container(
    width: 20,
    padding: const EdgeInsets.only(right: 5.0),
    child: Text('$index.', // Display the index as text.
        style: TextStyle(
          font: font, // Apply the specified font.
          fontFallback: fontFallback, // Use font fallbacks if needed.
        )..merge(
            customStyles.listIndexStyle)), // Apply custom styles for the index.
  );
}

// This function creates a numbered list child widget with its current number and properties.
// It takes a 'childValue' widget, 'index' (the current number), a 'font',
// a list of 'fontFallback' fonts, and 'customStyles' for styling.
Widget buildNumberWidget(
    Widget child,
    {
      required int index,
      Font? font,
      required List<Font> fontFallback,
      required HtmlTagStyle customStyles
    }) {
  return Container(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        defaultIndex(index,
            fontFallback: fontFallback, font: font, customStyles: customStyles),
        // Include the default index widget with specified properties.
        Flexible(child: child), // Include the main content child widget.
      ],
    ),
  );
}
