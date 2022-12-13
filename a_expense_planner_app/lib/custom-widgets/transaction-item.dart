import 'package:flutter/material.dart';
import '/models/transaction.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;

  TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          Container(
            child: Text(transaction.amount.toString()),
          ),
          Column(
            children: [
              Text(transaction.title),
              Text(transaction.date.toString()),
            ],
          ),
        ],
      ),
    );
  }
}
