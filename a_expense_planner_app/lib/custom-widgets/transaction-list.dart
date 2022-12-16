import 'package:flutter/material.dart';
import '../custom-widgets/transaction-item.dart';
import '../models/transaction.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  TransactionList({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 550,
      child: ListView.builder(
        itemBuilder: (context, index) {
          return TransactionItem(
            transaction: transactions[index],
          );
        },
        itemCount: transactions.length,
      ),
    );
    /*
    List<Widget> cards = transactions.map((transaction) {
      return TransactionItem(transaction: transaction);
    }).toList();
    return Container(
      height: 250,
      child: SingleChildScrollView(
        child: Column(
          children: cards,
        ),
      ),
    );
    */
  }
}
