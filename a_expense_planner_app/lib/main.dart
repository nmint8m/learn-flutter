import 'package:flutter/material.dart';
import './models/transaction-input-data.dart';
import './custom-widgets/transaction-section.dart';
import './custom-widgets/transaction-input.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  AppBarTheme _creatAppBarTheme() {
    return AppBarTheme(
      toolbarTextStyle: ThemeData.light()
          .textTheme
          .copyWith(
            titleLarge: const TextStyle(
              fontFamily: 'OpenSands',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
          .bodyText2,
      titleTextStyle: ThemeData.light()
          .textTheme
          .copyWith(
            titleLarge: const TextStyle(
              fontFamily: 'OpenSands',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
          .headline6,
    );
  }

  TextTheme _createTextTheme() {
    return ThemeData.light().textTheme.copyWith(
          titleLarge: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.orange,
          ),
          titleSmall: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.orange,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 13,
            color: Colors.black,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 12,
            color: Colors.black,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 11,
            color: Colors.grey,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        accentColor: Colors.amber,
        fontFamily: 'Quicksand',
        appBarTheme: _creatAppBarTheme(),
        textTheme: _createTextTheme(),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final _transactionSection = TransactionSection();

  MyHomePage({super.key});

  void _startAddNewTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return GestureDetector(
          child: TransactionInput(inputHandler: _addNewTransaction),
          onTap: () {},
          behavior: HitTestBehavior.opaque,
        );
      },
    );
  }

  void _addNewTransaction(TransactionInputData data) {
    print(data.title);
    print(data.amount);
    _transactionSection.controller.addNewTransactionHandler(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('An expense planner app'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _startAddNewTransaction(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 5,
              child: Container(
                color: Theme.of(context).accentColor,
                width: double.infinity,
                child: Text('Chart'),
              ),
            ),
            _transactionSection,
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _startAddNewTransaction(context),
      ),
    );
  }
}
