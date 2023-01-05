import 'package:flutter/material.dart';
import '../custom-widgets/transaction-item.dart';
import '../models/transaction.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final void Function(String) deleteCallback;

  TransactionList({
    super.key,
    required this.transactions,
    required this.deleteCallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      child: ListView.builder(
        itemBuilder: (context, index) {
          return TransactionItem(
            transaction: transactions[index],
            deleteCallback: deleteCallback,
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
