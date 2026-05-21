import 'package:flutter/widgets.dart';

enum DeviceType {
  mobile,
  tablet,
}

class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static const double tabletMinWidth = 600;
}

class Responsive {
  Responsive._();

  static DeviceType deviceTypeOf(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.tabletMinWidth
        ? DeviceType.tablet
        : DeviceType.mobile;
  }

  static bool isTablet(BuildContext context) {
    return deviceTypeOf(context) == DeviceType.tablet;
  }

  static bool isMobile(BuildContext context) {
    return deviceTypeOf(context) == DeviceType.mobile;
  }

  static T value<T>({
    required BuildContext context,
    required T mobile,
    required T tablet,
  }) {
    return isTablet(context) ? tablet : mobile;
  }
}
