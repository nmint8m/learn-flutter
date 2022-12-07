import 'package:flutter/material.dart';

class Answer extends StatelessWidget {
  final int totalScore;
  final int totalQuestions;

  Answer(this.totalScore, this.totalQuestions);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Answers submitted!. Your score: $totalScore/$totalQuestions.',
        style: TextStyle(fontSize: 28),
        textAlign: TextAlign.center,
      ),
    );
  }
}
