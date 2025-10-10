import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyImageMatch extends StatelessWidget {
  final List<Uint8List?> pickedImages;
  final int count; // number of image slots

  const MyImageMatch({
    super.key,
    required this.pickedImages,
    required this.count,
  });

  // 🔹 Helper to build each image box
  Widget _buildImageBox(Uint8List? img, int index) {
    return AnimatedButton(
      onPressed: () {},
      width: 100,
      height: 100,
      color: Colors.white,
      child: img != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                img,
                fit: BoxFit.contain,
              ),
            )
          : AnimatedButton(
              color: Colors.white,
              width: 100,
              height: 100,
              shadowDegree: ShadowDegree.light,
              onPressed: () {
                // Do nothing (or pass callback later)
              },
              child: Text(
                "Empty\n${index + 1}",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }

  // 🔹 Group list into rows of 2
  List<Widget> _buildRows(List<Widget> boxes) {
    final rows = <Widget>[];
    for (int i = 0; i < boxes.length; i += 2) {
      final rowChildren = <Widget>[];
      rowChildren.add(boxes[i]);
      if (i + 1 < boxes.length) {
        rowChildren.add(boxes[i + 1]);
      }
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rowChildren,
        ),
      );
    }

    return rows
        .expand((row) => [
              row,
              const SizedBox(height: 10),
            ])
        .toList()
      ..removeLast(); // remove trailing space
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Ensure correct number of slots
    final images = List<Uint8List?>.from(pickedImages);
    while (images.length < count) {
      images.add(null);
    }

    // 🔹 Split into odd (top) and even (bottom)
    final oddBoxes = <Widget>[];
    final evenBoxes = <Widget>[];

    for (int i = 0; i < count; i++) {
      if ((i + 1) % 2 == 1) {
        oddBoxes.add(_buildImageBox(images[i], i));
      } else {
        evenBoxes.add(_buildImageBox(images[i], i));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Image Match:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          "Match the correct image.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),

        if (oddBoxes.isNotEmpty) Column(children: _buildRows(oddBoxes)),

        if (oddBoxes.isNotEmpty && evenBoxes.isNotEmpty)
          const Divider(color: Colors.black26, thickness: 1, height: 30),

        if (evenBoxes.isNotEmpty) Column(children: _buildRows(evenBoxes)),
      ],
    );
  }
}

// ================================
// Column 3 - Settings Widget
// ================================
class MyImageMatchSettings extends StatefulWidget {
  final Function(int, Uint8List) onImagePicked;
  final Function(int) onCountChanged;
  final List<Uint8List?>? initialImages;
  final int? initialCount;

  const MyImageMatchSettings({
    super.key,
    required this.onImagePicked,
    required this.onCountChanged,
    this.initialImages,
    this.initialCount,
  });

  @override
  State<MyImageMatchSettings> createState() => _MyImageMatchSettingsState();
}

class _MyImageMatchSettingsState extends State<MyImageMatchSettings> {
  int _count = 2;
  List<Uint8List?> _localImages = List.filled(8, null);

  final Map<int, int?> _matches = {};
  
  @override
  void initState() {
    super.initState();

    // Initialize with provided data if available
    if (widget.initialCount != null) {
      _count = widget.initialCount!;
    }

    if (widget.initialImages != null) {
      _localImages = List.from(widget.initialImages!);
      // Ensure the list has exactly 8 elements
      while (_localImages.length < 8) {
        _localImages.add(null);
      }
    }
  }

  @override
  void didUpdateWidget(MyImageMatchSettings oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update state when widget properties change (e.g., when switching pages)
    if (widget.initialCount != null && widget.initialCount != _count) {
      setState(() {
        _count = widget.initialCount!;
      });
    }

    if (widget.initialImages != null) {
      setState(() {
        _localImages = List.from(widget.initialImages!);
        // Ensure the list has exactly 8 elements
        while (_localImages.length < 8) {
          _localImages.add(null);
        }
      });
    }
  }

  Future<void> _pickImage(int index) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        setState(() {
          _localImages[index] = fileBytes;
        });
        widget.onImagePicked(index, fileBytes);
      }
    }
  }

  void _increaseCount() {
    if (_count < 8) {
      setState(() {
        _count = (_count + 2 <= 8) ? _count + 2 : 8;
      });
      widget.onCountChanged(_count);
    }
  }

  void _decreaseCount() {
    if (_count > 2) {
      setState(() {
        _count = (_count - 2 >= 2) ? _count - 2 : 2;
      });
      widget.onCountChanged(_count);
    }
  }

  Widget _buildBox(int index) {
    final isOdd = (index + 1) % 2 == 1;

    return Column(
      children: [
        AnimatedButton(
          width: 100,
          height: 100,
          color: Colors.white,
          shadowDegree: ShadowDegree.light,
          onPressed: () => _pickImage(index),
          child: _localImages[index] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _localImages[index]!,
                    fit: BoxFit.contain,
                  ),
                )
              : Text(
                  "Upload\n${index + 1}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
        ),

        if (isOdd)
          Container(
            width: 100,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black26),
            ),
            child: DropdownButton<int>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _matches[index],
              hint: Text(
                "Select match",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
              items: List.generate(_count, (i) => i)
                  .where((i) => (i + 1) % 2 == 0)
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        "Image ${i + 1}",
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  if (val != null) {
                    final alreadyUsedBy = _matches.entries.firstWhere(
                      (entry) => entry.key != index && entry.value == val,
                      orElse: () => const MapEntry(-1, null),
                    );

                    if (alreadyUsedBy.key != -1) {
                      _matches[alreadyUsedBy.key] = null;
                    }

                    _matches[index] = val;
                  } else {
                    _matches[index] = null;
                  }
                });
              },
            ),
          ),

        if (!isOdd)
          Container(
            width: 100,
            margin: const EdgeInsets.only(top: 6),
            child: Text(
              "${index + 1}",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topRow = <Widget>[];
    final bottomRow = <Widget>[];

    for (int i = 0; i < _count; i++) {
      if ((i + 1) % 2 == 1) {
        topRow.add(_buildBox(i));
      } else {
        bottomRow.add(_buildBox(i));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Image Configuration:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AnimatedButton(
              width: 50,
              height: 50,
              color: Colors.white,
              onPressed: _increaseCount,
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.black),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              height: 50,
              child: TextField(
                readOnly: true,
                textAlign: TextAlign.center,
                controller: TextEditingController(text: _count.toString()),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedButton(
              width: 50,
              height: 50,
              color: Colors.white,
              onPressed: _decreaseCount,
              child: const Icon(Icons.remove_circle_outline_sharp,
                  color: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 20,
          children: topRow,
        ),
        const Divider(color: Colors.white, thickness: 1, height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 20,
          children: bottomRow,
        ),
      ],
    );
  }
}
