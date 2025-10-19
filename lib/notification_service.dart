// notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> showRequestAcceptedNotification({
    required String serviceName,
    String? providerName,
  }) async {
    try {
      // ✅ تم إزالة const لأننا نستخدم قيمًا ديناميكية
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'request_accepted_channel',
        'طلب مقبول',
        channelDescription: 'إشعار يفيد بقبول طلب الخدمة الخاص بك',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        // sound: RawResourceAndroidNotificationSound('notification_sound'),
        styleInformation: BigTextStyleInformation(
          'مبروك! تم قبول طلبك لخدمة "$serviceName" من قبل المزود${providerName != null ? " ($providerName)" : ""}. سيصل إليك قريبًا.',
        ),
      );

      // ✅ تم إزالة const
      final NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎉 تم قبول طلبك!',
        'اضغط لعرض التفاصيل',
        platformDetails,
        payload: 'request_accepted',
      );
    } catch (e) {
      print('خطأ في عرض إشعار قبول الطلب: $e');
    }
  }
}
