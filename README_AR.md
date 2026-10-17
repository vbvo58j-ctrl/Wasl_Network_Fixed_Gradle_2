# وصل — مشروع Flutter منظم

## المجلدات
- `lib/main.dart`: نقطة تشغيل التطبيق.
- `lib/screens/home_screen.dart`: الواجهة.
- `lib/models/chat_message.dart`: نموذج الرسائل.
- `lib/services/bluetooth_service.dart`: جسر Flutter إلى Bluetooth Classic الأصلي.
- `lib/services/local_database.dart`: تخزين SQLite محلي.
- `android/app/src/main/kotlin/.../MainActivity.kt`: تنفيذ البلوتوث في Android.
- `android/app/src/main/AndroidManifest.xml`: الأذونات وFlutter embedding v2.

## البناء
```bash
flutter clean
flutter create . --platforms=android
flutter pub get
flutter build apk --release
```

## تنبيه صريح
هذه حزمة مشروع منظمة وليست APK مختبراً أو منتجاً مضموناً. لم يتم بناء المشروع أو اختباره على أجهزة حقيقية هنا. البلوتوث المباشر ونموذج قبول طلب العضو موجودان في طبقة Android، لكن قبل الاستخدام الحقيقي يجب اختبار توافق القنوات على هاتفين، وإكمال تخزين الملفات وإعادة الاتصال التلقائي وتعدد الغرف وتشفير الرسائل. شبكة الترحيل لمسافات بعيدة عبر أجهزة الأعضاء غير منفذة؛ Bluetooth Classic لا يصنع شبكة Mesh تلقائياً. لا تستخدم النسخة للمعلومات الحساسة.
رابط الدعم فقط: https://wsend.co/967737414884
