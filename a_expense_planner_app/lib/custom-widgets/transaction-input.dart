import 'package:flutter/material.dart';
import '/models/transaction.dart';

typedef TransactionInputCallback = void Function(Transaction);

class TransactionInput extends StatelessWidget {
  final TransactionInputCallback inputHandler;

  TransactionInput({required this.inputHandler});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
              ),
            ),
            ElevatedButton(
              onPressed: () => inputHandler(Transaction(
                id: '',
                title: '',
                amount: 100,
                date: DateTime.now(),
              )),
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
