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

class AQuizApp extends StatelessWidget {
  var questions = [
    'Who is Harry Potter?',
    'What is his BFFs\'s name?',
  ];

  void answerQuestion() {
    print('Answer chosen.');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('A Quiz App')),
        body: Column(
          children: [
            Text('The questions:'),
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
        ),
      ),
    );
  }
}
