import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final void Function(String) deleteCallback;

  TransactionItem({
    super.key,
    required this.transaction,
    required this.deleteCallback,
  });

  String get _amountText {
    return '\$ ${transaction.amount.toStringAsFixed(2)}';
  }

  String get _dateTimeText {
    return DateFormat.yMMMd().format(transaction.date);
    // return DateFormat('dd MMM yyyy HH:mm:ss').format(transaction.date);
  }

  void _deleteTransaction() {
    deleteCallback(transaction.id);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          child: Padding(
            padding: EdgeInsets.all(5),
            child: FittedBox(
              child: Text(
                _amountText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        title: Text(
          transaction.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          _dateTimeText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          color: Theme.of(context).errorColor,
          onPressed: _deleteTransaction,
        ),
      ),
    );
    /*
    Card(
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                _dateTimeText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
    */
  }
}
