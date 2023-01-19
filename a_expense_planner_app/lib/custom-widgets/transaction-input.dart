import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction-input-data.dart';

typedef TransactionInputDataCallback = void Function(TransactionInputData);

class TransactionInput extends StatefulWidget {
  final TransactionInputDataCallback inputHandler;

  const TransactionInput({
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
  DateTime? _date;

  void _submitData() {
    /*
      print('${_title.text} ${_amount.text}');
      print('$_titleInput $_amountInput');
    */
    String enteredTitle = _title.text;
    double enteredAmount = double.parse(_amount.text);
    if (enteredTitle.trim().isEmpty || enteredAmount < 0 || _date == null) {
      return;
    }

    DateTime date = _date!;
    widget.inputHandler(TransactionInputData(
      title: _title.text,
      amount: double.parse(_amount.text),
      date: date,
    ));

    Navigator.of(context).pop();
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    ).then(_chooseDate);
  }

  void _chooseDate(DateTime? date) {
    print(date);
    if (date == null) {
      return;
    }
    setState(() {
      _date = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Title'),
              controller: _title,
              // onChanged: (value) => _titleInput = value,
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              controller: _amount,
            ),
            SizedBox(
              height: 70,
              child: Row(children: [
                Expanded(
                  child: Text(_date == null
                      ? 'No date chosen.'
                      : 'Picked date: ${DateFormat.yMd().format(_date!)}'),
                ),
                TextButton(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(
                        Theme.of(context).primaryColor),
                  ),
                  onPressed: _presentDatePicker,
                  child: const Text(
                    'Add date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              ]),
            ),
            ElevatedButton(
              onPressed: _submitData,
              // or onPressed: () => submitData,
              /*
              onPressed: () => inputHandler(TransactionInputData(
                title: _titleInput,
                amount: _amountInput,
              )),
              */
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all(
                    Theme.of(context).textTheme.button?.color),
              ),
              child: const Text(
                'Add transaction',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
