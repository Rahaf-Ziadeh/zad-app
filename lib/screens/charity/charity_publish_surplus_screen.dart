import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/charity_data_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';
import 'charity_publish_new_surplus_screen.dart';

class CharityPublishSurplusScreen extends StatelessWidget {
  const CharityPublishSurplusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إعادة توزيع الفائض'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'فائض متاح للنشر'),
              Tab(text: 'تم نشره'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AvailableSurplusTab(),
            PublishedSurplusTab(),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PublishNewSurplusScreen(),
              ),
            );
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(
            Icons.add_rounded,
            color: Colors.white,
          ),
          label: const Text(
            'نشر عرض جديد',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class AvailableSurplusTab extends StatelessWidget {
  const AvailableSurplusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = CharityDataService();

    return StreamBuilder<QuerySnapshot>(
      // Only donations the charity has confirmed receiving (status='received') appear here.
      stream: dataService.watchReceivedDonations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[Surplus][Available] ${snapshot.error}',
          );

          return const Center(
            child: Text(
              'تعذر تحميل التبرعات.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final documents = dataService.filterDonationsForCurrentCharity(
          snapshot.data!.docs,
        );

        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.primary.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'لا يوجد فائض جاهز للنشر',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اقبلي التبرعات وأكدي استلامها أولاً لتظهر هنا',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];

            final data = document.data() as Map<String, dynamic>;

            return SurplusCard(
              donationId: document.id,
              data: data,
              isPublished: false,
            );
          },
        );
      },
    );
  }
}

class PublishedSurplusTab extends StatelessWidget {
  const PublishedSurplusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = CharityDataService();

    return StreamBuilder<QuerySnapshot>(
      stream: dataService.watchPublishedCharityOffers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[Surplus][Published] ${snapshot.error}',
          );

          return const Center(
            child: Text(
              'تعذر تحميل العروض المنشورة.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final documents = snapshot.data!.docs;

        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share_outlined,
                  size: 64,
                  color: AppColors.primary.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'لم تنشري أي عرض بعد',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];

            final data = document.data() as Map<String, dynamic>;

            return PublishedOfferCard(
              offerId: document.id,
              data: data,
            );
          },
        );
      },
    );
  }
}
