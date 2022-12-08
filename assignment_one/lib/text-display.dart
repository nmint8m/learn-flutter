import 'package:flutter/material.dart';

class TextDisplay extends StatelessWidget {
  final String content;

  TextDisplay(this.content);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        content,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
