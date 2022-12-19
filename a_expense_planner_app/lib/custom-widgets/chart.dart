import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class Chart extends StatelessWidget {
  final List<Transaction> recentTransactions;

  List<Map<String, Object>> get groupedTransactionValues {
    return List.generate(7, (index) {
      final weekday = DateTime.now().subtract(
        Duration(days: index),
      );

      double totalSum = 0.0;
      for (var index = 0; index < recentTransactions.length; index++) {
        if (recentTransactions[index].date.day == weekday.day &&
            recentTransactions[index].date.month == weekday.month &&
            recentTransactions[index].date.year == weekday.year) {
          totalSum += recentTransactions[index].amount;
        }
      }

      return {
        'day': DateFormat.E(weekday),
        'amount': totalSum,
      };
    });
  }

  const Chart({super.key, required this.recentTransactions});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.all(20),
      child: Row(
        children: <Widget>[],
      ),
    );
  }
}
