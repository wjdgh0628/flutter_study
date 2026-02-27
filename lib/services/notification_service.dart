import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Android 13+ 알림 권한 요청
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleDailyNotification(int id, String name, TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 1차: 정시 일반 알림
    await _notifications.zonedSchedule(
      id,
      '복약 알람',
      '$name 드실 시간입니다!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminder_channel',
          '약 복용 알림',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 2차: 30분 후 긴급 알람 (ID는 기본 ID + 1000)
    await _notifications.zonedSchedule(
      id + 1000,
      '긴급 복약 알림',
      '아직 $name을 복용하지 않으셨습니다! 지금 바로 드세요.',
      scheduledDate.add(const Duration(minutes: 30)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'urgent_medicine_channel',
          '긴급 복약 알림',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // 전화 화면 효과
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 3차: 1시간 후 보호자 연락 권고 (ID는 기본 ID + 2000)
    await _notifications.zonedSchedule(
      id + 2000,
      '미복용 상태 지속',
      '장시간 미복용 상태입니다. 보호자에게 연락이 갈 수 있습니다.',
      scheduledDate.add(const Duration(hours: 1)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'guardian_alert_channel',
          '보호자 알림 예고',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);        // 1차 취소
    await _notifications.cancel(id + 1000); // 2차 취소
    await _notifications.cancel(id + 2000); // 3차 취소
  }
}
