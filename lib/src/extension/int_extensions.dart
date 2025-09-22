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

//it apply custom user style from provided constructor
  TextStyle? getHeadingStyle(
    HtmlTagStyle customStyles,
  ) {
    switch (this) {
      case 1:
        return customStyles.h1Style ?? customStyles.headingStyle;
      case 2:
        return customStyles.h2Style ?? customStyles.headingStyle;
      case 3:
        return customStyles.h3Style ?? customStyles.headingStyle;
      case 4:
        return customStyles.h4Style ?? customStyles.headingStyle;
      case 5:
        return customStyles.h5Style ?? customStyles.headingStyle;
      case 6:
        return customStyles.h6Style ?? customStyles.headingStyle;
      default:
        return customStyles.h1Style ?? customStyles.headingStyle;
    }
  }
}
