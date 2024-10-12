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
        ).merge(customStyles.h1Style).copyWith(decoration: customStyles.h1Style?.decoration);
      case 2:
        return TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h2Style).copyWith(decoration: customStyles.h2Style?.decoration);
      case 3:
        return TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h3Style).copyWith(decoration: customStyles.h3Style?.decoration);
      case 4:
        return TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h4Style).copyWith(decoration: customStyles.h4Style?.decoration);
      case 5:
        return TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h5Style).copyWith(decoration: customStyles.h5Style?.decoration);
      case 6:
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h6Style).copyWith(decoration: customStyles.h6Style?.decoration);
      default:
        return TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ).merge(customStyles.h1Style).copyWith(decoration: customStyles.h1Style?.decoration);
    }
  }
}
