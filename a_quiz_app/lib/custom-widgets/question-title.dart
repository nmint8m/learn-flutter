import 'package:flutter/material.dart';

class QuestionTitle extends StatelessWidget {
  final String questionString;

  QuestionTitle(this.questionString);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(5),
      child: Text(
        questionString,
        style: TextStyle(fontSize: 32),
        textAlign: TextAlign.center,
      ),
    );
  }
}
