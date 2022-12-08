import 'package:flutter/material.dart';

class Answer extends StatelessWidget {
  final int totalScore;
  final int totalQuestions;
  final VoidCallback resetHandler;

  Answer(this.totalScore, this.totalQuestions, this.resetHandler);

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
      child: Column(
        children: [
          Text(
            resultPhrase,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            child: Text(
              'Retry!',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
            onPressed: resetHandler,
          ),
        ],
      ),
    );
  }
}
