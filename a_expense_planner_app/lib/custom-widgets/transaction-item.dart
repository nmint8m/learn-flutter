import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;

  TransactionItem({
    super.key,
    required this.transaction,
  });

  String get _amountText {
    return '\$ ${transaction.amount.toStringAsFixed(2)}';
  }

  String get _dateTimeText {
    return DateFormat('dd MMM yyyy HH:mm:ss').format(transaction.date);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 30.0,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2.0,
              ),
            ),
            child: Text(
              _amountText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Text(
                _dateTimeText,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
