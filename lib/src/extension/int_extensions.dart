import 'package:htmltopdfwidgets/src/htmltagstyles.dart';
import 'package:pdf/widgets.dart';

extension IntConverter on int {

  TextStyle? getHeadingStyle(
    HtmlTagStyle customStyles,
  ) {
    switch (this) {
      case 1:
        return TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h1Style);
      case 2:
        return TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h2Style);
      case 3:
        return TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h3Style);
      case 4:
        return TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h4Style);
      case 5:
        return TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h5Style);
      case 6:
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h6Style);
      default:
        return TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h1Style);
    }
  }
}
