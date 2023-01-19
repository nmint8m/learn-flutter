import 'package:flutter/material.dart';

class Bar extends StatelessWidget {
  final String weekday;
  final double total;
  final double percentOfTotal;

  const Bar({
    super.key,
    required this.weekday,
    required this.total,
    required this.percentOfTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(weekday.substring(0, 1)),
        const SizedBox(height: 4),
        SizedBox(
          height: 60,
          width: 10,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                  ),
                  color: Theme.of(context).disabledColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                heightFactor: percentOfTotal,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                    ),
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
            height: 20,
            child: FittedBox(
              child: Text('\$ ${total.toStringAsFixed(2)}'),
            )),
        Text(percentOfTotal.toStringAsFixed(2)),
      ],
    );
  }
}
