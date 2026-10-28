import 'package:flutter/material.dart';

/// The live state of a table. Kept apart from the layout ([FloorPlan]) and
/// linked by table id, so bookings never touch the layout and moving a table
/// never loses its bookings.
enum TableStatus {
  free('Free', Color(0xFF81C784)),
  reserved('Reserved', Color(0xFFFFD54F)),
  occupied('Occupied', Color(0xFFE57373)),
  needsBill('Needs bill', Color(0xFF64B5F6));

  const TableStatus(this.label, this.color);

  final String label;
  final Color color;
}
