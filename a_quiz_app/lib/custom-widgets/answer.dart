import 'package:flutter/material.dart';

class Answer extends StatelessWidget {
  final int totalScore;
  final int totalQuestions;

  Answer(this.totalScore, this.totalQuestions);

  String get resultPhrase {
    if (totalScore > 1) {
      return 'You did it! Your score: $totalScore/$totalQuestions.';
    } else {
      return 'You failed. Your score: $totalScore/$totalQuestions.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        resultPhrase,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
