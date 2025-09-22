import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorKeypad extends StatefulWidget {
  final String value;
  final ValueChanged<String> onValueChanged;
  final ThemeData? theme;

  const CalculatorKeypad({
    super.key,
    required this.value,
    required this.onValueChanged,
    this.theme,
  });

  @override
  State<CalculatorKeypad> createState() => _CalculatorKeypadState();
}

class _CalculatorKeypadState extends State<CalculatorKeypad> {
  String _expression = '';

  @override
  void initState() {
    super.initState();
    _expression = widget.value;
  }

  void _onTap(String input) {
    setState(() {
      if (input == 'C') {
        _expression = '';
      } else if (input == 'back') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (input == '=') {
        _evaluate();
        return;
      } else {
        _expression += input;
      }
      widget.onValueChanged(_expression);
    });
  }

  void _evaluate() {
    try {
      String sanitized = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      Parser parser = Parser();
      Expression exp = parser.parse(sanitized);
      double result = exp.evaluate(EvaluationType.REAL, ContextModel());
      _expression = result.toString();
      widget.onValueChanged(_expression);
    } catch (e) {
      // Optionally show error
      widget.onValueChanged('Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context);
    final buttons = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', 'back', '+'],
      ['C', '='],
    ];
    return Column(
      children: buttons.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((label) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: label.length == 1 ? 64 : 80,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: label == 'C'
                        ? Colors.red[100]
                        : label == '='
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primaryContainer,
                    foregroundColor: label == 'C'
                        ? Colors.red
                        : label == '='
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _onTap(label == 'back' ? 'back' : label),
                  child: label == 'back'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(label, style: const TextStyle(fontSize: 20)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
