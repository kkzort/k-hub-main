import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/style/app_colors.dart';

class AdminEventPreRegistrationsView extends StatelessWidget {
  const AdminEventPreRegistrationsView({super.key});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih belirtilmemis';
    return DateFormat('dd.MM.yyyy HH:mm', 'tr').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'On Kayitlar',
          style: TextStyle(color: AppColors.textHeader),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('event_preregistrations')
            .orderBy('registeredAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.how_to_reg_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henuz on kayit yok.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final eventTitle =
                data['eventTitle']?.toString().trim().isNotEmpty == true
                ? data['eventTitle'].toString().trim()
                : 'Etkinlik';
            grouped.putIfAbsent(eventTitle, () => []).add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'On kayit yaptiran ogrenciler burada etkinlige gore gruplanir. Her kayitta kullanici adi, maili ve kayit zamani gorunur.',
                  style: TextStyle(color: AppColors.textBody, height: 1.45),
                ),
              ),
              ...grouped.entries.map((entry) {
                final registrations = entry.value;
                final firstData =
                    registrations.first.data() as Map<String, dynamic>;
                final eventDate = firstData['eventDate'] as Timestamp?;
                final location = firstData['eventLocation']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${registrations.length} on kayit • ${_formatDate(eventDate)}${location.isNotEmpty ? ' • $location' : ''}',
                      style: TextStyle(color: AppColors.textBody),
                    ),
                    children: registrations.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userName =
                          data['userName']?.toString() ?? 'Kullanici';
                      final userEmail = data['userEmail']?.toString() ?? '';
                      final registeredAt = data['registeredAt'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                userName.trim().isNotEmpty
                                    ? userName
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      color: AppColors.textHeader,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (userEmail.isNotEmpty)
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        color: AppColors.textBody,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Kayit zamani: ${_formatDate(registeredAt)}',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
