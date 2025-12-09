# Dashboard Navigation Pattern

## Overview
This document explains the callback-based navigation pattern used in the Teacher Dashboard to ensure consistent navigation across all pages in the teacher interface.

## Implementation

### 1. Parent Controller (teacher_home.dart)
The `MyTeacherHome` widget acts as the main controller that manages the `selectedIndex` state for the `IndexedStack`.

**Key Changes:**
- Changed `pages` from a static list to a dynamic `_buildPages()` method
- Passes `onNavigate` callback to `MyStudentDashboards` widget
- The callback updates the `selectedIndex` state when called

```dart
List<Widget> _buildPages() {
  return [
    MyStudentDashboards(
      onNavigate: (index) {
        setState(() {
          selectedIndex = index;
        });
      },
    ),
    const MyClass1(),
    const MyAddStudent(),
    const MyStudentRequest(),
    const MyGameCreate(),
    // ... other pages
  ];
}
```

### 2. Child Widget (mystudent_dashboard.dart)
The `MyStudentDashboards` widget receives the callback and uses it to trigger navigation.

**Key Changes:**
- Added optional `onNavigate` callback parameter
- Uses callback instead of `findAncestorStateOfType` for navigation
- Cleaner and more maintainable approach

```dart
class MyStudentDashboards extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const MyStudentDashboards({super.key, this.onNavigate});
  // ...
}

// In navigation confirmation:
navigationAction = () {
  Navigator.pop(context);
  if (widget.onNavigate != null) {
    widget.onNavigate!(1); // Navigate to Classes tab
  }
};
```

## Navigation Mappings

Dashboard cards navigate to the following pages:

| Card Title | Destination | Index | Action |
|------------|-------------|-------|--------|
| Total Classes | Classes | 1 | Uses callback |
| Total Students | Students | 2 | Uses callback |
| Pending Requests | Student Requests | 3 | Uses callback |
| Published Games | Published Games | N/A | Uses route navigation |

## Benefits

1. **Type Safety**: Callback approach is type-safe and doesn't rely on dynamic casting
2. **Maintainability**: Clear parent-child communication pattern
3. **Testability**: Easier to test with injectable callbacks
4. **Consistency**: Same pattern can be used across all child pages
5. **No Context Issues**: Avoids potential issues with finding ancestor states

## Usage Pattern for Other Pages

To implement similar navigation in other child pages:

```dart
// 1. Add callback parameter to widget
class MyChildPage extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const MyChildPage({super.key, this.onNavigate});
  // ...
}

// 2. Use callback for navigation
void _navigateToPage(int index) {
  if (widget.onNavigate != null) {
    widget.onNavigate!(index);
  }
}

// 3. Pass callback from parent
MyChildPage(
  onNavigate: (index) {
    setState(() {
      selectedIndex = index;
    });
  },
)
```

## Files Modified

- `final-project-lexiboost-on-web/lib/teacher/teacher_home.dart`
- `final-project-lexiboost-on-web/lib/teacher/mystudent_dashboard.dart`

## Testing

To test the navigation:
1. Login as a teacher
2. View the Dashboard (default page)
3. Click on any stat card (Classes, Students, Requests)
4. Confirm navigation in the dialog
5. Verify the correct page loads
6. Verify the sidebar highlights the correct menu item

## Future Enhancements

Consider implementing this pattern for:
- Quick actions in other pages
- Breadcrumb navigation
- Deep linking support
- Navigation history tracking
