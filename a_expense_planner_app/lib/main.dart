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
          .bodyMedium,
      titleTextStyle: ThemeData.light()
          .textTheme
          .copyWith(
            titleLarge: const TextStyle(
              fontFamily: 'OpenSands',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
          .titleLarge,
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
          labelLarge: const TextStyle(
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
        fontFamily: 'Quicksand',
        appBarTheme: _creatAppBarTheme(),
        textTheme: _createTextTheme(), colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange).copyWith(error: Colors.red),
      ),
      home: const TransactionSection(),
    );
  }
}
