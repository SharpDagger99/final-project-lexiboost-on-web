// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';
import 'package:lexi_on_web/services/settings_service.dart';

class MySettingsAdmin extends StatefulWidget {
  const MySettingsAdmin({super.key});

  @override
  State<MySettingsAdmin> createState() => _MySettingsAdminState();
}

class _MySettingsAdminState extends State<MySettingsAdmin>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _autoSaveEnabled = true;
  bool _showAutoSaveHelp = false;
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _helpAnimationController;
  late Animation<double> _helpAnimation;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _helpAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _helpAnimation = CurvedAnimation(
      parent: _helpAnimationController,
      curve: Curves.easeInOut,
    );

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Load current settings
    _loadSettings();
  }

  /// Load current settings from Firestore
  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final autoSaveEnabled = await _settingsService.getAutoSaveEnabled();

      if (mounted) {
        setState(() {
          _autoSaveEnabled = autoSaveEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load settings: $e',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh settings when app becomes active
      _loadSettings();
    }
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    _helpAnimationController.dispose();
    super.dispose();
  }

  void _toggleAutoSaveHelp() {
    setState(() {
      _showAutoSaveHelp = !_showAutoSaveHelp;
    });

    if (_showAutoSaveHelp) {
      _helpAnimationController.forward();
    } else {
      _helpAnimationController.reverse();
    }
  }

  void _saveSettings() async {
    if (_isSaving) return; // Prevent multiple saves

    try {
      setState(() {
        _isSaving = true;
      });

      // Save the auto-save setting to Firestore
      await _settingsService.setAutoSaveEnabled(_autoSaveEnabled);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings saved successfully!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save settings: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings: $e',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
       backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2C2A),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2C2A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editor Settings',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customize your game editor experience',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Loading indicator for initial load
              if (_isLoading)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2C2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading settings...',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Auto Save Settings Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2C2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Auto Save Toggle Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _autoSaveEnabled
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _autoSaveEnabled
                                  ? Icons.save
                                  : Icons.save_outlined,
                              color: _autoSaveEnabled
                                  ? Colors.green
                                  : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto Save',
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _autoSaveEnabled ? 'Enabled' : 'Disabled',
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 14 : 16,
                                    color: _autoSaveEnabled
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Help Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _showAutoSaveHelp
                                    ? Icons.help
                                    : Icons.help_outline,
                                color: _showAutoSaveHelp
                                    ? Colors.blue
                                    : Colors.blue,
                                size: 20,
                              ),
                              onPressed: _toggleAutoSaveHelp,
                              tooltip: 'Learn more about Auto Save',
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Toggle Switch
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: _autoSaveEnabled,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _autoSaveEnabled = value;
                                      });
                                    },
                              activeColor: Colors.green,
                              activeTrackColor: Colors.green.withOpacity(0.3),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),

                      // Help Container (Animated)
                      SizeTransition(
                        sizeFactor: _helpAnimation,
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto Save Information',
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'When enabled, the editor automatically saves your progress after you stop editing for 10 seconds. This helps prevent data loss and provides a seamless editing experience.',
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 13 : 14,
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Save Button
              Align(
                alignment: Alignment.bottomRight,
                child: AnimatedButton(
                  width: isMobile ? 120 : 140,
                  height: isMobile ? 50 : 56,
                  color: _isSaving ? Colors.grey : Colors.green,
                  onPressed: () {
                    if (!_isSaving) {
                      _saveSettings();
                    }
                  },
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.save,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Save',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
            ),
      ),
    );
  }
}