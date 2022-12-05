import 'package:flutter/material.dart';
import 'example.dart';

void main() {
  runApp(AQuizApp());

  var o1 = Person(age: 40, name: "Tam");
  print(o1.name);
  var o2 = Pet();
  print(o2.name);
  var o3 = Shoe(brand: 'UA', size: 38);
  print(o3.brand);
}

class AQuizApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return AQuizAppState();
  }
}

class AQuizAppState extends State<AQuizApp> {
  var questionIndex = 0;

  var questions = [
    'Who is Harry Potter?',
    'What is his BFFs\'s name?',
  ];

  var choices = [
    ['A boy', 'A girl'],
    ['Dobby', 'Ron', 'Draco'],
  ];

  void answerQuestion() {
    setState(() {
      questionIndex++;
    });
    print(questionIndex);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> choiceButtons = [];
    for (var choice in choices[questionIndex]) {
      choiceButtons.add(ElevatedButton(
        child: Text(choice),
        onPressed: () {
          print(choice);
          setState(() {
            questionIndex++;
          });
        },
      ));
    }
    Widget questionTitle = Text(questions[questionIndex]);
    List<Widget> questionLayout = [questionTitle] + choiceButtons;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('A Quiz App')),
        body: Column(
          children: questionLayout,
          /*
          [
            Text(questions[questionIndex]),
            ElevatedButton(
              child: Text('Answer 1:'),
              onPressed: answerQuestion,
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
