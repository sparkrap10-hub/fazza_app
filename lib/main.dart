// main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login_screen.dart';
import 'home.dart';
import 'admin/admin_screen.dart';
import 'splash_screen.dart';
import 'firebase_options.dart'; // <-- Add this import

// استيراد شاشة تفاصيل الطلب (يجب إنشاؤها)
// import 'request_details_screen.dart';
// ✅ إنشاء GlobalKey للتنقل من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// ✅ نسخة عالمية من المكون لإدارتها بسهولة
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// ✅ معالج الرسائل في الخلفية
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  showNotification(message);
}

// ✅ دالة عرض الإشعار
void showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'requests_channel', // معرف القناة
    'طلبات الخدمة', // اسم القناة
    channelDescription: 'إشعارات تتعلق بطلبات المستخدم',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    // sound: RawResourceAndroidNotificationSound('notification_sound'), // ✅ إلغاء التعليق إذا كان الصوت مضافًا
    styleInformation:  BigTextStyleInformation(''),
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID فريد
    message.notification?.title ?? "إشعار جديد",
    message.notification?.body ?? "لديك إشعار جديد",
    platformChannelSpecifics,
    payload: message.data['requestId'] ?? '',
  );
}

// ✅ نقطة الدخول الرئيسية للتطبيق
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <-- Use this!
  );

  // ✅ تهيئة الإشعارات المحلية
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
          '@mipmap/ic_launcher'); // أو '@drawable/ic_notification'

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      // ✅ عند الضغط على الإشعار
      if (details.payload!.isNotEmpty) {
        navigatorKey.currentState
            ?.pushNamed('/request-details', arguments: details.payload);
      }
    },
  );

  // ✅ FCM: معالج الرسائل في الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ الحصول على FCM Token وتخزينه في Firestore
  String? token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  // ✅ FCM: استقبال الإشعارات في المقدمة
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showNotification(message);
  });

  // ✅ FCM: عند الضغط على الإشعار من الخلفية
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final requestId = message.data['requestId'];
    if (requestId != null) {
      navigatorKey.currentState
          ?.pushNamed('/request-details', arguments: requestId);
    }
  });

  // ✅ تشغيل التطبيق - مرة واحدة فقط!
  runApp(const MyApp());
}

// ✅ ويدجت الجذر للتطبيق
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  double _textScale = 1.0;
  Locale _locale = const Locale('ar');

  void _toggleTheme(bool isDark) => setState(() => _isDarkMode = isDark);
  void _changeTextScale(double scale) => setState(() => _textScale = scale);
  void _changeLocale(Locale locale) => setState(() => _locale = locale);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ ربط GlobalKey
      title: 'فزع',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
          // يمكنك تخصيص الثيم الفاتح هنا
          ),
      darkTheme: ThemeData.dark().copyWith(
          // يمكنك تخصيص الثيم الداكن هنا
          ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: _textScale),
          child: child!,
        );
      },
      // ✅ تعريف المسارات
      routes: {
        // '/request-details': (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as String;
        //   return RequestDetailsScreen(requestId: args);
        // },
        // يمكنك إضافة مسارات أخرى هنا
      },
      home:  SplashScreen(), // شاشة البداية
    );
  }
}

// ✅ شاشة وسيطة لتحديد الدور
class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return LoginScreen(onLoginSuccess: null);
    }

    // الوصول إلى دوال التحكم في الثيم وحجم الخط من _MyAppState
    final myAppState = context.findAncestorStateOfType<_MyAppState>();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text("خطأ في جلب دور المستخدم: ${snapshot.error}")));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          print(
              "لم يتم العثور على مستند المستخدم لـ UID: ${user.uid}. سيتم الافتراض إلى دور 'user'.");
          return HomeMapScreen(
            onThemeChanged: myAppState?._toggleTheme,
            onFontSizeChanged: myAppState?._changeTextScale,
            onLocaleChanged: myAppState?._changeLocale,
          );
        }

        final data = snapshot.data!.data();
        final role = data?['role'] ?? 'user';

        if (role == 'admin') {
          return const AdminDashboard();
        } else {
          return HomeMapScreen(
            onThemeChanged: myAppState?._toggleTheme,
            onFontSizeChanged: myAppState?._changeTextScale,
            onLocaleChanged: myAppState?._changeLocale,
          );
        }
      },
    );
  }
}
