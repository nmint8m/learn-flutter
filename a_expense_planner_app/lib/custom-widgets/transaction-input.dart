import 'package:flutter/material.dart';
import '../models/transaction-input-data.dart';

typedef TransactionInputDataCallback = void Function(TransactionInputData);

class TransactionInput extends StatefulWidget {
  final TransactionInputDataCallback inputHandler;

  TransactionInput({
    super.key,
    required this.inputHandler,
  });

  @override
  State<TransactionInput> createState() => _TransactionInputState();
}

class _TransactionInputState extends State<TransactionInput> {
  /*
  late String _titleInput;
  late String _amountInput;
  */

  final _title = TextEditingController();
  final _amount = TextEditingController();

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

    widget.inputHandler(TransactionInputData(
      title: _title.text,
      amount: double.parse(_amount.text),
    ));

    Navigator.of(context).pop();
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
