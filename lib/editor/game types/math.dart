import 'package:animated_button/animated_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

// Shared state management class
class MathState extends ChangeNotifier {
  int _totalBoxes = 1;
  final List<TextEditingController> _boxControllers = [];
  final List<String> _operators = [];
  final TextEditingController _resultController = TextEditingController();
  final TextEditingController _counterController = TextEditingController(
    text: "1",
  );
  
  // Separate result controller for MyMath preview (read-only display)
  final TextEditingController _previewResultController =
      TextEditingController();

  int get totalBoxes => _totalBoxes;
  List<TextEditingController> get boxControllers => _boxControllers;
  List<String> get operators => _operators;
  TextEditingController get resultController => _resultController;
  TextEditingController get counterController => _counterController;
  TextEditingController get previewResultController => _previewResultController;

  MathState() {
    _initControllers();
    _calculateResult();
  }

  void _initControllers() {
    _boxControllers.clear();
    _operators.clear();
    for (int i = 0; i < _totalBoxes; i++) {
      final controller = TextEditingController();
      controller.addListener(_calculateResult);
      _boxControllers.add(controller);
      if (i < _totalBoxes - 1) {
        _operators.add("+");
      }
    }
  }

  void increment() {
    if (_totalBoxes < 10) {
      _totalBoxes++;
      _counterController.text = _totalBoxes.toString();
      final controller = TextEditingController();
      controller.addListener(_calculateResult);
      _boxControllers.add(controller);
      if (_totalBoxes > 1) {
        _operators.add("+");
      }
      _calculateResult();
      notifyListeners();
    }
  }

  void decrement() {
    if (_totalBoxes > 1) {
      _totalBoxes--;
      _counterController.text = _totalBoxes.toString();
      _boxControllers.removeLast().dispose();
      if (_operators.isNotEmpty) {
        _operators.removeLast();
      }
      _calculateResult();
      notifyListeners();
    }
  }

  void cycleOperator(int index) {
    switch (_operators[index]) {
      case "+":
        _operators[index] = "-";
        break;
      case "-":
        _operators[index] = "×";
        break;
      case "×":
        _operators[index] = "÷";
        break;
      case "÷":
        _operators[index] = "+";
        break;
    }
    _calculateResult();
    notifyListeners();
  }

  void _calculateResult() {
    double result = 0;
    if (_boxControllers.isNotEmpty) {
      result = double.tryParse(_boxControllers[0].text) ?? 0;
      for (int i = 0; i < _operators.length; i++) {
        double next = double.tryParse(_boxControllers[i + 1].text) ?? 0;
        switch (_operators[i]) {
          case "+":
            result += next;
            break;
          case "-":
            result -= next;
            break;
          case "×":
            result *= next;
            break;
          case "÷":
            if (next != 0) result /= next;
            break;
        }
      }
    }
    _resultController.text = result.toStringAsFixed(0);
    // Don't update previewResultController - it's independent
    notifyListeners();
  }

  // Dynamic height based on totalBoxes
  double getContainerHeight() {
    if (_totalBoxes >= 9) return 400;
    if (_totalBoxes >= 6) return 250;
    if (_totalBoxes >= 3) return 150;
    return 100;
  }

  double getBoxWidth(String text) {
    int len = text.length;
    if (len <= 3) return 50;
    if (len == 4) return 60;
    if (len == 5) return 70;
    if (len == 6) return 80;
    if (len >= 7) return 90;
    return 50;
  }

  double getBoxWidth2(String text) {
    int len = text.length;
    if (len <= 3) return 50;
    if (len <= 6) return 80;
    if (len <= 10) return 120;
    if (len <= 15) return 160;
    if (len <= 20) return 200;
    return 250;
  }

  // Special width calculation for preview result (can go up to 400)
  double getPreviewResultWidth(String text) {
    int len = text.length;
    if (len <= 1) return 50;
    if (len <= 3) return 80;
    if (len <= 5) return 120;
    if (len <= 7) return 160;
    if (len <= 9) return 200;
    if (len <= 11) return 250;
    if (len <= 13) return 300;
    if (len <= 15) return 350;
    return 400; // max width for 16 digits
  }

  IconData getOperatorIcon(String op) {
    switch (op) {
      case "+":
        return Icons.add;
      case "-":
        return Icons.remove;
      case "×":
        return Icons.close;
      case "÷":
        return CupertinoIcons.divide;
      default:
        return Icons.add;
    }
  }

  @override
  void dispose() {
    _counterController.dispose();
    for (var controller in _boxControllers) {
      controller.dispose();
    }
    _resultController.dispose();
    _previewResultController.dispose();
    super.dispose();
  }
}

// ----------- Preview Widget (for Column 2) -----------
class MyMath extends StatelessWidget {
  final MathState mathState;

  const MyMath({super.key, required this.mathState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mathState,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Math:",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Solve the math problem.",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Dynamic height container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 400,
              height: mathState.getContainerHeight(),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < mathState.totalBoxes; i++) ...[
                        // Number box (read-only)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: mathState.getBoxWidth(
                            mathState.boxControllers[i].text,
                          ),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: mathState.boxControllers[i],
                            readOnly: true,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            decoration: const InputDecoration(
                              hintText: "0",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),

                        // Operator button (read-only display)
                        if (i < mathState.totalBoxes - 1)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2F2C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              mathState.getOperatorIcon(mathState.operators[i]),
                              color: Colors.white,
                            ),
                          ),
                      ],

                      // Equal box
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2F2C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.equal,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  "Your Answer:",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // Result textfield below container (centered, dark background, white text, editable)
            Center(
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: mathState.getPreviewResultWidth(
                      mathState.previewResultController.text,
                    ),
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2F2C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: mathState.previewResultController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      onChanged: (value) {
                        setInnerState(() {});
                      },
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  );
                },
              ),
            ),

            const Spacer(),
          ],
        );
      },
    );
  }
}

// ----------- Settings Widget (for Column 3) -----------
class MyMathSettings extends StatelessWidget {
  final MathState mathState;

  const MyMathSettings({super.key, required this.mathState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mathState,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Boxes:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            // Counter Row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: AnimatedButton(
                    width: 50,
                    height: 50,
                    color: Colors.white,
                    onPressed: mathState.increment,
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Counter display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: mathState.counterController,
                      readOnly: true,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // Remove button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: AnimatedButton(
                    width: 50,
                    height: 50,
                    color: Colors.white,
                    onPressed: mathState.decrement,
                    child: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Dynamic math row
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (int i = 0; i < mathState.totalBoxes; i++) ...[
                  // Number box
                  StatefulBuilder(
                    builder: (context, setInnerState) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: mathState.getBoxWidth(
                          mathState.boxControllers[i].text,
                        ),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: mathState.boxControllers[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          onChanged: (value) {
                            setInnerState(() {});
                          },
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            hintText: "0",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    },
                  ),

                  // Operator button (only between textfields)
                  if (i < mathState.totalBoxes - 1)
                    AnimatedButton(
                      width: 50,
                      height: 50,
                      color: Colors.white,
                      onPressed: () => mathState.cycleOperator(i),
                      child: Icon(
                        mathState.getOperatorIcon(mathState.operators[i]),
                        color: Colors.black,
                      ),
                    ),
                ],

                // Equal box after the last textfield
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.equal, color: Colors.black),
                ),

                // Result textfield (read-only)
                StatefulBuilder(
                  builder: (context, setInnerState) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: mathState.getBoxWidth2(
                        mathState.resultController.text,
                      ),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: mathState.resultController,
                        readOnly: true,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// Usage example:
// Create one MathState instance and pass it to both widgets:
// final mathState = MathState();
// MyMath(mathState: mathState)
// MyMathSettings(mathState: mathState)