import 'package:flutter/material.dart';
import 'package:a_quiz_app/custom-widgets/question-title.dart';
import 'package:a_quiz_app/custom-widgets/question-choice.dart';

class Quiz extends StatelessWidget {
  final List<Map<String, Object>> questions;
  final int questionIndex;
  final StringCallback answerQuestion;

  Quiz({
    required this.questions,
    required this.questionIndex,
    required this.answerQuestion,
  });

  @override
  Widget build(BuildContext context) {
    // Build question title
    Widget questionTitle =
        QuestionTitle(questions[questionIndex]['question'] as String);

    // Build question choices
    List<String> choices = questions[questionIndex]['choices'] as List<String>;
    List<Widget> choiceButtons = choices.map((choice) {
      return QuestionChoice(choice, answerQuestion);
    }).toList();

    // Build question and choices layout
    List<Widget> questionLayout = [questionTitle, ...choiceButtons];

    return Container(
      width: double.infinity,
      child: Column(children: questionLayout),
    );
  }
}
