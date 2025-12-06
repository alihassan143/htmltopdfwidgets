import 'package:htmltopdfwidgets/src/htmltagstyles.dart';
import 'package:pdf/widgets.dart';

extension IntConverter on int {
  //givee default font size for the heading tag
  double get getHeadingSize {
    switch (this) {
      case 1:
        return 32;
      case 2:
        return 28;
      case 3:
        return 20;
      case 4:
        return 17;
      case 5:
        return 14;
      case 6:
        return 10;
      default:
        return 32;
    }
  }

//it apply custom user style from provided constructor with fallback
  TextStyle? getHeadingStyle(
    HtmlTagStyle customStyles,
  ) {
    TextStyle? specificStyle;
    switch (this) {
      case 1:
        specificStyle = customStyles.h1Style;
        break;
      case 2:
        specificStyle = customStyles.h2Style;
        break;
      case 3:
        specificStyle = customStyles.h3Style;
        break;
      case 4:
        specificStyle = customStyles.h4Style;
        break;
      case 5:
        specificStyle = customStyles.h5Style;
        break;
      case 6:
        specificStyle = customStyles.h6Style;
        break;
      default:
        specificStyle = customStyles.h1Style;
        break;
    }
    // Fallback to headingStyle if specific style is not provided
    return specificStyle ?? customStyles.headingStyle;
  }
}
