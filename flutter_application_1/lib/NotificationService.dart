import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'notes_channel_v2';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDesc = 'Reminder notifications for notes';

  Future<void> init() async {
    // 1) TZ init (Türkiye için sabitle)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    print("✅ tz.local=${tz.local} NOW=${tz.TZDateTime.now(tz.local)}");

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        print("🔔 onDidReceiveNotificationResponse payload=${resp.payload}");
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // 2) Android 13+ permission
    final perm = await androidPlugin?.requestNotificationsPermission();
    print("✅ requestNotificationsPermission=$perm");

    final enabled = await androidPlugin?.areNotificationsEnabled();
    print("✅ areNotificationsEnabled=$enabled");

    // 3) Exact alarm permission (Android 12+)
    final exact = await androidPlugin?.canScheduleExactNotifications();
    print("✅ canScheduleExactNotifications=$exact");

    await androidPlugin?.requestExactAlarmsPermission();

    // 4) Kanalı kesin oluştur (id değişince cache sorunu da biter)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    await androidPlugin?.createNotificationChannel(channel);

    // 5) Debug: pending listele
    await debugPending();
  }

  Future<void> debugPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    print("📌 PENDING COUNT=${pending.length}");
    for (final p in pending) {
      print("   - pending id=${p.id} title=${p.title}");
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  Future<void> showNow() async {
    await _plugin.show(
      999999,
      "TEST",
      "Bu anında bildirim testi",
      _details(),
    );
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final nowLocal = DateTime.now();
    final diff = dateTime.difference(nowLocal).inSeconds;

    final scheduled = tz.TZDateTime.from(dateTime, tz.local);
    final nowTz = tz.TZDateTime.now(tz.local);

    print(
        "🕒 NOW(local)=$nowLocal | SCHEDULED(local)=$dateTime | diffSec=$diff");
    print("🌍 NOW(tz)=$nowTz | SCHEDULED(tz)=$scheduled | tz=${tz.local}");

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print("✅ zonedSchedule OK. id=$id");
    await debugPending();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    print("🧹 cancel id=$id");
    await debugPending();
  }
}
