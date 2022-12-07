import 'package:flutter/material.dart';

typedef StringCallback = void Function(String);

class QuestionChoice extends StatelessWidget {
  final String choice;

  // Passing callback functions arround
  // final Function selectHandler;
  // final VoidCallback selectHandler; // More specific void callback function than Function
  final StringCallback selectHandler;

  QuestionChoice(this.choice, this.selectHandler);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(5),
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.green),
        ),
        child: Text(choice),
        onPressed: () {
          selectHandler(choice);
        },
      ),
    );
  }
}
