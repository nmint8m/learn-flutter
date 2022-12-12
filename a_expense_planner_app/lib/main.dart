import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('An expense planner app'),
      ),
      body: Column(children: <Widget>[
        Card(
          child: Container(
            width: double.infinity,
            child: Text('Chart'),
          ),
          elevation: 5,
        ),
        Container(
          width: double.infinity,
          child: Card(
            child: Text('List of text'),
            elevation: 5,
          ),
        ),
      ]),
    );
  }
}
