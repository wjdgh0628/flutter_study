import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../services/notification_service.dart';

class TodayMedicineScreen extends StatefulWidget {
  const TodayMedicineScreen({super.key});

  @override
  State<TodayMedicineScreen> createState() => _TodayMedicineScreenState();
}

class _TodayMedicineScreenState extends State<TodayMedicineScreen> {
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('medicines');

    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        _medicines = decoded.map((item) => Medicine.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      _medicines = [
        Medicine(id: '1', name: '고혈압약', time: const TimeOfDay(hour: 8, minute: 0)),
        Medicine(id: '2', name: '비타민C', time: const TimeOfDay(hour: 12, minute: 30)),
        Medicine(id: '3', name: '오메가3', time: const TimeOfDay(hour: 12, minute: 30)),
        Medicine(id: '4', name: '마그네슘', time: const TimeOfDay(hour: 20, minute: 0)),
      ];
      await _saveMedicines();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_medicines.map((m) => m.toJson()).toList());
    await prefs.setString('medicines', encoded);

    for (var medicine in _medicines) {
      if (!medicine.isTaken) {
        await NotificationService().scheduleDailyNotification(
          int.parse(medicine.id),
          medicine.name,
          medicine.time,
        );
      } else {
        await NotificationService().cancelNotification(int.parse(medicine.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _medicines.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final medicine = _medicines[index];
          return ListTile(
            leading: Checkbox(
              value: medicine.isTaken,
              onChanged: (value) async {
                setState(() {
                  medicine.isTaken = value ?? false;
                });
                await _saveMedicines();
              },
            ),
            title: Text(
              medicine.name,
              style: TextStyle(
                decoration: medicine.isTaken ? TextDecoration.lineThrough : null,
                color: medicine.isTaken ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Text(medicine.time.format(context)),
          );
        },
      ),
    );
  }
}
