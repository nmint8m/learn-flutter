import 'package:flutter/material.dart';
import '/models/transaction.dart';
import '/custom-widgets/transaction-section.dart';
import '/custom-widgets/transaction-input.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
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

  void _handle(Transaction transaction) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('An expense planner app'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            elevation: 5,
            child: Container(
              width: double.infinity,
              child: Text('Chart'),
            ),
          ),
          TransactionInput(inputHandler: _handle),
          TransactionSection(transactions: transactions),
        ],
      ),
    );
  }
}
