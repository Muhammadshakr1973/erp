class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMax = 767.9;
  static const double tabletMin = 768.0;
  static const double desktopMin = 1024.0;
  static const double wideMin = 1440.0;

  static bool isMobile(double width) => width <= mobileMax;
  static bool isTablet(double width) => width >= tabletMin && width < desktopMin;
  static bool isDesktop(double width) => width >= desktopMin;
  static bool isWide(double width) => width >= wideMin;
}
