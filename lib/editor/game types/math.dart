import 'package:animated_button/animated_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

// ----------- Preview Widget (for Column 2) -----------
class MyMath extends StatelessWidget {
  const MyMath({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const Spacer(),
      ],
    );
  }
}

// ----------- Settings Widget (for Column 3) -----------
class MyMathSettings extends StatefulWidget {
  const MyMathSettings({super.key});

  @override
  State<MyMathSettings> createState() => _MyMathSettingsState();
}

class _MyMathSettingsState extends State<MyMathSettings> {
  int _totalBoxes = 1; // start at 1
  final TextEditingController _counterController =
      TextEditingController(text: "1");

  // controllers for the dynamic small textfields
  final List<TextEditingController> _boxControllers = [];
  // store operator states between boxes
  final List<String> _operators = [];

  // result controller
  final TextEditingController _resultController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
        _operators.add("+"); // default operator
      }
    }
  }

  void _increment() {
    if (_totalBoxes < 10) {
      setState(() {
        _totalBoxes++;
        _counterController.text = _totalBoxes.toString();
        final controller = TextEditingController();
        controller.addListener(_calculateResult);
        _boxControllers.add(controller);
        if (_totalBoxes > 1) {
          _operators.add("+");
        }
        _calculateResult();
      });
    }
  }

  void _decrement() {
    if (_totalBoxes > 1) {
      setState(() {
        _totalBoxes--;
        _counterController.text = _totalBoxes.toString();
        _boxControllers.removeLast();
        if (_operators.isNotEmpty) {
          _operators.removeLast();
        }
        _calculateResult();
      });
    }
  }

  // Dynamic width for input boxes
  double _getBoxWidth(String text) {
    int len = text.length;
    if (len <= 3) return 50; // default
    if (len == 4) return 60;
    if (len == 5) return 70;
    if (len == 6) return 80;
    if (len >= 7) return 90;
    return 50;
  }

  // More flexible width for the RESULT box (no strict limit)
  double _getBoxWidth2(String text) {
    int len = text.length;
    if (len <= 3) return 50;
    if (len <= 6) return 80;
    if (len <= 10) return 120;
    if (len <= 15) return 160;
    if (len <= 20) return 200;
    return 250; // cap at large size
  }

  IconData _getOperatorIcon(String op) {
    switch (op) {
      case "+":
        return Icons.add;
      case "-":
        return Icons.remove;
      case "×":
        return Icons.close; // multiplication
      case "÷":
        return CupertinoIcons.divide; // division
      default:
        return Icons.add;
    }
  }

  void _cycleOperator(int index) {
    setState(() {
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
    });
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _increment,
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
                  controller: _counterController,
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
                onPressed: _decrement,
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
            for (int i = 0; i < _totalBoxes; i++) ...[
              // Number box
              StatefulBuilder(
                builder: (context, setInnerState) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _getBoxWidth(_boxControllers[i].text),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _boxControllers[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      onChanged: (value) {
                        setInnerState(() {});
                        _calculateResult();
                      },
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0", // ✅ Added hint
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  );
                },
              ),

              // Operator button (only between textfields)
              if (i < _totalBoxes - 1)
                AnimatedButton(
                  width: 50,
                  height: 50,
                  color: Colors.white,
                  onPressed: () => _cycleOperator(i),
                  child: Icon(
                    _getOperatorIcon(_operators[i]),
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
                CupertinoIcons.equal, // equal icon
                color: Colors.black,
              ),
            ),

            // Result textfield (read-only)
            StatefulBuilder(
              builder: (context, setInnerState) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _getBoxWidth2(_resultController.text), // ✅ use _getBoxWidth2
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _resultController,
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
  }
}