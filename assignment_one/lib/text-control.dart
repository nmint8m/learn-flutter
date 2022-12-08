import 'package:flutter/material.dart';

class TextControl extends StatelessWidget {
  final VoidCallback handler;

  TextControl(this.handler);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: Text('Change text'),
        onPressed: handler,
      ),
    );
  }
}
