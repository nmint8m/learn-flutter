import 'package:flutter/material.dart';
import '../custom-widgets/transaction-input.dart';
import '../custom-widgets/transaction-list.dart';
import '../custom-widgets/transaction-empty-list.dart';
import '../custom-widgets/chart.dart';
import '../models/transaction.dart';
import '../models/transaction-input-data.dart';

class TransactionSection extends StatefulWidget {
  const TransactionSection({super.key});

  @override
  State<TransactionSection> createState() => _TransactionSectionState();
}

class _TransactionSectionState extends State<TransactionSection> {
  List<Transaction> transactions = [];
  /*
      [
    Transaction(
      id: '1',
      title: 'New a',
      amount: 200.1,
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Transaction(
      id: '2',
      title: 'New b',
      amount: 500.5,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Transaction(
      id: '3',
      title: 'New c',
      amount: 500.5,
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Transaction(
      id: '4',
      title: 'New d',
      amount: 200.1,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Transaction(
      id: '5',
      title: 'New e',
      amount: 500.5,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Transaction(
      id: '6',
      title: 'New f',
      amount: 500.5,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: '7',
      title: 'New g',
      amount: 500.5,
      date: DateTime.now(),
    ),
  ];
  // */

  List<Transaction> get _recentTransaction {
    return transactions.where((transaction) {
      return transaction.date
          .isAfter(DateTime.now().subtract(const Duration(days: 7)));
    }).toList();
  }

  void _startAddNewTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: TransactionInput(inputHandler: _addNewTransaction),
        );
      },
    );
  }

  void _addNewTransaction(TransactionInputData transactionInputData) {
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
      transactions.removeWhere((transaction) => transaction.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('An expense planner app'),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _startAddNewTransaction(context),
        )
      ],
    );

    final height = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        appBar.preferredSize.height;

    Widget recentTransaction = Container(
        height: height * 0.3,
        child: Chart(
          recentTransactions: _recentTransaction,
        ));

    Widget transactionList = Container(
      height: height * 0.7,
      child: transactions.isEmpty
          ? const TransactionEmptyList()
          : TransactionList(
              transactions: transactions,
              deleteCallback: deleteTransaction,
            ),
    );

    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: double.infinity,
              child: Column(
                children: [
                  recentTransaction,
                  transactionList,
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _startAddNewTransaction(context),
      ),
    );
  }
}
