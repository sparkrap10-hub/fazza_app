# 🚨 فزع (Fazaa) - تطبيق المساعدة على الطريق

تطبيق **فزع (Fazaa)** هو حل متكامل لخدمات المساعدة على الطريق، مصمم لربط المستخدمين الذين يحتاجون إلى مساعدة عاجلة لمركباتهم مع مقدمي الخدمات المتاحين في منطقتهم.  
تم بناء التطبيق باستخدام إطار عمل **Flutter**، مما يضمن تجربة مستخدم سلسة وأداءً عاليًا على أنظمة **Android** و **iOS**.

![واجهة التطبيق](https://disturbing-coral-dchnrxjdqs.edgeone.app/logo.png))  
> *(ملاحظة: استبدل الرابط أعلاه بصورة فعلية لواجهة التطبيق)*

---

## 🚀 الميزات الرئيسية

- **واجهتان:**
  - للمستخدم
  - لمقدم الخدمة / المسؤول
- **تحديد الموقع الجغرافي:**  
  باستخدام خرائط **OpenStreetMap** لتحديد موقع المستخدم وتقديم الخدمة بدقة.
- **طلبات خدمة متعددة:**  
  (صيانة – وقود – سحب – إلخ)
- **مصادقة آمنة:**  
  تسجيل دخول وإنشاء حساب باستخدام **Firebase Authentication**.
- **إشعارات فورية (Push Notifications):**  
  باستخدام **Firebase Cloud Messaging (FCM)**، وتعمل في:
  - المقدمة (Foreground)
  - الخلفية (Background)
  - حتى عند إغلاق التطبيق  
  *(مع إمكانية التنقل إلى شاشة تفاصيل الطلب مباشرة)*.
- **إعدادات مخصصة للمستخدم:**
  - الوضع الليلي 🌙  
  - التحكم في حجم الخط 🔠  
- **هيكلية نظيفة ومنظمة:**  
  لتسهيل الصيانة والتطوير المستقبلي.

---

## 🛠️ التقنيات المستخدمة

| التقنية | الاستخدام |
|----------|------------|
| **Flutter** | إطار العمل الأساسي |
| **Firebase** | الخدمات السحابية (Backend) |
| **Firestore** | تخزين بيانات المستخدمين والطلبات |
| **Authentication** | مصادقة المستخدمين |
| **Cloud Messaging (FCM)** | الإشعارات الفورية |
| **flutter_map** | عرض خرائط OpenStreetMap |
| **geolocator** | تحديد موقع المستخدم |
| **flutter_local_notifications** | عرض الإشعارات محليًا |
| **إدارة الحالة** | تعتمد على `StatefulWidget` و `setState` (قابلة للتطوير لاحقًا إلى Provider أو Riverpod) |

---

## ⚙️ متطلبات التشغيل

- Flutter SDK (الإصدار 3.0.0 أو أحدث)
- Android Studio أو VS Code
- حساب Firebase مع مشروع معد مسبقًا

---

## 🚀 بدء الاستخدام

1. **استنساخ المستودع:**
   ```bash
   git clone https://github.com/sparkrap10-hub/fazza_app.git
   cd fazza_app
**الهيكل**
lib/
├── admin/               # شاشات لوحة تحكم المسؤول
│   └── admin_screen.dart
├── model/               # نماذج البيانات (User, Request)
├── services/            # إدارة الخدمات (Firebase, Notifications)
├── widgets/             # الويدجتس القابلة لإعادة الاستخدام
├── admin_screen.dart    # (يُنقل إلى مجلد admin)
├── home.dart            # شاشة الخريطة الرئيسية
├── login_screen.dart    # شاشة تسجيل الدخول
├── main.dart            # نقطة الدخول
├── register_screen.dart # إنشاء حساب جديد
├── request_screen.dart  # طلب خدمة
└── splash_screen.dart   # شاشة البداية
🤝 المساهمة

نرحب بمساهماتكم لتطوير المشروع ❤️
اتبع الخطوات التالية:

Fork المستودع

إنشاء فرع جديد:

git checkout -b feature/AmazingFeature


تنفيذ التغييرات ثم:

git commit -m 'Add some AmazingFeature'
git push origin feature/AmazingFeature


افتح Pull Request

