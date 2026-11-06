import 'package:flutter/material.dart';

extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isSmallPhone => screenWidth < 380;
  bool get isPhone => screenWidth < 540;
  bool get isTablet => screenWidth >= 540;

  double get horizontalPadding => isTablet ? 32 : (isPhone ? 16 : 12);

  int get detailCardColumns {
    if (isTablet) return 4;
    if (isPhone) return 3;
    return 2;
  }
}
