// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads, avoid_print

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart'; 
import 'package:image_picker/image_picker.dart';

class MyTeacherProfile extends StatefulWidget {
  const MyTeacherProfile({super.key});

  @override
  State<MyTeacherProfile> createState() => _MyTeacherProfileState();
}

class _MyTeacherProfileState extends State<MyTeacherProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image to Firebase Storage
  Future<String?> _uploadImageToStorage(XFile imageFile, String userId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final ref = _storage.ref().child('profileImage/$userId.jpg');
      
      // Upload the file
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _showEditDialog() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final userData = userDoc.data() ?? {};

    final TextEditingController fullnameController = TextEditingController(
      text: userData['fullname'] ?? '',
    );
    final TextEditingController mobileController = TextEditingController(
      text: userData['mobileNumber'] ?? '',
    );
    final TextEditingController addressController = TextEditingController(
      text: userData['address'] ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: userData['description'] ?? '',
    );
    final TextEditingController noteController = TextEditingController(
      text: userData['note'] ?? '',
    );

    // Initialize schedules list from Firestore
    List<Map<String, dynamic>> schedules = [];
    if (userData['schedules'] != null && userData['schedules'] is List) {
      schedules = List<Map<String, dynamic>>.from(userData['schedules']);
    } else if (userData['schedule'] != null &&
        userData['schedule'].toString().isNotEmpty &&
        userData['schedule'] != 'Empty') {
      // Migrate old single schedule to new format
      schedules = [
        {'name': 'Schedule 1', 'content': userData['schedule']},
      ];
    }

    // If no schedules exist, add one default
    if (schedules.isEmpty) {
      schedules.add({'name': 'Schedule 1', 'content': ''});
    }

    // Create controllers for each schedule
    List<TextEditingController> scheduleControllers = schedules
        .map((s) => TextEditingController(text: s['content'] ?? ''))
        .toList();

    String? newProfileImageUrl = userData['profileImageUrl'];
    XFile? selectedImageFile;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: 600,
                constraints: const BoxConstraints(maxHeight: 750),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Profile',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Update your information',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Profile Image
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                print('Starting image picker...');
                                final ImagePicker picker = ImagePicker();
                                
                                XFile? image;
                                if (kIsWeb) {
                                  // For web, use pickImage without specifying source
                                  // This opens the browser's file picker
                                  print('Using web image picker');
                                  image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1024,
                                    maxHeight: 1024,
                                    imageQuality: 85,
                                  );
                                } else {
                                  // For mobile, show dialog to choose source
                                  print('Using mobile image picker');
                                  final source = await showDialog<ImageSource>(
                                    context: dialogContext,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        'Choose Image Source',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_library,
                                              color: Colors.blue,
                                            ),
                                            title: Text(
                                              'Gallery',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            onTap: () => Navigator.pop(
                                              context,
                                              ImageSource.gallery,
                                            ),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.blue,
                                            ),
                                            title: Text(
                                              'Camera',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            onTap: () => Navigator.pop(
                                              context,
                                              ImageSource.camera,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  
                                  if (source != null) {
                                    image = await picker.pickImage(
                                      source: source,
                                      maxWidth: 1024,
                                      maxHeight: 1024,
                                      imageQuality: 85,
                                    );
                                  }
                                }
                                
                                if (image != null) {
                                  print('Image selected: ${image.name}');
                                  setDialogState(() {
                                    selectedImageFile = image;
                                  });
                                } else {
                                  print('No image selected');
                                }
                              } catch (e, stackTrace) {
                                print('Error picking image: $e');
                                print('Stack trace: $stackTrace');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to pick image: ${e.toString()}',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Stack(
                              children: [
                                FutureBuilder(
                                  future: selectedImageFile?.readAsBytes(),
                                  builder: (context, snapshot) {
                                    ImageProvider? imageProvider;
                                    
                                    if (snapshot.hasData && snapshot.data != null) {
                                      imageProvider = MemoryImage(snapshot.data!);
                                    } else if (newProfileImageUrl != null && newProfileImageUrl.isNotEmpty) {
                                      imageProvider = NetworkImage(newProfileImageUrl);
                                    }
                                    
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.blue,
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.white,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click to upload profile image',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full Name
                        _buildEditField(
                          'Full Name',
                          fullnameController,
                          Icons.person,
                        ),
                        const SizedBox(height: 16),

                        // Mobile Number
                        _buildEditField(
                          'Mobile Number',
                          mobileController,
                          Icons.phone,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        _buildEditField(
                          'Address',
                          addressController,
                          Icons.location_on,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        _buildEditField(
                          'Description',
                          descriptionController,
                          Icons.description,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Schedules Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Schedules',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  schedules.add({
                                    'name': 'Schedule ${schedules.length + 1}',
                                    'content': '',
                                  });
                                  scheduleControllers.add(
                                    TextEditingController(),
                                  );
                                });
                              },
                              tooltip: 'Add Schedule',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Schedule List
                        ...List.generate(schedules.length, (index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          schedules[index]['name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (schedules.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            scheduleControllers[index]
                                                .dispose();
                                            schedules.removeAt(index);
                                            scheduleControllers.removeAt(index);
                                            // Renumber remaining schedules
                                            for (
                                              int i = 0;
                                              i < schedules.length;
                                              i++
                                            ) {
                                              schedules[i]['name'] =
                                                  'Schedule ${i + 1}';
                                            }
                                          });
                                        },
                                        tooltip: 'Remove Schedule',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: scheduleControllers[index],
                                  maxLines: 2,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter schedule details (e.g., Mon-Fri 9AM-5PM)',
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Note
                        _buildEditField(
                          'Note',
                          noteController,
                          Icons.note,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedButton(
                              width: 100,
                              height: 45,
                              color: Colors.grey[300]!,
                              shadowDegree: ShadowDegree.light,
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedButton(
                              width: 120,
                              height: 45,
                              color: Colors.blue,
                              shadowDegree: ShadowDegree.light,
                              onPressed: () async {
                                try {
                                  // Show loading
                                  showDialog(
                                    context: dialogContext,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  // Upload image if selected
                                  String? uploadedImageUrl;
                                  if (selectedImageFile != null) {
                                    uploadedImageUrl = await _uploadImageToStorage(
                                      selectedImageFile!,
                                      currentUser.uid,
                                    );
                                    if (uploadedImageUrl == null) {
                                      Navigator.pop(dialogContext); // Close loading
                                      throw Exception('Failed to upload image');
                                    }
                                  }

                                  // Update schedules with current controller values
                                  for (int i = 0; i < schedules.length; i++) {
                                    schedules[i]['content'] =
                                        scheduleControllers[i].text.trim();
                                  }

                                  await _firestore
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .update({
                                        'fullname':
                                            fullnameController.text
                                                .trim()
                                                .isEmpty
                                            ? 'Unknown'
                                            : fullnameController.text.trim(),
                                        'mobileNumber':
                                            mobileController.text.trim().isEmpty
                                            ? 'Unknown'
                                            : mobileController.text.trim(),
                                        'address':
                                            addressController.text
                                                .trim()
                                                .isEmpty
                                            ? 'Unknown'
                                            : addressController.text.trim(),
                                        'description':
                                            descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? 'Empty'
                                            : descriptionController.text.trim(),
                                        'schedules': schedules,
                                        'note':
                                            noteController.text.trim().isEmpty
                                            ? 'Empty'
                                            : noteController.text.trim(),
                                        if (uploadedImageUrl != null)
                                          'profileImageUrl': uploadedImageUrl,
                                      });

                                  Navigator.pop(dialogContext); // Close loading

                                  // Dispose schedule controllers
                                  for (var controller in scheduleControllers) {
                                    controller.dispose();
                                  }
                                  Navigator.of(dialogContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Profile updated successfully',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error updating profile: $e',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.save,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Save',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF1E201E),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFF1E201E),
            body: const Center(
              child: Text(
                'Unable to load profile',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final fullname = userData['fullname'] ?? 'Unknown';
        final email = userData['email'] ?? 'Unknown';
        final mobileNumber = userData['mobileNumber'] ?? 'Unknown';
        final address = userData['address'] ?? 'Unknown';
        final description = userData['description'] ?? 'Empty';
        final note = userData['note'] ?? 'Empty';
        final profileImageUrl = userData['profileImageUrl'] as String?;

        // Get schedules list
        List<Map<String, dynamic>> schedules = [];
        if (userData['schedules'] != null && userData['schedules'] is List) {
          schedules = List<Map<String, dynamic>>.from(userData['schedules']);
        } else if (userData['schedule'] != null &&
            userData['schedule'].toString().isNotEmpty &&
            userData['schedule'] != 'Empty') {
          // Migrate old single schedule to new format
          schedules = [
            {'name': 'Schedule 1', 'content': userData['schedule']},
          ];
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1E201E),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 800;
              final cardWidth = isLargeScreen
                  ? constraints.maxWidth * 0.6
                  : constraints.maxWidth * 0.95;

              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                  scrollbars: true,
                ),
                child: CustomScrollView(
                  slivers: [
                    // AppBar
                    SliverAppBar(
                      expandedHeight: 200,
                      floating: false,
                      pinned: true,
                      backgroundColor: const Color(0xFF2C2F2C),
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: _showEditDialog,
                        ),
                        const SizedBox(width: 8),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'Teacher Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        background: Container(
                          color: const Color(0xFF2C2F2C),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 60),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.blue,
                                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                                child: profileImageUrl == null || profileImageUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Content
                    SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          width: cardWidth,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),

                              // Basic Information Card
                              _buildSectionCard(
                                'Basic Information',
                                Icons.person,
                                Colors.blue,
                                [
                                  _buildInfoRow(
                                    'Full Name',
                                    fullname,
                                    Icons.person,
                                  ),
                                  _buildInfoRow('Email', email, Icons.email),
                                  _buildInfoRow(
                                    'Mobile Number',
                                    mobileNumber,
                                    Icons.phone,
                                  ),
                                  _buildInfoRow(
                                    'Address',
                                    address,
                                    Icons.location_on,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Professional Information Card
                              _buildSectionCard(
                                'Professional Information',
                                Icons.work,
                                Colors.purple,
                                [
                                  _buildInfoRow(
                                    'Description',
                                    description,
                                    Icons.description,
                                    isLarge: true,
                                  ),
                                  ...schedules.asMap().entries.map((entry) {
                                    return _buildInfoRow(
                                      entry.value['name'] ??
                                          'Schedule ${entry.key + 1}',
                                      entry.value['content']
                                                  ?.toString()
                                                  .isEmpty ??
                                              true
                                          ? 'Empty'
                                          : entry.value['content'].toString(),
                                      Icons.schedule,
                                      isLarge: true,
                                    );
                                  }).toList(),
                                  if (schedules.isEmpty)
                                    _buildInfoRow(
                                      'Schedule',
                                      'Empty',
                                      Icons.schedule,
                                      isLarge: true,
                                    ),
                                  _buildInfoRow(
                                    'Note',
                                    note,
                                    Icons.note,
                                    isLarge: true,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 40),

                              // Edit Button
                              Center(
                                child: AnimatedButton(
                                  width: isLargeScreen ? 300 : cardWidth * 0.8,
                                  height: 55,
                                  color: Colors.blue,
                                  shadowDegree: ShadowDegree.dark,
                                  onPressed: _showEditDialog,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Edit Profile',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isLarge = false,
  }) {
    final isEmpty = value == 'Unknown' || value == 'Empty';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty
              ? Colors.orange.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: isLarge
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEmpty
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isEmpty ? Colors.orange : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isEmpty ? Colors.orange : Colors.white,
                    fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w600,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: isLarge ? null : 1,
                  overflow: isLarge ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
