/// 📝 جميع قوالب ورسائل الواتساب الخاصة بالتطبيق
/// يمكنك تعديل وتخصيص النصوص والعبارات من هذا الملف مباشرة في أي وقت.
class WhatsAppTemplates {
  // ─── 1. رسالة العميل عند تسجيل طلب الشحن (تُرسل للإدارة) ───────────────────
  static String depositRequestMessage({
    required String userName,
    required String userPhone,
    required String accountNumber,
    required double amount,
  }) {
    final now = DateTime.now();
    final period = now.hour >= 12 ? 'م' : 'ص';
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final formattedDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} – $hour12:$minuteStr $period';

    return '''📋 *طلب شحن رصيد – شبكة تاج نت*
━━━━━━━━━━━━━━━━━━━━
👤 *اسم العميل:* $userName
🔢 *رقم الحساب:* $accountNumber
💰 *المبلغ المحوّل:* $amount ريال
━━━━━━━━━━━━━━━━━━━━
⏰ *تاريخ الطلب:* $formattedDate
📎 *صورة سند الإيداع مرفقة مع هذه الرسالة*
✅ *يرجى التأكد من السند وإضافة الرصيد إلى المحفظة فوراً.*''';
  }

  // ─── 2. رسالة موافقة الإدارة وشحن المحفظة (تُرسل للعميل) ─────────────────────
  static String depositApprovalMessage({
    required String userName,
    required String accountNumber,
    required double amount,
  }) {
    return '''🎉 *إشعار موافقة وشحن محفظة – شبكة تاج نت*
━━━━━━━━━━━━━━━━━━━━
مرحباً بك عزيزي *$userName* 👤
تمت الموافقة على طلبك وتم شحن محفظتك بنجاح! ✅

💳 *المبلغ المضاف:* $amount ريال
━━━━━━━━━━━━━━━━━━━━
شكراً لاستخدامك خدمات شبكة تاج نت! 🚀''';
  }

  // ─── 3. رسالة رفض طلب الشحن (تُرسل للعميل) ──────────────────────────────────
  static String depositRejectionMessage({
    required String userName,
    required String accountNumber,
    required double amount,
    required String reason,
  }) {
    final noteStr = reason.trim().isNotEmpty
        ? reason.trim()
        : 'السند غير مطابق أو غير واضح';

    return '''⚠️ *إشعار بشأن طلب شحن الرصيد – شبكة تاج نت*
━━━━━━━━━━━━━━━━━━━━
عزيزي العميل *$userName* 👤
نود إبلاغك بأنه تعذر قبول طلب شحن الرصيد بمبلغ *$amount ريال*.

❌ *السبب:* $noteStr
━━━━━━━━━━━━━━━━━━━━
يرجى التأكد من السند وإعادة التقديم أو التواصل مع الدعم الفني.''';
  }

  // ─── 4. رسالة استفسار مباشر من المدير للعميل ───────────────────────────────
  static String clientInquiryMessage({
    required String userName,
    required double amount,
    required String accountNumber,
  }) {
    return '''مرحباً $userName 👤
بخصوص طلب شحن الرصيد بمبلغ $amount ريال (رقم الحساب: $accountNumber)...''';
  }

  // ─── 5. رسالة تفعيل الحساب وإرسال الكود للعميل (سابقاً) ──────────────────
  static String accountActivationMessage({
    required String userName,
    required String code,
  }) {
    return '''🎉 *رمز تفعيل حسابك في شبكة تاج نت*
━━━━━━━━━━━━━━━━━━━━
مرحباً بك عزيزي *$userName* 👤
تمت الموافقة على طلب إنشاء حسابك في شبكة تاج نت!

🔐 *رمز التفعيل الخاص بك هو:*
👉 *$code* 👈

يرجى إدخال هذا الرمز داخل التطبيق لتأكيد وتفعيل حسابك والبدء في الاستخدام.
━━━━━━━━━━━━━━━━━━━━
نتمنى لك تجربة ممتعة مع شبكة تاج نت! 🚀''';
  }

  // ─── 5.5. رسالة إنشاء الحساب وإرسال كلمة المرور (النظام المعتمد الجديد) ──────
  static String accountCreatedWithPasswordMessage({
    required String userName,
    required String phone,
    required String email,
    required String password,
  }) {
    final emailLine = email.trim().isNotEmpty ? '📧 *البريد الإلكتروني:* $email\n' : '';
    return '''🎉 *تم إنشاء وتفعيل حسابك في شبكة تاج نت!* 👑🚀
━━━━━━━━━━━━━━━━━━━━
مرحباً بك عزيزي *$userName* 👤
تمت الموافقة على طلبك وإنشاء حسابك بنجاح.

🔑 *بيانات تسجيل الدخول الخاصة بك:*
📱 *رقم الهاتف:* $phone
$emailLine🔐 *كلمة المرور:* *$password*
━━━━━━━━━━━━━━━━━━━━
📲 يمكنك الآن فتح تطبيق تاج نت وتسجيل الدخول مباشرة باستخدام رقم هاتفك (أو بريدك الإلكتروني) مع كلمة المرور أعلاه.

💡 *ملاحظة أمنية هامة:*
يُنصح بتغيير كلمة المرور بعد تسجيل الدخول من خلال:
(حسابي ⚙️ ⬅️ معلومات الحساب 🔒 ⬅️ تغيير كلمة المرور).

نتمنى لك تجربة ممتعة وسريعة مع شبكة تاج نت! 🌐⚡''';
  }

  // ─── 6. رسالة رفض طلب إنشاء الحساب ─────────────────────────────────────────
  static String registrationRejectionMessage({
    required String userName,
    required String reason,
  }) {
    final noteStr = reason.trim().isNotEmpty
        ? reason.trim()
        : 'البيانات غير مطابقة أو لم يتم التحقق منها';

    return '''⚠️ *إشعار بشأن طلب إنشاء الحساب – شبكة تاج نت*
━━━━━━━━━━━━━━━━━━━━
عزيزي *$userName* 👤
نود إبلاغك بأنه تعذر قبول طلب إنشاء حسابك في التطبيق حالياً.

❌ *السبب:* $noteStr
━━━━━━━━━━━━━━━━━━━━
يرجى التواصل مع الدعم الفني للاستفسار والمساعدة.''';
  }
}
