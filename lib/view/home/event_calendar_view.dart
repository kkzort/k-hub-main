import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/style/app_colors.dart';

class EventCalendarView extends StatelessWidget {
  final Color kPrimaryColor;

  const EventCalendarView({super.key, required this.kPrimaryColor});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih belirtilmemis';
    return DateFormat('dd MMMM yyyy, HH:mm', 'tr').format(timestamp.toDate());
  }

  String _formatDay(Timestamp? timestamp) {
    if (timestamp == null) return '--';
    return DateFormat('dd', 'tr').format(timestamp.toDate());
  }

  String _formatMonth(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('MMM', 'tr').format(timestamp.toDate()).toUpperCase();
  }

  String _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value == null ? '' : value.toString().trim();
  }

  Timestamp? _timestampValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is Timestamp ? value : null;
  }

  bool _boolValue(
    Map<String, dynamic> data,
    String key, {
    bool fallback = false,
  }) {
    final value = data[key];
    if (value is bool) return value;
    return fallback;
  }

  String _registrationDocId(String eventId, String userId) {
    return '${eventId}_$userId';
  }

  bool _isPast(Timestamp? timestamp) {
    if (timestamp == null) return false;
    return timestamp.toDate().isBefore(DateTime.now());
  }

  bool _isToday(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final date = timestamp.toDate();
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _discountNote(Map<String, dynamic> data) {
    final custom = _stringValue(data, 'preRegistrationDiscountNote');
    if (custom.isNotEmpty) return custom;
    return 'Ön kayıt yaptıran öğrenciler etkinlik girişinde öğrenci indirimi ve öncelikli bilgilendirme avantajından yararlanır.';
  }

  Future<void> _registerForEvent(
    BuildContext context, {
    required String eventId,
    required Map<String, dynamic> eventData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ön kayıt için önce giriş yapman gerekiyor.'),
        ),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data();
    final nick = userData?['nick']?.toString().trim() ?? '';
    final name = userData?['name']?.toString().trim() ?? '';
    final displayName = user.displayName?.trim() ?? '';
    final userName = nick.isNotEmpty
        ? nick
        : name.isNotEmpty
        ? name
        : displayName.isNotEmpty
        ? displayName
        : (user.email?.split('@').first ?? 'Kullanıcı');

    await FirebaseFirestore.instance
        .collection('event_preregistrations')
        .doc(_registrationDocId(eventId, user.uid))
        .set({
          'eventId': eventId,
          'eventTitle': _stringValue(eventData, 'title'),
          'eventLocation': _stringValue(eventData, 'location'),
          'eventImageUrl': _stringValue(eventData, 'imageUrl'),
          'eventDate': _timestampValue(eventData, 'eventDate'),
          'discountNote': _discountNote(eventData),
          'userId': user.uid,
          'userName': userName,
          'userEmail': user.email ?? '',
          'status': 'pre_registered',
          'registeredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_stringValue(eventData, 'title').isNotEmpty ? _stringValue(eventData, 'title') : 'Etkinlik'} için ön kaydın alındı.',
        ),
      ),
    );
  }

  Future<void> _showEventDetail(
    BuildContext context, {
    required String eventId,
    required Map<String, dynamic> eventData,
  }) async {
    final imageUrl = _stringValue(eventData, 'imageUrl');
    final title = _stringValue(eventData, 'title');
    final description = _stringValue(eventData, 'description');
    final location = _stringValue(eventData, 'location');
    final eventDate = _timestampValue(eventData, 'eventDate');
    final canPreRegister =
        !_isPast(eventDate) &&
        _boolValue(eventData, 'preRegistrationEnabled', fallback: true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 14, bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EventVisual(
                          imageUrl: imageUrl,
                          height: 240,
                          title: title,
                          accentColor: kPrimaryColor,
                        ),
                        const SizedBox(height: 18),
                        if (_isToday(eventDate))
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'BUGÜN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Text(
                          title.isNotEmpty ? title : 'Etkinlik',
                          style: TextStyle(
                            color: AppColors.textHeader,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailInfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Tarih',
                          value: _formatDate(eventDate),
                          color: kPrimaryColor,
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _DetailInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Konum',
                            value: location,
                            color: Colors.orange,
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          description.isNotEmpty
                              ? description
                              : 'Bu etkinlik için henüz detaylı bir açıklama eklenmemiş.',
                          style: TextStyle(
                            color: AppColors.textBody,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                        if (canPreRegister) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_offer_outlined,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ön kayıt ve öğrenci indirimi',
                                      style: TextStyle(
                                        color: AppColors.textHeader,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _discountNote(eventData),
                                  style: TextStyle(
                                    color: AppColors.textBody,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: canPreRegister
                        ? _EventRegistrationButton(
                            eventId: eventId,
                            eventData: eventData,
                            registrationDocIdBuilder: _registrationDocId,
                            color: kPrimaryColor,
                            onRegister: () async {
                              await _registerForEvent(
                                context,
                                eventId: eventId,
                                eventData: eventData,
                              );
                            },
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text(
                                _isPast(eventDate)
                                    ? 'Etkinlik tamamlandı'
                                    : 'Ön kayıt kapalı',
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Etkinlik Takvimi'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.calendar_month, color: Colors.white70, size: 36),
                SizedBox(height: 8),
                Text(
                  'Yaklaşan Etkinlikler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Görselli etkinlik kartlarına dokunup detayları inceleyin',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .orderBy('eventDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return const _ErrorState(
                    message:
                        'Etkinlikler yüklenirken bir sorun oldu. Lütfen tekrar dene.',
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final eventId = docs[index].id;
                    final raw = docs[index].data();
                    final data = raw is Map<String, dynamic>
                        ? raw
                        : <String, dynamic>{};
                    final title = _stringValue(data, 'title');
                    final description = _stringValue(data, 'description');
                    final location = _stringValue(data, 'location');
                    final imageUrl = _stringValue(data, 'imageUrl');
                    final eventDate = _timestampValue(data, 'eventDate');
                    final preRegistrationEnabled = _boolValue(
                      data,
                      'preRegistrationEnabled',
                      fallback: true,
                    );
                    final isPast = _isPast(eventDate);
                    final isToday = _isToday(eventDate);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            _showEventDetail(
                              context,
                              eventId: eventId,
                              eventData: data,
                            );
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: isToday
                                  ? Border.all(color: kPrimaryColor, width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: isPast
                                      ? Colors.black.withValues(alpha: 0.03)
                                      : kPrimaryColor.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    _EventVisual(
                                      imageUrl: imageUrl,
                                      height: 200,
                                      title: title,
                                      accentColor: kPrimaryColor,
                                      topRadius: 24,
                                    ),
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      child: Container(
                                        width: 62,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              _formatDay(eventDate),
                                              style: TextStyle(
                                                color: AppColors.textHeader,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              _formatMonth(eventDate),
                                              style: TextStyle(
                                                color: kPrimaryColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isToday)
                                      Positioned(
                                        top: 14,
                                        right: 14,
                                        child: _BadgeChip(
                                          label: 'BUGUN',
                                          color: kPrimaryColor,
                                          textColor: Colors.white,
                                        ),
                                      )
                                    else if (isPast)
                                      const Positioned(
                                        top: 14,
                                        right: 14,
                                        child: _BadgeChip(
                                          label: 'GEÇTİ',
                                          color: Colors.black54,
                                          textColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title.isNotEmpty ? title : 'Etkinlik',
                                        style: TextStyle(
                                          color: AppColors.textHeader,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        description.isNotEmpty
                                            ? description
                                            : 'Detayları görmek için karta dokun.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textBody,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MetaChip(
                                            icon: Icons.access_time_rounded,
                                            label: _formatDate(eventDate),
                                            color: kPrimaryColor,
                                          ),
                                          if (location.isNotEmpty)
                                            _MetaChip(
                                              icon: Icons.location_on_outlined,
                                              label: location,
                                              color: Colors.orange,
                                            ),
                                          if (!isPast && preRegistrationEnabled)
                                            const _MetaChip(
                                              icon: Icons.local_offer_outlined,
                                              label: 'Ön kayıt ve indirim',
                                              color: Colors.orange,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Text(
                                            'Detayları görmek için dokun',
                                            style: TextStyle(
                                              color: AppColors.textTertiary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: kPrimaryColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRegistrationButton extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  final String Function(String eventId, String userId) registrationDocIdBuilder;
  final Color color;
  final Future<void> Function() onRegister;

  const _EventRegistrationButton({
    required this.eventId,
    required this.eventData,
    required this.registrationDocIdBuilder,
    required this.color,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ön kayıt için önce giriş yapman gerekiyor.'),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Ön kayıt yaptır',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('event_preregistrations')
          .doc(registrationDocIdBuilder(eventId, user.uid))
          .snapshots(),
      builder: (context, snapshot) {
        final alreadyRegistered = snapshot.data?.exists == true;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: alreadyRegistered ? null : onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyRegistered ? Colors.green : color,
              disabledBackgroundColor: Colors.green,
              disabledForegroundColor: Colors.white,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: Icon(
              alreadyRegistered
                  ? Icons.check_circle_rounded
                  : Icons.app_registration_rounded,
            ),
            label: Text(
              alreadyRegistered ? 'Ön kayıt yapıldı' : 'Ön kayıt yaptır',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}

class _EventVisual extends StatelessWidget {
  final String imageUrl;
  final double height;
  final String title;
  final Color accentColor;
  final double topRadius;

  const _EventVisual({
    required this.imageUrl,
    required this.height,
    required this.title,
    required this.accentColor,
    this.topRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(topRadius));

    if (imageUrl.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.95),
              const Color(0xFF0F274A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  title.isNotEmpty ? title : 'Etkinlik',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: accentColor.withValues(alpha: 0.16),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: accentColor,
                    size: 42,
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _BadgeChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textHeader,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Henüz etkinlik eklenmemiş',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
        ),
      ),
    );
  }
}
