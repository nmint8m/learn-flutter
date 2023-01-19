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
        const SizedBox(height: 10),
        SizedBox(
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
