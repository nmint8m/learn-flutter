import 'package:flutter/material.dart';
import '../custom-widgets/transaction-input.dart';
import '../custom-widgets/transaction-list.dart';
import '../models/transaction.dart';
import '../models/transaction-input-data.dart';

class TransactionSection extends StatefulWidget {
  @override
  State<TransactionSection> createState() => _TransactionSectionState();
}

class _TransactionSectionState extends State<TransactionSection> {
  final List<Transaction> transactions = [
    Transaction(
      id: '1',
      title: 'New car',
      amount: 1000.1,
      date: DateTime.now(),
    ),
    Transaction(
      id: '2',
      title: 'New house',
      amount: 5000.5,
      date: DateTime.now(),
    ),
    Transaction(
      id: '3',
      title: 'Food',
      amount: 500.5,
      date: DateTime.now(),
    ),
  ];

  void addNewTransaction(TransactionInputData transactionInputData) {
    int id = transactions.length + 1;
    Transaction newTransaction = Transaction(
      id: id.toString(),
      title: transactionInputData.title,
      amount: transactionInputData.amount,
      date: DateTime.now(),
    );
    setState(() {
      transactions.add(newTransaction);
    });
    print(newTransaction);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          TransactionInput(inputHandler: addNewTransaction),
          TransactionList(transactions: transactions)
        ],
      ),
    );
  }
}
