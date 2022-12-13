import 'package:flutter/material.dart';
import '/models/transaction.dart';

class TransactionSection extends StatelessWidget {
  final List<Transaction> transactions;

  TransactionSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    List<Widget> cards = transactions.map((transaction) {
      return Card(
          child: Text(
        transaction.title,
        style: TextStyle(color: Colors.green),
      ));
    }).toList();

    return Container(
      width: double.infinity,
      child: Column(
        children: cards,
      ),
    );
  }
}
