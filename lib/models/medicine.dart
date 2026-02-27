import 'package:flutter/material.dart';

class Medicine {
  final String id;
  final String name;
  final TimeOfDay time;
  bool isTaken;

  Medicine({
    required this.id,
    required this.name,
    required this.time,
    this.isTaken = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hour': time.hour,
    'minute': time.minute,
    'isTaken': isTaken,
  };

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
      isTaken: json['isTaken'] as bool,
    );
  }
}
