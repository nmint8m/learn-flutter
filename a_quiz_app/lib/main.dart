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

  final _questions = const [
    {
      'question': 'Who is Harry Potter?',
      'choices': ['A boy', 'A girl'],
    },
    {
      'question': 'What is his BFFs\'s name?',
      'choices': ['Dobby', 'Ron', 'Draco'],
    },
    {
      'question': 'What is Voldermort\'s real name?',
      'choices': ['Hermione Granger', 'Lucius Malfoy', 'Tom Riddle'],
    },
  ];

  void _answerQuestion(String answer) {
    if (_questionIndex < _questions.length) {
      setState(() {
        _questionIndex++;
      });
    }
    print('Selected answer: $answer');
    print('Next question: $_questionIndex');
  }

  @override
  Widget build(BuildContext context) {
    Widget childrenLayout = _questionIndex < _questions.length
        ? Quiz(
            questions: _questions,
            questionIndex: _questionIndex,
            answerQuestion: _answerQuestion)
        : Answer();
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
