import 'package:flutter/material.dart';
import './custom-widgets/transaction-section.dart';

void main() {
  runApp(const MyApp());
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
          headline6: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange,
          ),
          subtitle1: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.orange,
          ),
          subtitle2: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.orange,
          ),
          bodyText1: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 13,
            color: Colors.black,
          ),
          bodyText2: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 12,
            color: Colors.black,
          ),
          caption: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 11,
            color: Colors.grey,
          ),
          button: const TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.normal,
            fontSize: 11,
            color: Colors.white,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Quicksand',
        appBarTheme: _creatAppBarTheme(),
        textTheme: _createTextTheme(),
        errorColor: Colors.red,
      ),
      home: const TransactionSection(),
    );
  }
}
