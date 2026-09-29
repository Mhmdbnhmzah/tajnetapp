# 🌐 تطبيق شبكة تاج نت | TajNet App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web_Live-4285F4?style=for-the-badge&logo=google-chrome&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)

**منظومة متكاملة لإدارة شبكات الواي فاي (MikroTik Hotspot)، متجر بيع الكروت، المحفظة الرقمية، ولوحة تحكم الإدارة الذكية.**

[🔗 تجربة النسخة الحية على الويب (Web App)](https://tajnetapp.web.app)

</div>

---

## 📖 نبذة عن المشروع (Overview)

**تطبيق تاج نت (TajNet)** هو حل برمجي شامل ومبتكر مخصص لشبكات توزيع خدمة الإنترنت اللاسلكي (Wi-Fi Networks). يربط التطبيق بين المشتركين وسيرفرات المايكروتك (MikroTik RouterOS) عبر سحابة **Google Firebase**، مما يتيح للمشتركين شراء كروت الإنترنت وشحن محافظهم ومتابعة استهلاكهم على مدار 24 ساعة، مع توفير لوحة تحكم متقدمة لإدارة الشبكة والمخزون والعمليات المالية بدقة متناهية.

---

## ✨ المميزات الرئيسية (Key Features)

### 📱 أولاً: ميزات المشتركين (Client Features)

* **🛒 متجر شراء الكروت 24/7:** شراء فوري لكروت الإنترنت بمختلف الباقات والسرعات في أي وقت دون الحاجة لزيارة نقاط البيع.
* **📋 محفظة كروتي الذكية (Offline Caching):** حفظ تلقائي لكافة الكروت المشتراة مع إمكانية استعراضها ونسخ رموز الـ PIN حتى في حال انقطاع الإنترنت تماماً.
* **💳 شحن المحفظة عبر البنوك والمحافظ اليمنية:** دعم التحويل عبر (بنك الكريمي، شركة العمقي، بنك القطيبي، محفظة ون كاش، محفظة جيب، وغيرها) مع عرض شعار وبيانات كل بنك ونسخها بلمسة واحدة.
* **💸 تحويل الرصيد المباشر (P2P Balance Transfer):** تحويل رصيد فوري وآمن بين حسابات المشتركين برقم الحساب مع إشعارات فورية للمستلم.
* **⏱️ مراقبة الرصيد والاستهلاك:** استعلام لحظي عن الرصيد المتبقي، الوقت، واستهلاك البيانات.
* **🔒 أمان متقدم للمحفظة:** حماية العمليات المالية برمز سري مشفر (Wallet Security PIN) ودعم الدخول البيومتري (بصمة الإصبع / الوجه).
* **⚡ فحص سرعة الاتصال (Speed Test):** أداة مدمجة داخل التطبيق لقياس سرعة الإنترنت وجودة الاتصال بالشبكة.

---

### 🛡️ ثانياً: ميزات لوحة تحكم الإدارة (Admin Features)

* **📦 إدارة مخزون الكروت:** رفع كميات ضخمة من الكروت دفعة واحدة (Bulk Import)، ومتابعة الكروت المتاحة والمباعة لكل فئة.
* **💰 إدارة وتدقيق طلبات الشحن:** مراجعة طلبات شحن المحفظة الواردة، واعتماد الإيداع أو رفضه مع تحديث رصيد العميل آلياً بمعاملة ذرية آمنة.
* **👥 إدارة المستخدمين:** استعراض قائمة المشتركين، البحث بالاسم أو رقم الهاتف أو الحساب، تجميد أو تفعيل الحسابات، وإعادة ضبط رمز حماية المحفظة.
* **🏦 إدارة الحسابات والمحافظ البنكية:** إضافة وتعديل الحسابات البنكية المعتمدة لاستقبال الحوالات مع رفع شعارات البنوك المخصصة.
* **📊 التحليلات والتقارير المالية:** إحصائيات دقيقة وفورية لحجم المبيعات، إجمالي الإيداعات، والأرباح.
* **📢 نظام الإشعارات الموجهة (FCM HTTP v1):** إرسال تنبيهات جماعية لكافة المشتركين أو إشعارات مخصصة لعميل معين.
* **🔄 التحكم في إصدار التطبيق (Force Update):** إمكانية إجبار المستخدمين على التحديث عند إطلاق إصدارات جديدة لضمان توافق النظام.

---

## 🏗️ البنية المعمارية وإدارة الحالة (Architecture & State Management)

يعتمد المشروع على نمط **MVVM (Model-View-ViewModel)** مع استخدام **Provider** و **ChangeNotifier**:

```
lib/
├── core/                       # الأدوات الأساسية المشتركة
│   ├── constants/              # الثوابت والإعدادات العامة (Config, WhatsApp Templates)
│   ├── models/                 # كائنات البيانات (AppUser, CardItem, BankAccount, ...)
│   ├── services/               # الخدمات المشتركة (Notifications, Cache, Force Update)
│   ├── theme/                  # هوية التطبيق البصرية، الألوان، والتدرجات النيونية
│   └── widgets/                # الودجت المخصصة القابلة لإعادة الاستخدام
│
├── features/                   # الميزات والوحدات الوظيفية
│   ├── auth/                   # المصادقة، تسجيل الدخول، والتحقق البيومتري
│   │   ├── data/               # خدمات Firebase Auth و MikroTik
│   │   ├── viewmodels/         # AuthViewModel
│   │   └── views/              # شاشات تسجيل الدخول والتحقق
│   │
│   ├── store/                  # المتجر، المحفظة، وشراء الكروت
│   │   ├── data/               # StoreService والمعاملات المالية
│   │   ├── viewmodels/         # StoreViewModel
│   │   └── views/              # شاشات شراء الكروت، كروتي، والشحن
│   │
│   └── admin/                  # لوحة تحكم المشرف والإدارة
│       ├── data/               # AdminService
│       ├── viewmodels/         # AdminViewModel
│       └── views/              # شاشات إدارة الكروت، الإيداعات، والمستخدمين
│
└── main.dart                   # نقطة انطلاق التطبيق وتهيئته
```

---

## 🔒 الأمان المالي والمعاملات الذرية (Security & Financial Integrity)

* **Atomic Transactions:** جميع العمليات المالية الحساسة (خصم الرصيد، شراء الكرت، تحويل الأموال، واعتماد الإيداع) تُنفذ عبر `FirebaseFirestore.instance.runTransaction` لضمان مبدأ (All-or-Nothing) ومنع أي تضارب أو تكرار لبيع الكروت (Race Conditions).
* **Firestore Security Rules:** قواعد أمان سحابية صارمة تمنع التلاعب بالأرصدة من جانب العميل، وتضمن صلاحيات القراءة والتعديل لكل دور (`admin` / `user`).
* **SHA-256 Wallet Hashing:** تشفير رمز المحفظة السري وتأمينه ضد محاولات الاختراق.

---

## 🚀 التشغيل والتثبيت (Getting Started)

### المتطلبات الأساسية (Prerequisites):
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (الإصدار `^3.10.7` فما فوق).
* [Firebase CLI](https://firebase.google.com/docs/cli) لإدارة ونشر الخدمات السحابية.
* حساب Firebase مفعل مع تفعيل (Authentication, Firestore, Storage, Hosting).

### خطوات التثبيت:

1. **استنساخ المستودع (Clone the repository):**
   ```bash
   git clone https://github.com/Mhmdbnhmzah/tajnetapp.git
   cd tajnetapp
   ```

2. **تثبيت الحزم والمكتبات (Install dependencies):**
   ```bash
   flutter pub get
   ```

3. **تشغيل التطبيق على محاكي أو جهاز حقيقي:**
   ```bash
   flutter run
   ```

---

## 📦 البناء والنشر (Building & Deployment)

### 1. بناء تطبيق أندرويد (Android APK):
```bash
flutter build apk --release
```

### 2. بناء ونشر نسخة الويب (Firebase Hosting):
```bash
# بناء نسخة الويب
flutter build web --release

# نشر الموقع وقواعد الحماية السحابية
firebase deploy --only "hosting,firestore:rules"
```

---

## 🛠️ التقنيات المستخدمة (Tech Stack)

* **Framework:** [Flutter](https://flutter.dev/)
* **Language:** [Dart](https://dart.dev/)
* **Backend:** [Firebase](https://firebase.google.com/) (Auth, Firestore, Cloud Storage, Cloud Messaging, Hosting)
* **State Management:** [Provider](https://pub.dev/packages/provider)
* **Network Integration:** MikroTik RouterOS API & HTTP Services
* **Design & UI:** Google Fonts (Tajawal), Dark Luxury Neon Design System

---

## 📄 الترخيص وحقوق الملكية (License)

هذا المشروع ملك لـ **شبكة تاج نت (TajNet)**. جميع الحقوق محفوظة © 2026.
