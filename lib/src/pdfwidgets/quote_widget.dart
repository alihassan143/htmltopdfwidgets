// Import the necessary dependencies from the 'htmltopdfwidgets.dart' file.
import '../../htmltopdfwidgets.dart';

// Define a function named 'buildQuotewidget' that takes a 'childValue' Widget
// and a required 'customStyles' parameter of type 'HtmlTagStyle'.
Widget buildQuotewidget(Widget childValue, {required HtmlTagStyle customStyles}) {
  // Create a Widget named 'child' which will be returned by this function.
  Widget child = Container(
    // Create a Container widget to hold the child elements.
    child: Row(
      // Create a Row widget to arrange its children horizontally.
      crossAxisAlignment: CrossAxisAlignment.start,
      // Align children vertically at the top of the row.
      mainAxisAlignment: MainAxisAlignment.start,
      // Align children horizontally to the start of the row.
      mainAxisSize: MainAxisSize.min,
      // Allow the row to occupy the minimum horizontal space necessary.
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: VerticalDivider(
            // Create a SizedBox with a fixed width and height and add a VerticalDivider.
            color: customStyles.quoteBarColor ?? PdfColors.black,
            // Set the divider color to 'customStyles.quoteBarColor', if defined,
            // otherwise use PdfColors.black as the default color.
          ),
        ),
        Flexible(child: childValue), // Add the 'childValue' Widget inside a Flexible container.
      ],
    ),
  );
  return child; // Return the 'child' widget as the result of this function.
}
