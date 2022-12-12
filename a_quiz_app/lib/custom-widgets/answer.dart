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
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.pink,
            ),
            child: Text('Retry! Elevated Button.'),
            onPressed: resetHandler,
          ),
          TextButton(
            child: Text('Retry! Text Button.'),
            onPressed: resetHandler,
          ),
          OutlinedButton(
            style:
                OutlinedButton.styleFrom(side: BorderSide(color: Colors.black)),
            child: Text('Retry! Outlined Button.'),
            onPressed: resetHandler,
          )
        ],
      ),
    );
  }
}
