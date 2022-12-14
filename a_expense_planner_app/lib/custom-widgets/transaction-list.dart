import 'package:flutter/material.dart';
import '../custom-widgets/transaction-item.dart';
import '../models/transaction.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    List<Widget> cards = transactions.map((transaction) {
      return TransactionItem(transaction: transaction);
    }).toList();
    return Column(
      children: cards,
    );
  }
}
