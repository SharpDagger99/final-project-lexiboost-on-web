import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Custom scroll behavior that enables drag scrolling on all platforms
/// including mouse drag on desktop, touch on mobile, stylus, and trackpad.
///
/// Usage:
/// ```dart
/// ScrollConfiguration(
///   behavior: CustomScrollBehavior(),
///   child: SingleChildScrollView(
///     child: YourContent(),
///   ),
/// )
/// ```
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  /// Customize scroll physics if needed
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }

  /// Enable overscroll indicator (glow effect on Android)
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // For a cleaner look on desktop, you can return child directly
    // to remove the glow effect. For mobile consistency, keep the glow.
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }

  /// Customize scrollbar appearance
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Show scrollbar on desktop/web for better UX
    if (MediaQuery.of(context).size.width >= 800) {
      return Scrollbar(
        controller: details.controller,
        thumbVisibility: false, // Auto-hide when not scrolling
        trackVisibility: false,
        thickness: 8,
        radius: const Radius.circular(4),
        child: child,
      );
    }
    return child;
  }
}

/// Alternative scroll behavior with always-visible scrollbar
class CustomScrollBehaviorWithScrollbar extends CustomScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true, // Always visible
      trackVisibility: true, // Show track as well
      thickness: 10,
      radius: const Radius.circular(5),
      child: child,
    );
  }
}

/// Scroll behavior with no overscroll effect (cleaner on desktop)
class CustomScrollBehaviorNoGlow extends CustomScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // No glow effect
  }
}

/// Extension to easily wrap widgets with custom scroll behavior
extension ScrollBehaviorExtension on Widget {
  /// Wrap this widget with custom drag-enabled scroll behavior
  Widget withDragScrolling({
    bool showScrollbar = false,
    bool removeGlow = false,
  }) {
    return Builder(
      builder: (context) {
        ScrollBehavior behavior;

        if (removeGlow && showScrollbar) {
          behavior = CustomScrollBehaviorWithScrollbar();
        } else if (removeGlow) {
          behavior = CustomScrollBehaviorNoGlow();
        } else if (showScrollbar) {
          behavior = CustomScrollBehaviorWithScrollbar();
        } else {
          behavior = CustomScrollBehavior();
        }

        return ScrollConfiguration(
          behavior: behavior,
          child: this,
        );
      },
    );
  }
}

/// Convenient wrapper widget for drag-scrollable content
class DragScrollableView extends StatelessWidget {
  final Widget child;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool showScrollbar;
  final bool removeGlow;
  final ScrollController? controller;

  const DragScrollableView({
    super.key,
    required this.child,
    this.physics,
    this.padding,
    this.showScrollbar = false,
    this.removeGlow = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    ScrollBehavior behavior;

    if (removeGlow && showScrollbar) {
      behavior = CustomScrollBehaviorWithScrollbar();
    } else if (removeGlow) {
      behavior = CustomScrollBehaviorNoGlow();
    } else if (showScrollbar) {
      behavior = CustomScrollBehaviorWithScrollbar();
    } else {
      behavior = CustomScrollBehavior();
    }

    return ScrollConfiguration(
      behavior: behavior,
      child: SingleChildScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Example usage:
/// 
/// ```dart
/// // Method 1: Using ScrollConfiguration
/// ScrollConfiguration(
///   behavior: CustomScrollBehavior(),
///   child: SingleChildScrollView(
///     child: Column(children: [...]),
///   ),
/// )
/// 
/// // Method 2: Using extension
/// SingleChildScrollView(
///   child: Column(children: [...]),
/// ).withDragScrolling()
/// 
/// // Method 3: Using DragScrollableView widget
/// DragScrollableView(
///   padding: EdgeInsets.all(16),
///   showScrollbar: true,
///   child: Column(children: [...]),
/// )
/// ```

