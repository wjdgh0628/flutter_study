import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 ID 가져오기 (비로그인 상태면 익명 로그인 권장)
  String? get userId => _auth.currentUser?.uid;

  // 약 정보 목록 스트림 (실시간 업데이트 지원)
  Stream<List<Medicine>> getMedicines() {
    if (userId == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // 약 정보 추가/업데이트
  Future<void> saveMedicine(Medicine medicine) async {
    if (userId == null) return;

    await _db
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicine.id)
        .set(medicine.toJson());
  }

  // 복용 상태 업데이트
  Future<void> updateTakenStatus(String medicineId, bool isTaken) async {
    if (userId == null) return;

    await _db
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicineId)
        .update({'isTaken': isTaken});
  }
}
