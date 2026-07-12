import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/support_service.dart';
import '../../theme/app_colors.dart';
import '../restaurant/restaurant_complaints_history_screen.dart';
import '../restaurant/restaurant_donate_to_charity_screen.dart';
import '../restaurant/restaurant_reviews_screen.dart';
import '../restaurant/scan_qr_screen.dart';
import 'chatbot_role_config.dart';
import 'support_chat_screen.dart';
import 'user_support_list_screen.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> chips;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.chips = const [],
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

/// مساعد زاد — شاشة واحدة مشتركة بين كل الأدوار (فرد/مطعم، وقابلة للتوسّع
/// لاحقاً بجمعية)، تُحدَّد محتوياتها (رسالة الترحيب، الأسئلة المقترحة،
/// الردود، رسالة الفشل) بالكامل من [ChatbotRoleConfig] حسب [userRole] —
/// لا يوجد أي فرع "if role == restaurant" داخل build() نفسها. التنقّل
/// الفعلي (تبديل تبويب في اللوحة الأم، أو فتح شاشة مباشرة) يبقى هنا فقط،
/// عبر خرائط استدعاءات (callbacks) يُمرّرها كل Dashboard حسب دوره.
class ChatbotScreen extends StatefulWidget {
  // ── الدور — يُفضَّل تمريره صراحةً من الشاشة الأم (لا حاجة لأي قراءة
  // إضافية من Firestore هنا). أي قيمة غير معروفة تُعامَل كفرد (individual) ──
  final String userRole;

  // ── تنقّل مشترك بين الأدوار (نفس المعنى وإن اختلفت التسمية المعروضة) ──
  final VoidCallback? onGoToOffers; // "عروضي" (مطعم) أو "العروض" (فرد)
  final VoidCallback? onGoToOrders; // "حجوزاتي" (مطعم) أو "طلباتي" (فرد)
  final VoidCallback? onGoToNotifications; // مشتركة — كل لوحة تفتح شاشتها الخاصة

  // ── خاصة بالفرد ──
  final VoidCallback? onGoToPackages;
  final VoidCallback? onGoToDonate;

  // ── خاصة بالمطعم ──
  final VoidCallback? onGoToAddOffer;

  // Null when user is anonymous — disables contact-admin flow
  final String? userId;
  final String? userName;

  const ChatbotScreen({
    super.key,
    this.userRole = 'individual',
    this.onGoToOffers,
    this.onGoToOrders,
    this.onGoToNotifications,
    this.onGoToPackages,
    this.onGoToDonate,
    this.onGoToAddOffer,
    this.userId,
    this.userName,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_ChatMessage> _messages = [];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  bool _isTyping = false;

  // Contact-admin flow state
  bool _awaitingIssueCategory = false;
  String? _lastCreatedChatId;

  late final ChatbotRole _role;
  late final ChatbotRoleConfig _config;

  static const List<String> _issueCategories = [
    'مشكلة في الحجز',
    'مشكلة في QR',
    'لم أستلم إشعار',
    'مشكلة في الدفع',
    'عرض غير ظاهر',
    'مشكلة أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _role = chatbotRoleFromString(widget.userRole);
    _config = configForRole(_role);
    _addBotMessage(_config.welcomeMessage, chips: _config.defaultChips);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ─── Message helpers ──────────────────────────────────────────────────────

  void _addBotMessage(String text, {List<String> chips = const []}) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, chips: chips));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Input handling ───────────────────────────────────────────────────────

  Future<void> _handleInput(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _addUserMessage(text);
    await _processIntent(text);
  }

  Future<void> _processIntent(String text) async {
    // ── Contact-admin sub-flow: waiting for issue category (مشتركة) ────────
    if (_awaitingIssueCategory) {
      await _handleIssueCategorySelected(text);
      return;
    }

    // ── أزرار/إجراءات مشتركة بين كل الأدوار، خارج نطاق ChatbotRoleConfig
    // لأنها تدفّقات حالة (state) وليست ردوداً نصية ثابتة ──
    if (text == 'رجوع للقائمة') {
      setState(() => _awaitingIssueCategory = false);
      _addBotMessage('ما الذي تودّ الاستفسار عنه؟', chips: _config.defaultChips);
      return;
    }
    if (text == 'فتح المحادثة' && _lastCreatedChatId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(chatId: _lastCreatedChatId!),
        ),
      );
      return;
    }
    if (text == 'عرض محادثاتي') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserSupportListScreen()),
      );
      return;
    }

    // ── المُحلِّل المشترك — يطابق ضمن نيّات هذا الدور فقط، بلا خلط مع
    // الدور الآخر (Part 10) ──
    final response = resolveIntent(role: _role, message: text);

    if (response != null && response.navigationActionId != null) {
      await _dispatchNavigation(response.navigationActionId!);
      return;
    }
    if (response != null && response.text != null) {
      _addBotMessage(response.text!, chips: response.chips);
      return;
    }

    // ── لم يُطابَق أي شيء — رسالة الفشل الخاصة بالدور مع الأسئلة المقترحة
    // من جديد (Part 11) ──
    _addBotMessage(_config.fallbackMessage, chips: _config.defaultChips);
  }

  // ─── Navigation dispatch ────────────────────────────────────────────────
  //
  // يُنفَّذ التنقّل الفعلي هنا فقط (وليس داخل chatbot_role_config.dart، التي
  // لا تعرف شيئاً عن BuildContext أو Navigator). الإجراءات المشتركة بين
  // الأدوار (offers/orders/notifications) تستخدم استدعاءات اللوحة الأم؛
  // الشاشات الثابتة الخاصة بالمطعم (QR/التبرع لجمعية/التقييمات/الشكاوى)
  // تُفتَح مباشرة هنا لأنها نفس الوجهة دائماً بصرف النظر عن اللوحة الأم،
  // فلا داعي لتمرير 4 استدعاءات إضافية عبر كل Dashboard لمجرّد فتحها.

  Future<void> _dispatchNavigation(String actionId) async {
    switch (actionId) {
      case kNavContactAdmin:
        _replyContactAdmin();
        return;
      case kNearestOffersAsync:
        await _replyNearestOffers();
        return;
      case kNavOffers:
        _popThenCall(widget.onGoToOffers);
        return;
      case kNavPackages:
        _popThenCall(widget.onGoToPackages);
        return;
      case kNavOrders:
        _popThenCall(widget.onGoToOrders);
        return;
      case kNavDonate:
        _popThenCall(widget.onGoToDonate);
        return;
      case kNavAddOffer:
        _popThenCall(widget.onGoToAddOffer);
        return;
      case kNavNotifications:
        _popThenCall(widget.onGoToNotifications);
        return;
      case kNavScanQr:
        _pushDirect(const ScanQrScreen());
        return;
      case kNavDonateToCharity:
        _pushDirect(const RestaurantDonateToCharityScreen());
        return;
      case kNavReviews:
        _pushDirect(const RestaurantReviewsScreen());
        return;
      case kNavComplaints:
        _pushDirect(const RestaurantComplaintsHistoryScreen());
        return;
    }
  }

  /// يُغلق شاشة المساعد ثم يستدعي استدعاء اللوحة الأم (لتبديل تبويب مثلاً)؛
  /// إن كان الاستدعاء غير مُمرَّر (null) — لا شيء يحدث بعد الإغلاق.
  void _popThenCall(VoidCallback? callback) {
    Navigator.pop(context);
    callback?.call();
  }

  /// يفتح شاشة ثابتة مباشرة فوق نفس Navigator الذي تعيش عليه شاشة المساعد
  /// نفسها (بدل إغلاقها أولاً) — نفس نمط فتح المحادثات (فتح المحادثة/عرض
  /// محادثاتي) أعلاه.
  void _pushDirect(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ─── نية غير متزامنة خاصة بالفرد: أقرب العروض (Firestore + GPS) ──────────
  // منسوخة دون أي تغيير عن السلوك الأصلي لمساعد المستخدم ──

  Future<void> _replyNearestOffers() async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    final position = await LocationService().getCurrentLocation();
    if (!mounted) return;

    if (position == null) {
      setState(() => _isTyping = false);
      _addBotMessage(
        'تعذّر تحديد موقعك الجغرافي. يرجى:\n'
        '• تفعيل خدمة الموقع (GPS) على الجهاز\n'
        '• منح التطبيق إذن الوصول للموقع\n\n'
        'يمكنك تصفح جميع العروض يدوياً.',
        chips: const ['تصفح كل العروض', 'رجوع للقائمة'],
      );
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('offers')
          .where('status', isEqualTo: 'available')
          .limit(30)
          .get();

      if (!mounted) return;

      final svc = LocationService();
      final list = <({String name, double dist, num price})>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final dist = svc.distanceKm(
          lat1: position.latitude,
          lon1: position.longitude,
          lat2: lat,
          lon2: lon,
        );

        final restaurantName =
            (data['restaurantName'] as String? ?? '').trim();
        final title = (data['title'] as String? ?? '').trim();
        final name = restaurantName.isNotEmpty
            ? restaurantName
            : (title.isNotEmpty ? title : 'عرض');
        final price = (data['price'] as num?) ?? 0;

        list.add((name: name, dist: dist, price: price));
      }

      list.sort((a, b) => a.dist.compareTo(b.dist));
      final top = list.take(3).toList();

      setState(() => _isTyping = false);

      if (top.isEmpty) {
        _addBotMessage(
          'لا توجد عروض متاحة قريبة منك حالياً.\nيمكنك تصفح جميع العروض.',
          chips: const ['تصفح كل العروض', 'رجوع للقائمة'],
        );
        return;
      }

      final sb = StringBuffer('أقرب العروض المتاحة إليك:\n\n');
      for (final item in top) {
        sb.write('📍 ${item.name}\n');
        sb.write(
          'السعر: ${item.price} ₪  •  ${svc.formatDistance(item.dist)}\n\n',
        );
      }

      _addBotMessage(
        sb.toString().trim(),
        chips: const ['تصفح كل العروض', 'رجوع للقائمة'],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _addBotMessage(
        'حدث خطأ أثناء جلب العروض. يرجى المحاولة مجدداً.',
        chips: _config.defaultChips,
      );
    }
  }

  // ─── Contact-admin flow (مشتركة بين كل الأدوار) ──────────────────────────
  //
  // نفس التدفّق الأصلي تماماً، مع فرقين فقط: userRole يُمرَّر للخدمة كما هو
  // (بدل 'user' الثابتة)، ويُتحقَّق أولاً من وجود محادثة مفتوحة لنفس
  // المستخدم لتفادي إنشاء أكثر من محادثة مفتوحة واحدة (Part 9).

  void _replyContactAdmin() {
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    final hasUserId = widget.userId != null && widget.userId!.isNotEmpty;

    if (isAnonymous || !hasUserId) {
      _addBotMessage(
        'يجب تسجيل الدخول بحساب حقيقي للتواصل مع الإدارة.',
        chips: _config.defaultChips,
      );
      return;
    }

    setState(() => _awaitingIssueCategory = true);
    _addBotMessage(
      'يسعدنا مساعدتك 😊\nالرجاء اختيار نوع المشكلة:',
      chips: [..._issueCategories, 'رجوع للقائمة'],
    );
  }

  Future<void> _handleIssueCategorySelected(String category) async {
    setState(() {
      _awaitingIssueCategory = false;
      _isTyping = true;
    });

    try {
      // ── تفادي محادثة مفتوحة مكرّرة لنفس المستخدم (Part 9) ──
      final existingChatId =
          await SupportService().findOpenChatId(widget.userId!);
      if (!mounted) return;

      if (existingChatId != null) {
        setState(() {
          _isTyping = false;
          _lastCreatedChatId = existingChatId;
        });
        _addBotMessage(
          'لديك محادثة دعم مفتوحة بالفعل، سيتم متابعتها بدلاً من إنشاء '
          'محادثة جديدة.',
          chips: const ['فتح المحادثة', 'عرض محادثاتي', 'رجوع للقائمة'],
        );
        return;
      }

      final chatId = await SupportService().createSupportChat(
        userId: widget.userId!,
        userName: widget.userName ?? 'مستخدم',
        userRole: widget.userRole,
        userEmail: FirebaseAuth.instance.currentUser?.email,
        issueCategory: category,
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _lastCreatedChatId = chatId;
      });
      _addBotMessage(
        'تم استلام طلبك بنجاح ✅\n'
        'سيتم التواصل معك من قبل الإدارة في أقرب وقت ممكن.\n\n'
        'جميع المسؤولين مشغولون حالياً.\n'
        'تم تسجيل طلبك وسيتم التواصل معك لاحقاً.',
        chips: const ['فتح المحادثة', 'عرض محادثاتي', 'رجوع للقائمة'],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _addBotMessage(
        'حدث خطأ أثناء إنشاء الطلب. يرجى المحاولة مجدداً.',
        chips: _config.defaultChips,
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _role == ChatbotRole.restaurant ? 'مساعد المطعم' : 'مساعد زاد',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Text(
                  'متصل',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'محادثاتي',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserSupportListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _MessageBubble(
                message: _messages[i],
                onChipTap: _handleInput,
              ),
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypingIndicator(),
              ),
            ),
          _InputBar(
            controller: _textController,
            onSend: _handleInput,
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<String> onChipTap;

  const _MessageBubble({required this.message, required this.onChipTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textDark,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          if (message.chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: message.chips
                  .map(
                    (chip) => _QuickChip(
                      label: chip,
                      onTap: () => onChipTap(chip),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Quick reply chip ─────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(),
          SizedBox(width: 4),
          _Dot(),
          SizedBox(width: 4),
          _Dot(),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.textLight.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك هنا...',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
