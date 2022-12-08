import 'package:flutter/material.dart';
import 'package:assignment_one/text-display.dart';
import 'package:assignment_one/text-control.dart';

class App extends StatefulWidget {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String _content = 'Hello World!';

  void _changeText() {
    setState(() {
      _content = 'Hi World!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Assignment One')),
        body: Column(children: [
          TextDisplay(_content),
          TextControl(_changeText),
        ]),
      ),
    );
  }
}
