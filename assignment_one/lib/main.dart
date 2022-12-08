// 1) Create a new Flutter App (in this project) and output an AppBar and some text
// below it
// 2) Add a button which changes the text (to any other text of your choice)
// 3) Split the app into three widgets: App, TextControl & Text

import 'package:flutter/material.dart';
import 'package:assignment_one/app.dart';

void main() {
  runApp(AssigmentOne());
}

class AssigmentOne extends StatefulWidget {
  @override
  State<AssigmentOne> createState() => _AssigmentOneState();
}

class _AssigmentOneState extends State<AssigmentOne> {
  @override
  Widget build(BuildContext context) {
    return App();
  }
}
