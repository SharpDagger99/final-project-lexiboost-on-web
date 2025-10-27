import 'package:flutter/material.dart';

/// Responsive design helper class with breakpoints and utilities
class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 800;
  static const double desktopBreakpoint = 1200;

  /// Get screen width
  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if mobile screen
  static bool isMobile(BuildContext context) {
    return getWidth(context) < mobileBreakpoint;
  }

  /// Check if tablet screen
  static bool isTablet(BuildContext context) {
    final width = getWidth(context);
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if desktop screen
  static bool isDesktop(BuildContext context) {
    return getWidth(context) >= desktopBreakpoint;
  }

  /// Get device type as enum
  static DeviceType getDeviceType(BuildContext context) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint) return DeviceType.desktop;
    if (width >= tabletBreakpoint) return DeviceType.tabletLandscape;
    if (width >= mobileBreakpoint) return DeviceType.tabletPortrait;
    return DeviceType.mobile;
  }

  /// Get responsive padding based on screen size
  static double getPadding(BuildContext context, {double multiplier = 1.0}) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint) return 24 * multiplier;
    if (width >= tabletBreakpoint) return 20 * multiplier;
    if (width >= mobileBreakpoint) return 16 * multiplier;
    return 12 * multiplier;
  }

  /// Get responsive spacing based on screen size
  static double getSpacing(BuildContext context, {double multiplier = 1.0}) {
    final width = getWidth(context);
    if (width >= tabletBreakpoint) return 16 * multiplier;
    return 12 * multiplier;
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context, {required double base}) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint) return base;
    if (width >= tabletBreakpoint) return base * 0.95;
    if (width >= mobileBreakpoint) return base * 0.9;
    return base * 0.85;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, {double base = 24}) {
    return getFontSize(context, base: base);
  }

  /// Get grid cross axis count based on screen size
  static int getGridCrossAxisCount(BuildContext context, {
    int mobile = 1,
    int tabletPortrait = 2,
    int tabletLandscape = 3,
    int desktop = 4,
  }) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint) return desktop;
    if (width >= tabletBreakpoint) return tabletLandscape;
    if (width >= mobileBreakpoint) return tabletPortrait;
    return mobile;
  }

  /// Get responsive value based on device type
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tabletPortrait,
    T? tabletLandscape,
    T? desktop,
  }) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint && desktop != null) return desktop;
    if (width >= tabletBreakpoint && tabletLandscape != null) {
      return tabletLandscape;
    }
    if (width >= mobileBreakpoint && tabletPortrait != null) {
      return tabletPortrait;
    }
    return mobile;
  }

  /// Get responsive chart height
  static double getChartHeight(BuildContext context) {
    final width = getWidth(context);
    if (width >= desktopBreakpoint) return 300;
    if (width >= tabletBreakpoint) return 280;
    if (width >= mobileBreakpoint) return 250;
    return 220;
  }

  /// Get responsive button height
  static double getButtonHeight(BuildContext context) {
    return isMobile(context) ? 45 : 50;
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context, {double base = 16}) {
    return isMobile(context) ? base * 0.75 : base;
  }

  /// Get orientation-aware aspect ratio
  static double getAspectRatio(BuildContext context, {
    required double portrait,
    required double landscape,
  }) {
    final orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.portrait ? portrait : landscape;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Calculate responsive width percentage
  static double widthPercent(BuildContext context, double percent) {
    return getWidth(context) * (percent / 100);
  }

  /// Calculate responsive height percentage
  static double heightPercent(BuildContext context, double percent) {
    return getHeight(context) * (percent / 100);
  }

  /// Get max content width (useful for centering on large screens)
  static double getMaxContentWidth(BuildContext context) {
    final width = getWidth(context);
    if (width > 1400) return 1400;
    return width;
  }

  /// Center content on large screens
  static Widget centerOnLargeScreen(BuildContext context, Widget child) {
    if (isDesktop(context)) {
      return Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: getMaxContentWidth(context)),
          child: child,
        ),
      );
    }
    return child;
  }
}

/// Device type enumeration
enum DeviceType {
  mobile,
  tabletPortrait,
  tabletLandscape,
  desktop,
}

/// Responsive breakpoint class for custom breakpoints
class Breakpoint {
  final double mobile;
  final double tablet;
  final double desktop;

  const Breakpoint({
    this.mobile = 600,
    this.tablet = 800,
    this.desktop = 1200,
  });

  bool isMobile(double width) => width < mobile;
  bool isTablet(double width) => width >= mobile && width < desktop;
  bool isDesktop(double width) => width >= desktop;
}

/// Extension on BuildContext for easier access to responsive helpers
extension ResponsiveExtension on BuildContext {
  /// Check if current screen is mobile
  bool get isMobile => ResponsiveHelper.isMobile(this);

  /// Check if current screen is tablet
  bool get isTablet => ResponsiveHelper.isTablet(this);

  /// Check if current screen is desktop
  bool get isDesktop => ResponsiveHelper.isDesktop(this);

  /// Get screen width
  double get screenWidth => ResponsiveHelper.getWidth(this);

  /// Get screen height
  double get screenHeight => ResponsiveHelper.getHeight(this);

  /// Get device type
  DeviceType get deviceType => ResponsiveHelper.getDeviceType(this);

  /// Get responsive padding
  double responsivePadding([double multiplier = 1.0]) {
    return ResponsiveHelper.getPadding(this, multiplier: multiplier);
  }

  /// Get responsive spacing
  double responsiveSpacing([double multiplier = 1.0]) {
    return ResponsiveHelper.getSpacing(this, multiplier: multiplier);
  }

  /// Get responsive font size
  double responsiveFontSize(double base) {
    return ResponsiveHelper.getFontSize(this, base: base);
  }
}

