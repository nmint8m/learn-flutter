import 'package:flutter/material.dart';

class TransactionEmptyList extends StatelessWidget {
  const TransactionEmptyList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Empty list',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(
          height: 10,
        ),
        Container(
          height: 200,
          child: Image.asset(
            'assets/images/waiting.png',
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}
