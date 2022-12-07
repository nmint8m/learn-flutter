import 'package:flutter/material.dart';

typedef ChoiceCallback = void Function(String, int);

class QuestionChoice extends StatelessWidget {
  final Map<String, Object> choice;

  // Passing callback functions arround
  // final Function selectHandler;
  // final VoidCallback selectHandler; // More specific void callback function than Function
  final ChoiceCallback selectHandler;

  QuestionChoice(this.choice, this.selectHandler);

  @override
  Widget build(BuildContext context) {
    String text = choice['text'] as String;
    int score = choice['score'] as int;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(5),
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.green),
        ),
        child: Text(text),
        onPressed: () {
          selectHandler(text, score);
        },
      ),
    );
  }
}
