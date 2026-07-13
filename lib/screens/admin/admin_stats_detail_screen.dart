import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/utils/phone_formatter.dart';
import '../../theme/app_colors.dart';

// One field definition for a stats card row.
class AdminFieldDef {
  final IconData icon;
  final String label;
  final String key;
  final String fallback;
  final bool isPhone;

  const AdminFieldDef({
    required this.icon,
    required this.label,
    required this.key,
    this.fallback = '—',
    this.isPhone = false,
  });
}

// Generic reusable list screen for admin stats items.
class AdminStatsDetailScreen extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final Stream<QuerySnapshot> stream;
  final Color accentColor;

  /// Doc field key used as the card's primary title.
  final String titleKey;

  /// Optional secondary key shown directly below the title.
  final String? subtitleKey;

  /// Detail field rows displayed inside each card.
  final List<AdminFieldDef> fields;

  const AdminStatsDetailScreen({
    super.key,
    required this.title,
    required this.stream,
    required this.titleKey,
    this.subtitleKey,
    this.fields = const [],
    this.emptyMessage = 'لا توجد سجلات حالياً',
    this.accentColor = AppColors.primary,
  });

  // Safe conversion of any Firestore value to a readable string.
  String _display(dynamic raw, String fallback) {
    if (raw == null) return fallback;
    if (raw is Timestamp) {
      final dt = raw.toDate().toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y  $h:$min';
    }
    final s = raw.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 52, color: AppColors.danger),
                    const SizedBox(height: 12),
                    const Text('حدث خطأ أثناء التحميل',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          // Client-side newest-first sort; callers don't add orderBy to the stream query.
          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
            ..sort((a, b) {
              final aRaw =
                  (a.data() as Map<String, dynamic>)['createdAt'];
              final bRaw =
                  (b.data() as Map<String, dynamic>)['createdAt'];
              final aTs = aRaw is Timestamp ? aRaw : null;
              final bTs = bRaw is Timestamp ? bRaw : null;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 64,
                        color: accentColor.withValues(alpha: 0.25)),
                    const SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ستظهر السجلات هنا فور إضافتها',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              try {
                final doc = docs[i];
                final d = doc.data() as Map<String, dynamic>;
                final titleVal = _display(d[titleKey], '—');
                final subtitleVal =
                    subtitleKey != null ? _display(d[subtitleKey!], '') : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  accentColor.withValues(alpha: 0.12),
                              child: Text(
                                titleVal.isNotEmpty
                                    ? titleVal[0].toUpperCase()
                                    : '؟',
                                style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleVal,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textDark),
                                  ),
                                  if (subtitleVal != null &&
                                      subtitleVal.isNotEmpty)
                                    Text(
                                      subtitleVal,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (fields.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 10),
                          for (final f in fields) ...[
                            _FieldRow(
                              icon: f.icon,
                              label: f.label,
                              value: _display(d[f.key], f.fallback),
                              isPhone: f.isPhone,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPhone;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(fontSize: 12, color: AppColors.textDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textLight),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: isPhone
                ? PhoneText(value, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
