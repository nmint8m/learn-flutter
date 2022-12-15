import 'package:flutter/material.dart';
import '../models/transaction-input-data.dart';

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

  void submitData() {
    /*
      print('${_title.text} ${_amount.text}');
      print('$_titleInput $_amountInput');
    */
    String enteredTitle = _title.text;
    double enteredAmount = double.parse(_amount.text);
    if (enteredTitle.trim().isEmpty || enteredAmount < 0) {
      return;
    }

    inputHandler(TransactionInputData(
      title: _title.text,
      amount: double.parse(_amount.text),
    ));
  }

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
              onSubmitted: (_) => submitData,
            ),
            ElevatedButton(
              onPressed: submitData,
              // or onPressed: () => submitData,
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
