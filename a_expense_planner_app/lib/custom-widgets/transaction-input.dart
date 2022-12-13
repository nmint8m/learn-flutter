import 'package:flutter/material.dart';
import '/models/transaction-input-data.dart';

typedef TransactionInputDataCallback = void Function(TransactionInputData);

class TransactionInput extends StatelessWidget {
  final TransactionInputDataCallback inputHandler;

  /*
  late String _titleInput;
  late String _amountInput;
  */

  final _title = TextEditingController();
  final _amount = TextEditingController();

  TransactionInput({required this.inputHandler});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
              controller: _title,
              // onChanged: (value) => _titleInput = value,
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
              ),
              controller: _amount,
              // onChanged: (value) => _amountInput = value,
            ),
            ElevatedButton(
              onPressed: () {
                print('${_title.text} ${_amount.text}');
                // print('$_titleInput $_amountInput');
              },
              /*
              onPressed: () => inputHandler(TransactionInputData(
                title: _titleInput,
                amount: _amountInput,
              )),
              */
              child: Text('Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
