import 'package:flutter/material.dart';
import '../custom-widgets/transaction-list.dart';
import '../custom-widgets/transaction-empty-list.dart';
import '../custom-widgets/chart.dart';
import '../models/transaction.dart';
import '../models/transaction-input-data.dart';

class TransactionSection extends StatefulWidget {
  TransactionSection({super.key});

  Function(TransactionInputData)? addNewTransactionHandler;

  @override
  State<TransactionSection> createState() => _TransactionSectionState();
}

class _TransactionSectionState extends State<TransactionSection> {
  List<Transaction> transactions = [];
  /*
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
  */

  List<Transaction> get _recentTransaction {
    return transactions.where((transaction) {
      return transaction.date
          .isAfter(DateTime.now().subtract(Duration(days: 7)));
    }).toList();
  }

  void addNewTransaction(TransactionInputData transactionInputData) {
    Transaction newTransaction = Transaction(
      id: DateTime.now().toString(),
      title: transactionInputData.title,
      amount: transactionInputData.amount,
      date: transactionInputData.date,
    );
    setState(() {
      transactions.add(newTransaction);
    });
  }

  void deleteTransaction(String id) {
    setState(() {
      transactions.removeWhere((transaction) {
        return transaction.id == id;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.addNewTransactionHandler = addNewTransaction;
    Widget transactionList = transactions.isEmpty
        ? TransactionEmptyList()
        : TransactionList(
            transactions: transactions, deleteCallback: deleteTransaction);
    return Container(
      width: double.infinity,
      height: 500,
      child: Column(
        children: [
          Chart(recentTransactions: _recentTransaction),
          transactionList,
        ],
      ),
    );
  }
}
