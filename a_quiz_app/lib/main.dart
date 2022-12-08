import 'package:flutter/material.dart';
import 'package:a_quiz_app/example.dart';
import 'package:a_quiz_app/custom-widgets/quiz.dart';
import 'package:a_quiz_app/custom-widgets/answer.dart';

void main() {
  runApp(AQuizApp());
  printSomeInfo();
}

void printSomeInfo() {
  var o1 = Person(age: 40, name: "Tam");
  print(o1.name);
  var o2 = Pet();
  print(o2.name);
  var o3 = Shoe(brand: 'UA', size: 38);
  print(o3.brand);
  var o3l = Shoe.large('Nike');
  print(o3l.brand);
  print(o3l.size);
}

class AQuizApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AQuizAppState();
  }
}

class _AQuizAppState extends State<AQuizApp> {
  var _questionIndex = 0;
  var _totalScore = 0;

  final _questions = const [
    {
      'question': 'Who is Harry Potter?',
      'choices': [
        {'text': 'A boy', 'score': 1},
        {'text': 'A girl', 'score': 0},
      ]
    },
    {
      'question': 'What is his BFFs\'s name?',
      'choices': [
        {'text': 'Dobby', 'score': 0},
        {'text': 'Ron', 'score': 1},
        {'text': 'Draco', 'score': 0},
      ],
    },
    {
      'question': 'What is Voldermort\'s real name?',
      'choices': [
        {'text': 'Hermione Granger', 'score': 0},
        {'text': 'Lucius Malfoy', 'score': 0},
        {'text': 'Tom Riddle', 'score': 1},
      ],
    },
  ];

  void _answerQuestion(String answer, int score) {
    _totalScore += score;
    if (_questionIndex < _questions.length) {
      setState(() {
        _questionIndex++;
      });
    }
    print('Selected answer: $answer');
    print('Selected answer\'s score: $score');
    print('Next question: $_questionIndex');
    print('Total score: $_totalScore');
  }

  void _resetQuiz() {
    setState(() {
      _questionIndex = 0;
      _totalScore = 0;
    });
    print('Next question: $_questionIndex');
    print('Total score: $_totalScore');
  }

  @override
  Widget build(BuildContext context) {
    Widget childrenLayout = _questionIndex < _questions.length
        ? Quiz(
            questions: _questions,
            questionIndex: _questionIndex,
            answerQuestion: _answerQuestion)
        : Answer(_totalScore, _questions.length, _resetQuiz);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('A Quiz App')),
        body: childrenLayout,
        /* // Named functions and Anonymous functions
          [
            Text(_questions[_questionIndex]),
            ElevatedButton(
              child: Text('Answer 1:'),
              onPressed: _answerQuestion,
            ),
            ElevatedButton(
              child: Text('Answer 2:'),
              onPressed: () => print('Answer 2 chosen!'),
            ),
            ElevatedButton(
              child: Text('Answer 3:'),
              onPressed: () {
                print('Answer 3 chosen!');
              },
            ),
          ],
          */
      ),
    );
  }
}
