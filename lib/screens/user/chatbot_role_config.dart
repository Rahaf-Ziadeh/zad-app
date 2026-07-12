// ─────────────────────────────────────────────
// بنية الإعداد المشتركة لمساعد زاد حسب الدور — تفصل محتوى كل دور (رسالة
// ترحيب، أسئلة مقترحة، أنماط النية، نصوص الردود، إجراءات التنقّل، رسالة
// الفشل) عن منطق العرض والتنقّل الفعلي في ChatbotScreen، حتى لا يتكرر أي
// جزء من هذا المنطق داخل build() أو بين الأدوار. قابلة للتوسّع لاحقاً بإضافة
// دور "charity" دون تغيير ChatbotScreen نفسها — فقط بإضافة ChatbotRoleConfig
// جديد وربطه في configForRole ──
// ─────────────────────────────────────────────

/// الأدوار المدعومة حالياً. أي دور غير معروف يُعامَل كـ[individual] (وضع
/// المساعدة الأساسي) بدل الفشل أو ترك الشاشة بلا محتوى.
enum ChatbotRole { individual, restaurant }

ChatbotRole chatbotRoleFromString(String? raw) {
  switch (raw) {
    case 'restaurant':
      return ChatbotRole.restaurant;
    case 'individual':
    case 'user':
      return ChatbotRole.individual;
    default:
      // ── دور غير معروف (مثال: قيمة فارغة، أو دور مستقبلي كـ"charity" لم
      // يُضَف إعداده بعد) — رجوع آمن لوضع المساعدة الأساسي للفرد ──
      return ChatbotRole.individual;
  }
}

/// نتيجة معالجة نية واحدة: إمّا نص إرشادي (وحينها [chips] هي الأزرار التي
/// تظهر أسفله)، أو إجراء تنقّل مباشر عبر [navigationActionId] (تتولى
/// ChatbotScreen تنفيذه الفعلي عبر خرائط الاستدعاءات الخاصة بها؛ لا تحتوي
/// هذه الطبقة على أي BuildContext أو منطق واجهة).
class ChatbotResponse {
  final String? text;
  final List<String> chips;
  final String? navigationActionId;

  const ChatbotResponse.reply({required this.text, this.chips = const []})
      : navigationActionId = null;

  const ChatbotResponse.navigate(String actionId)
      : text = null,
        chips = const [],
        navigationActionId = actionId;
}

/// نية واحدة ضمن إعداد دور معيّن.
///
/// - [exactMatches]: نصوص الأزرار (chips) التي تُطابِق هذه النية تماماً عند
///   الضغط عليها أو كتابتها حرفياً.
/// - [keywords]: أجزاء نصية (بعد التطبيع) يُطابَق بها النص الحر إن لم يوجد
///   تطابق تام مع أي نية أخرى.
/// - [reply]/[replyChips]: للأسئلة الإرشادية — نص الرد وأزرار المتابعة.
/// - [navigationActionId]: للأزرار التي تُنفّذ تنقّلاً مباشراً بلا أي رد
///   نصي (مثل "اذهب إلى العروض")؛ يُستثنى مع [reply] عادةً.
class ChatbotIntent {
  final String id;
  final List<String> exactMatches;
  final List<String> keywords;
  final String Function()? reply;
  final List<String> replyChips;
  final String? navigationActionId;

  const ChatbotIntent({
    required this.id,
    this.exactMatches = const [],
    this.keywords = const [],
    this.reply,
    this.replyChips = const [],
    this.navigationActionId,
  });
}

/// إعداد كامل لدور واحد — يُستهلَك بالكامل من ChatbotScreen، ولا يحتوي على
/// أي حالة (state) أو BuildContext.
class ChatbotRoleConfig {
  final ChatbotRole role;
  final String welcomeMessage;
  final List<String> defaultChips;
  final String fallbackMessage;
  final List<ChatbotIntent> intents;

  const ChatbotRoleConfig({
    required this.role,
    required this.welcomeMessage,
    required this.defaultChips,
    required this.fallbackMessage,
    required this.intents,
  });
}

// ─── معرّفات إجراءات التنقّل المشتركة (تُستهلَك من ChatbotScreen فقط) ──────────
// موحّدة بين الدورين حيثما كان المعنى واحداً (offers/orders/notifications)
// حتى لا تُكرَّر خرائط الاستدعاءات، وتُميَّز حيث يختلف المعنى فعلياً.
const kNavOffers = 'offers'; // "عروضي" (مطعم) أو "العروض" (فرد)
const kNavPackages = 'packages'; // الباقات (فرد فقط)
const kNavOrders = 'orders'; // "طلباتي" (فرد) أو "حجوزاتي" (مطعم)
const kNavDonate = 'donate'; // تبويب التبرع (فرد فقط)
const kNavNotifications = 'notifications'; // مشتركة بين الدورين
const kNavAddOffer = 'add_offer'; // تبويب "إضافة" (مطعم فقط)
const kNavScanQr = 'scan_qr'; // ماسح QR (مطعم فقط)
const kNavDonateToCharity = 'donate_to_charity'; // تبرع لجمعية (مطعم فقط)
const kNavReviews = 'reviews'; // التقييمات (مطعم فقط)
const kNavComplaints = 'complaints'; // سجل الشكاوى (مطعم فقط)
const kNavContactAdmin = 'contact_admin'; // مشتركة — تُعالَج خاصةً في الشاشة
// ── نية غير متزامنة خاصة بالفرد فقط (تستعلم عن الموقع الجغرافي وأقرب
// العروض عبر Firestore) — لا يمكن تمثيلها كنص رد ثابت، فتُعالَج خاصةً في
// الشاشة تماماً مثل contact_admin، دون أي منطق تنقّل عام ──
const kNearestOffersAsync = 'nearest_offers_async';

// ─── إعداد الفرد (individual) ──────────────────────────────────────────────
// النصوص والكلمات المفتاحية هنا مطابقة تماماً للسلوك الأصلي لمساعد المستخدم
// قبل هذا التعديل — لا شيء أُزيل أو غُيِّر، فقط نُقل إلى بنية بيانات مشتركة.
final ChatbotRoleConfig individualChatbotConfig = ChatbotRoleConfig(
  role: ChatbotRole.individual,
  welcomeMessage: 'مرحباً بك في مساعد ZAD. كيف يمكنني مساعدتك في التصفح أو الحجز أو التبرع؟',
  defaultChips: const [
    'كيف أحجز عرض؟',
    'أقرب العروض',
    'الفرق بين العروض والباقات',
    'أين حجوزاتي؟',
    'مشكلة في QR',
    'إلغاء الحجز',
    'التواصل مع الإدارة',
  ],
  fallbackMessage:
      'لم أتمكن من تحديد الإجابة بدقة. اختر أحد الأسئلة المقترحة أو تواصل مع الإدارة.',
  intents: [
    ChatbotIntent(
      id: 'reserve_offer',
      exactMatches: const ['كيف أحجز عرض؟'],
      keywords: const ['احجز', 'حجز', 'كيف', 'خطوات', 'طريقه', 'طريقة'],
      reply: () => 'لحجز عرض في زاد، اتبع هذه الخطوات:\n\n'
          '١. انتقل إلى تبويب «تصفح» في الشريط السفلي\n'
          '٢. اختر «العروض» للطعام الواضح، أو «الباقات» للمفاجآت\n'
          '٣. اضغط على العرض الذي يناسبك\n'
          '٤. اختر الكمية ثم اضغط «احجز الآن»\n'
          '٥. اختر طريقة الدفع وأكّد الحجز\n'
          '٦. ستصلك رسالة تأكيد ورمز QR للاستلام',
      replyChips: const ['اذهب إلى العروض', 'اذهب إلى الباقات', 'رجوع للقائمة'],
    ),
    // ── نية غير متزامنة (استعلام موقع + Firestore) — لا رد ثابت هنا؛
    // ChatbotScreen تعترضها عبر kNearestOffersAsync وتستدعي المعالج
    // الأصلي غير المتغيّر _replyNearestOffers() ──
    ChatbotIntent(
      id: 'nearby_offers',
      exactMatches: const ['أقرب العروض'],
      keywords: const ['قريب', 'اقرب', 'قربي', 'منطقتي', 'توصيه', 'بالقرب'],
      navigationActionId: kNearestOffersAsync,
    ),
    ChatbotIntent(
      id: 'browse_offers_vs_packages',
      exactMatches: const ['الفرق بين العروض والباقات'],
      keywords: const ['فرق', 'الفرق', 'غامضه', 'واضح'],
      reply: () => 'الفرق بين العروض والباقات في زاد:\n\n'
          '🍽️ العروض (واضحة المحتوى)\n'
          '• تعرف ماذا ستحصل عليه مسبقاً\n'
          '• سعر مخفّض مقارنةً بالسعر الأصلي\n'
          '• مناسبة إذا كان لديك حساسية غذائية\n\n'
          '🎁 الباقات (غامضة)\n'
          '• مفاجأة! لا تعرف المحتوى قبل الاستلام\n'
          '• سعر خاص جداً\n'
          '• مغامرة لتجربة أطعمة متنوعة',
      replyChips: const ['اذهب إلى العروض', 'اذهب إلى الباقات', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'cancel_reservation',
      exactMatches: const ['أين حجوزاتي؟'],
      keywords: const ['حجوزاتي', 'طلباتي', 'اين', 'اجد', 'متابعه'],
      reply: () => 'يمكنك متابعة حجوزاتك من خلال:\n\n'
          '• تبويب «طلباتي» في الشريط السفلي\n'
          '• ستجد الحجوزات النشطة والمكتملة\n'
          '• يمكنك عرض رمز QR لكل حجز من هناك',
      replyChips: const ['اذهب إلى طلباتي', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'qr_help',
      exactMatches: const ['مشكلة في QR'],
      keywords: const ['qr', 'رمز', 'مشكله', 'لا يعمل', 'خطا'],
      reply: () => 'إذا واجهتك مشكلة في رمز QR:\n\n'
          '١. تأكد من أن الحجز لا يزال بحالة «محجوز»\n'
          '٢. حاول تحديث الصفحة بالسحب للأسفل\n'
          '٣. تحقق من اتصالك بالإنترنت\n'
          '٤. أظهر تفاصيل الحجز للمطعم مباشرة\n'
          '٥. إذا استمرت المشكلة، تواصل مع الإدارة',
      replyChips: const ['أين حجوزاتي؟', 'التواصل مع الإدارة', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'cancel_reservation_guide',
      exactMatches: const ['إلغاء الحجز'],
      keywords: const ['الغاء', 'الغ', 'ارجاع'],
      reply: () => 'لإلغاء حجز في زاد:\n\n'
          '١. انتقل إلى تبويب «طلباتي»\n'
          '٢. اختر الحجز الذي تريد إلغاءه\n'
          '٣. اضغط زر «إلغاء الحجز»\n'
          '٤. أكّد الإلغاء في النافذة الظاهرة\n\n'
          '⚠️ يُسترجع المخزون تلقائياً عند الإلغاء',
      replyChips: const ['اذهب إلى طلباتي', 'رجوع للقائمة'],
    ),
    // ── التواصل مع الإدارة — تُعالَج خاصةً في الشاشة (تدفّق حالة متعدد
    // الخطوات: اختيار فئة المشكلة ثم إنشاء/إعادة استخدام محادثة دعم) ──
    ChatbotIntent(
      id: 'contact_admin',
      exactMatches: const ['التواصل مع الإدارة'],
      keywords: const ['تواصل', 'اداره', 'ادمن', 'مسؤول', 'دعم', 'support'],
      navigationActionId: kNavContactAdmin,
    ),
    // ── أزرار تنقّل مباشرة (بلا رد نصي) ──
    ChatbotIntent(
      id: 'nav_offers',
      exactMatches: const ['اذهب إلى العروض', 'تصفح كل العروض'],
      navigationActionId: kNavOffers,
    ),
    ChatbotIntent(
      id: 'nav_packages',
      exactMatches: const ['اذهب إلى الباقات'],
      navigationActionId: kNavPackages,
    ),
    ChatbotIntent(
      id: 'nav_orders',
      exactMatches: const ['اذهب إلى طلباتي'],
      navigationActionId: kNavOrders,
    ),
  ],
);

// ─── إعداد المطعم (restaurant) ─────────────────────────────────────────────
final ChatbotRoleConfig restaurantChatbotConfig = ChatbotRoleConfig(
  role: ChatbotRole.restaurant,
  welcomeMessage:
      'مرحباً بك في مساعد المطعم. يمكنني مساعدتك في نشر العروض، إدارة الحجوزات، التبرع للجمعيات، ومتابعة التقييمات.',
  defaultChips: const [
    'كيف أنشر عرضاً؟',
    'كيف أنشر باقة غامضة؟',
    'كيف أعدل أو أحذف عرضاً؟',
    'كيف أتابع الحجوزات؟',
    'كيف أؤكد استلام الطلب؟',
    'كيف أستخدم QR؟',
    'لماذا لا يظهر عرضي؟',
    'كيف أحدد موقع الاستلام؟',
    'كيف أضيف معلومات الحساسية؟',
    'كيف أتبرع لجمعية؟',
    'كيف أرى التقييمات؟',
    'كيف أرى الشكاوى؟',
    'كيف أتواصل مع الإدارة؟',
  ],
  fallbackMessage:
      'لم أتمكن من تحديد الإجابة بدقة. اختر سؤالاً يخص إدارة المطعم أو تواصل مع الإدارة.',
  intents: [
    ChatbotIntent(
      id: 'publish_offer',
      exactMatches: const ['كيف أنشر عرضاً؟'],
      keywords: const ['انشر', 'نشر عرض', 'اضافه عرض', 'اضف عرض'],
      reply: () => 'لنشر عرض جديد:\n\n'
          '١. افتح «إدارة العروض»\n'
          '٢. اضغط «إضافة عرض»\n'
          '٣. اختر «عرض واضح» أو «باقة غامضة»\n'
          '٤. أدخل العنوان والوصف والسعر والكمية\n'
          '٥. حدد الموقع ووقت الاستلام\n'
          '٦. أضف معلومات الحساسية إن وُجدت\n'
          '٧. اضغط «نشر»',
      replyChips: const ['إضافة عرض', 'فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'publish_mystery_package',
      exactMatches: const ['كيف أنشر باقة غامضة؟'],
      keywords: const ['باقه غامضه', 'غامضه', 'مفاجاه'],
      reply: () => 'لنشر باقة غامضة (مفاجأة للمستخدم):\n\n'
          '١. افتح «إدارة العروض» ثم «إضافة عرض»\n'
          '٢. اختر نوع الباقة «باقة غامضة المحتوى»\n'
          '٣. لن يُطلَب وصف تفصيلي للمحتوى — يبقى مفاجأة\n'
          '٤. أدخل السعر والكمية، وحدد الموقع ووقت الاستلام\n'
          '٥. اضغط «نشر»\n\n'
          'ملاحظة: الصورة تبقى اختيارية للباقات الغامضة، وتُستخدم صورة '
          'افتراضية إن لم تُضِف صورة.',
      replyChips: const ['إضافة عرض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'edit_offer',
      exactMatches: const ['كيف أعدل أو أحذف عرضاً؟'],
      keywords: const ['عدل', 'تعديل', 'حرر عرض'],
      reply: () => 'لتعديل أو حذف عرض حالي:\n\n'
          '١. افتح «إدارة العروض»\n'
          '٢. اضغط على العرض المطلوب، أو استخدم القائمة (⋮) على بطاقته\n'
          '٣. اختر «تعديل العرض» لتغيير السعر أو الكمية أو الصورة أو أي '
          'تفصيل آخر\n'
          '٤. أو اختر «حذف العرض» لإزالته نهائياً\n\n'
          'ملاحظة: لا يمكن حذف عرض مرتبط بحجز محجوز حالياً أو تم استلامه.',
      replyChips: const ['فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'delete_offer',
      keywords: const ['حذف', 'احذف', 'ازاله عرض'],
      reply: () => 'لحذف عرض: افتح «إدارة العروض»، اضغط القائمة (⋮) على '
          'بطاقة العرض، ثم اختر «حذف العرض».\n\n'
          'ملاحظة: لا يمكن حذف عرض مرتبط بحجز محجوز حالياً أو تم استلامه.',
      replyChips: const ['فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'reservation_management',
      exactMatches: const ['كيف أتابع الحجوزات؟'],
      keywords: const ['حجوزات', 'متابعه الحجوزات', 'الطلبات'],
      reply: () => 'لمتابعة حجوزات عملائك:\n\n'
          '١. افتح «الحجوزات»\n'
          '٢. راقب الحالات: نشطة، بانتظار الاستلام، مكتملة، ملغاة\n'
          '٣. يمكن تأكيد الاستلام مباشرة عبر مسح رمز QR الخاص بالحجز',
      replyChips: const ['فتح الحجوزات', 'فتح ماسح QR', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'pickup_confirmation',
      exactMatches: const ['كيف أؤكد استلام الطلب؟'],
      keywords: const ['تاكيد استلام', 'استلام الطلب', 'تسليم'],
      reply: () => 'لتأكيد استلام طلب من عميل:\n\n'
          '١. افتح ماسح رمز QR\n'
          '٢. وجّه الكاميرا نحو رمز QR الذي يعرضه العميل عند الاستلام\n'
          '٣. يتم تأكيد الحجز تلقائياً عند نجاح المسح، وتنتقل حالته إلى '
          '«مكتملة» في تبويب الحجوزات',
      replyChips: const ['فتح ماسح QR', 'فتح الحجوزات', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'qr_scan',
      exactMatches: const ['كيف أستخدم QR؟'],
      keywords: const ['qr', 'رمز', 'مسح', 'استخدام qr'],
      reply: () => 'ماسح رمز QR يُستخدَم لتأكيد استلام الطلبات:\n\n'
          '١. افتح «ماسح رمز الاستلام»\n'
          '٢. اطلب من العميل إظهار رمز QR الخاص بحجزه\n'
          '٣. وجّه الكاميرا نحوه حتى يُقرأ تلقائياً\n'
          '٤. سترى تأكيداً فورياً عند نجاح المسح',
      replyChips: const ['فتح ماسح QR', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'offer_visibility',
      exactMatches: const ['لماذا لا يظهر عرضي؟'],
      keywords: const ['لا يظهر', 'مايظهر', 'غير ظاهر', 'ما يظهر'],
      reply: () => 'إن لم يظهر عرضك للمستخدمين، تحقق من:\n\n'
          '• الحالة (status): يجب أن تكون «نشط» وليست «مغلق»\n'
          '• الكمية المتبقية: يجب أن تكون أكبر من صفر\n'
          '• تاريخ الانتهاء: يجب ألا يكون قد انتهى\n'
          '• نوع العرض: تأكد من اختيار «عرض واضح» أو «باقة غامضة» بشكل صحيح\n'
          '• فلاتر العرض: بعض المستخدمين يفلترون حسب الفئة أو المسافة\n'
          '• الموقع: تأكد من تحديد موقع الاستلام بدقة\n'
          '• الاتصال بالإنترنت: تأكد من مزامنة التطبيق بعد النشر',
      replyChips: const ['فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'location_help',
      exactMatches: const ['كيف أحدد موقع الاستلام؟'],
      keywords: const ['موقع الاستلام', 'تحديد الموقع', 'الخريطه'],
      reply: () => 'لتحديد موقع الاستلام بدقة عند نشر أو تعديل عرض:\n\n'
          '١. اضغط زر «اختيار الموقع من الخريطة / استخدام موقعي الحالي»\n'
          '٢. اختر «استخدام موقعي الحالي» لتحديد موقعك تلقائياً عبر GPS، أو '
          'حرّك الخريطة لاختيار موقع آخر يدوياً\n'
          '٣. سيُملأ اسم العنوان تلقائياً — يمكنك تعديله يدوياً إن أردت\n'
          '٤. اضغط «تأكيد الموقع»',
      replyChips: const ['فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'allergy_help',
      exactMatches: const ['كيف أضيف معلومات الحساسية؟'],
      keywords: const ['حساسيه', 'مسببات الحساسيه', 'الحساسية الغذائية'],
      reply: () => 'يمكنك إضافة معلومات الحساسية الغذائية عند نشر أو تعديل '
          'عرض:\n\n'
          '١. مرّر لأسفل حتى قسم «معلومات الحساسية الغذائية»\n'
          '٢. حدّد كل مسبب حساسية موجود في الطعام (مثل المكسرات، الألبان، '
          'الغلوتين...)\n'
          '٣. إن لم تتوفر أي مسببات معروفة، اترك الخيار المناسب لذلك\n\n'
          'هذه المعلومات تظهر للمستخدم قبل الحجز لحمايته من أي حساسية.',
      replyChips: const ['فتح إدارة العروض', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'charity_donation',
      exactMatches: const ['كيف أتبرع لجمعية؟'],
      keywords: const ['اتبرع', 'تبرع لجمعيه', 'تبرع بالطعام'],
      reply: () => 'للتبرع بفائض الطعام لجمعية خيرية مباشرة:\n\n'
          '١. افتح اختصار «تبرع لجمعية» من الشاشة الرئيسية\n'
          '٢. اختر الجمعية المستفيدة\n'
          '٣. أدخل تفاصيل الطعام (الاسم، الفئة، الكمية، الوصف)\n'
          '٤. أضف صورة للطعام\n'
          '٥. حدد موقع ووقت الاستلام\n'
          '٦. اضغط «إرسال التبرع»\n\n'
          'ملاحظة: تبرعات المطعم للجمعيات تكون دائماً واضحة المحتوى — لا '
          'يوجد خيار باقة غامضة هنا.',
      replyChips: const ['فتح التبرع لجمعية', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'reviews_history',
      exactMatches: const ['كيف أرى التقييمات؟'],
      keywords: const ['تقييم', 'تقييمات', 'اراء', 'نجوم'],
      reply: () => 'يمكنك مراجعة كل التقييمات التي حصل عليها مطعمك من '
          '«التقييمات والآراء» في صفحة حسابك — تعرض متوسط التقييم والعدد '
          'الإجمالي، بالإضافة إلى تفاصيل كل تقييم على حدة.',
      replyChips: const ['فتح التقييمات', 'رجوع للقائمة'],
    ),
    ChatbotIntent(
      id: 'complaints_history',
      exactMatches: const ['كيف أرى الشكاوى؟'],
      keywords: const ['شكوى', 'شكاوى', 'بلاغ'],
      reply: () => 'يمكنك مراجعة الشكاوى المتعلقة بمطعمك من «سجل الشكاوى» في '
          'صفحة حسابك — تعرض النوع والوصف والحالة، وتفاصيل كل شكوى عند '
          'الضغط عليها. القرار النهائي (حل/رفض) يبقى من صلاحيات الإدارة.',
      replyChips: const ['فتح سجل الشكاوى', 'رجوع للقائمة'],
    ),
    // ── التواصل مع الإدارة — تُعالَج خاصةً في الشاشة، بنفس تدفّق الفرد
    // تماماً، فقط بعبارة الزر ودور المُستخدَم المختلفَين ──
    ChatbotIntent(
      id: 'contact_admin',
      exactMatches: const ['كيف أتواصل مع الإدارة؟'],
      keywords: const ['تواصل', 'ادمن', 'مسؤول', 'دعم', 'support'],
      navigationActionId: kNavContactAdmin,
    ),
    // ── أزرار تنقّل مباشرة (بلا رد نصي) ──
    ChatbotIntent(
      id: 'nav_offers',
      exactMatches: const ['فتح إدارة العروض'],
      navigationActionId: kNavOffers,
    ),
    ChatbotIntent(
      id: 'nav_add_offer',
      exactMatches: const ['إضافة عرض'],
      navigationActionId: kNavAddOffer,
    ),
    ChatbotIntent(
      id: 'nav_reservations',
      exactMatches: const ['فتح الحجوزات'],
      navigationActionId: kNavOrders,
    ),
    ChatbotIntent(
      id: 'nav_scan_qr',
      exactMatches: const ['فتح ماسح QR'],
      navigationActionId: kNavScanQr,
    ),
    ChatbotIntent(
      id: 'nav_donate_to_charity',
      exactMatches: const ['فتح التبرع لجمعية'],
      navigationActionId: kNavDonateToCharity,
    ),
    ChatbotIntent(
      id: 'nav_reviews',
      exactMatches: const ['فتح التقييمات'],
      navigationActionId: kNavReviews,
    ),
    ChatbotIntent(
      id: 'nav_complaints',
      exactMatches: const ['فتح سجل الشكاوى'],
      navigationActionId: kNavComplaints,
    ),
  ],
);

ChatbotRoleConfig configForRole(ChatbotRole role) {
  switch (role) {
    case ChatbotRole.restaurant:
      return restaurantChatbotConfig;
    case ChatbotRole.individual:
      return individualChatbotConfig;
  }
}

/// يُطبّع النص العربي لمطابقة الكلمات المفتاحية (نفس منطق التطبيع الأصلي في
/// مساعد المستخدم قبل هذا التعديل، بلا أي تغيير) ──
String normalizeArabicChat(String text) {
  return text
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}

/// المُحلِّل المشترك للنية — يُستخدَم لكل الأدوار دون خلط بين نيّات دور
/// وآخر: يختار إعداد الدور المطلوب فقط، ثم يطابق ضمن نياته حصراً.
///
/// الأولوية: تطابق تام مع أحد أزرار (chips) هذا الدور أولاً، ثم مطابقة
/// كلمات مفتاحية على النص المُطبَّع. يُعيد null إن لم يوجد أي تطابق، لتعرض
/// ChatbotScreen عندها رسالة الفشل الخاصة بالدور مع الأسئلة المقترحة من جديد.
ChatbotResponse? resolveIntent({
  required ChatbotRole role,
  required String message,
}) {
  final config = configForRole(role);

  for (final intent in config.intents) {
    if (intent.exactMatches.contains(message)) {
      return _responseFor(intent);
    }
  }

  final normalized = normalizeArabicChat(message);
  for (final intent in config.intents) {
    if (intent.keywords.any((k) => normalized.contains(k))) {
      return _responseFor(intent);
    }
  }

  return null;
}

ChatbotResponse _responseFor(ChatbotIntent intent) {
  if (intent.navigationActionId != null) {
    return ChatbotResponse.navigate(intent.navigationActionId!);
  }
  return ChatbotResponse.reply(
    text: intent.reply?.call() ?? '',
    chips: intent.replyChips,
  );
}
