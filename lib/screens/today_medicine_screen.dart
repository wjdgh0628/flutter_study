import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전화 연결을 할 수 없습니다.')),
        );
      }
    }
  }

  void _showMedicineForm({Medicine? medicine}) {
    final isEditing = medicine != null;
    final nameController = TextEditingController(text: medicine?.name ?? '');
    final guardianController = TextEditingController(text: medicine?.guardianContact ?? '');
    TimeOfDay selectedTime = medicine?.time ?? TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? '약 정보 수정' : '새로운 약 등록',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() => _medicines.remove(medicine));
                        _saveMedicines();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '약 이름',
                  hintText: '예: 비타민C, 고혈압약',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('복용 시간'),
                subtitle: Text(selectedTime.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.access_time),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: selectedTime);
                  if (time != null) setModalState(() => selectedTime = time);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: guardianController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '보호자 연락처 (3차 비상 알림용)',
                  hintText: '예: 010-1234-5678',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.contact_phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isEmpty) return;
                    
                    final newMedicine = Medicine(
                      id: isEditing ? medicine.id : DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      time: selectedTime,
                      isTaken: isEditing ? medicine.isTaken : false,
                      guardianContact: guardianController.text,
                    );

                    setState(() {
                      if (isEditing) {
                        final index = _medicines.indexOf(medicine);
                        _medicines[index] = newMedicine;
                      } else {
                        _medicines.add(newMedicine);
                      }
                    });
                    _saveMedicines();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(isEditing ? '수정 완료' : '등록 완료', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final takenCount = _medicines.where((m) => m.isTaken).length;
    final totalCount = _medicines.length;
    final progress = totalCount > 0 ? takenCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMedicineForm(),
        label: const Text('약 추가'),
        icon: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(progress, takenCount, totalCount),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                '복용 목록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _medicines.length,
              itemBuilder: (context, index) {
                final medicine = _medicines[index];
                return _buildMedicineCard(medicine);
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress, int taken, int total) {
    String todayStr = DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now());
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todayStr,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '오늘의 건강 체크',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 $total개 중 $taken개 완료',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine) {
    return Dismissible(
      key: Key(medicine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('약 정보 삭제'),
            content: Text('${medicine.name} 정보를 삭제하시겠습니까?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        setState(() => _medicines.remove(medicine));
        _saveMedicines();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${medicine.name} 정보가 삭제되었습니다.')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: medicine.isTaken ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: medicine.isTaken ? Colors.transparent : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            if (!medicine.isTaken)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              setState(() => medicine.isTaken = !medicine.isTaken);
              await _saveMedicines();
            },
            onLongPress: () => _showMedicineForm(medicine: medicine),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: medicine.isTaken 
                          ? Colors.grey.shade200 
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medication_outlined,
                      color: medicine.isTaken 
                          ? Colors.grey 
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: medicine.isTaken ? Colors.grey : Colors.black87,
                            decoration: medicine.isTaken ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medicine.time.format(context),
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (medicine.guardianContact != null && medicine.guardianContact!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.shield_outlined, size: 24, color: Colors.blue),
                        onPressed: () => _makePhoneCall(medicine.guardianContact!),
                        tooltip: '보호자에게 전화 걸기',
                      ),
                    ),
                  Icon(
                    medicine.isTaken ? Icons.check_circle : Icons.circle_outlined,
                    color: medicine.isTaken 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey.shade300,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
