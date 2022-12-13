import 'package:flutter/material.dart';
import '/custom-widgets/transaction-item.dart';
import '/models/transaction.dart';

class TransactionSection extends StatelessWidget {
  final List<Transaction> transactions;

  TransactionSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    List<Widget> cards = transactions.map((transaction) {
      return TransactionItem(transaction: transaction);
    }).toList();

    return Container(
      width: double.infinity,
      child: Column(
        children: cards,
      ),
    );
  }
}
