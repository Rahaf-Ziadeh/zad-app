import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/widgets/charity_widgets.dart';

import '../../services/charity_reservations_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';

class CharityReservationsScreen extends StatefulWidget {
  // يستخدم فقط لتحديد التبويب الأول
  final String? statusFilter;

  const CharityReservationsScreen({
    super.key,
    this.statusFilter,
  });

  @override
  State<CharityReservationsScreen> createState() =>
      _CharityReservationsScreenState();
}

class _CharityReservationsScreenState extends State<CharityReservationsScreen>
    with SingleTickerProviderStateMixin {
  final CharityReservationsService _reservationsService =
      CharityReservationsService();

  late final TabController _tabController;

  // null = الكل
  static const List<String?> _statuses = [
    null,
    'reserved',
    'picked_up',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();

    final initialIndex = _statuses.indexOf(
      widget.statusFilter,
    );

    _tabController = TabController(
      length: _statuses.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabLabel(String? status) {
    switch (status) {
      case 'reserved':
        return 'بانتظار الاستلام';

      case 'picked_up':
        return 'تم الاستلام';

      case 'cancelled':
        return 'ملغي';

      default:
        return 'الكل';
    }
  }

  Future<void> _cancelReservation({
    required String reservationId,
    required String offerId,
  }) async {
    try {
      await _reservationsService.cancelReservation(
        reservationId: reservationId,
        offerId: offerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء الحجز بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reservationsService.cancelErrorMessage(error),
          ),
        ),
      );
    }
  }

  Future<void> _confirmCancel({
    required String reservationId,
    required String offerId,
  }) async {
    final confirmed = await showCancelReservationDialog(
      context: context,
    );

    if (!confirmed || !mounted) return;

    await _cancelReservation(
      reservationId: reservationId,
      offerId: offerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: _statuses
              .map(
                (status) => Tab(
                  text: _tabLabel(status),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map(_buildReservationsList).toList(),
      ),
    );
  }

  Widget _buildReservationsList(
    String? status,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _reservationsService.watchReservations(
        status: status,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[CharityReservationsScreen] '
            'stream error: ${snapshot.error}',
          );

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final reservations = snapshot.data!.docs;

        if (reservations.isEmpty) {
          return EmptyCharityReservations(
            statusFilter: status,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final document = reservations[index];

            final data = document.data() as Map<String, dynamic>;

            final reservationId = document.id;

            final offerId = data['offerId'] ?? '';

            return CharityReservationCard(
              reservationId: reservationId,
              data: data,
              currentUserId: _reservationsService.currentUserId,
              onCancel: () {
                _confirmCancel(
                  reservationId: reservationId,
                  offerId: offerId,
                );
              },
            );
          },
        );
      },
    );
  }
}
