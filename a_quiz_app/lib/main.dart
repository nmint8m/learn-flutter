import 'package:flutter/material.dart';
import 'example.dart';
import 'custom-widgets/question-title.dart';
import 'custom-widgets/question-choice.dart';

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

  var _questions = [
    'Who is Harry Potter?',
    'What is his BFFs\'s name?',
  ];

  var _choices = [
    ['A boy', 'A girl'],
    ['Dobby', 'Ron', 'Draco'],
  ];

  void _answerQuestion() {
    setState(() {
      _questionIndex++;
    });
    print(_questionIndex);
  }

  @override
  Widget build(BuildContext context) {
    Widget questionTitle = QuestionTitle(_questions[_questionIndex]);

    List<Widget> choiceButtons = [];
    for (var choice in _choices[_questionIndex]) {
      choiceButtons.add(QuestionChoice(choice, _answerQuestion));
      /*
      choiceButtons.add(ElevatedButton(
        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.green),),
        child: Text(choice),
        onPressed: () {
          print(choice);
          _answerQuestion();
        },
      ));
      */
    }

    List<Widget> questionLayout = [questionTitle] + choiceButtons;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('A Quiz App')),
        body: Column(
          children: questionLayout,
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
      ),
    );
  }
}
