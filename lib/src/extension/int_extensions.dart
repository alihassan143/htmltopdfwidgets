import 'package:htmltopdfwidgets/src/htmltagstyles.dart';
import 'package:pdf/widgets.dart';

extension IntConverter on int {
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

  TextStyle? getHeadingStyle(
    HtmlTagStyle customStyles,
  ) {
    switch (this) {
      case 1:
        return customStyles.h1Style;
      case 2:
        return customStyles.h2Style;
      case 3:
        return customStyles.h3Style;
      case 4:
        return customStyles.h4Style;
      case 5:
        return customStyles.h5Style;
      case 6:
        return customStyles.h6Style;
      default:
        return customStyles.h1Style;
    }
  }
}
