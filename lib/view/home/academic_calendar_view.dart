import 'package:flutter/material.dart';
import '../../core/style/app_colors.dart';


// =============================================
// AKADEMİK TAKVİM MODELİ
// =============================================
class CalendarEvent {
  final String dateRange;
  final String title;
  final CalendarEventType type;

  const CalendarEvent({
    required this.dateRange,
    required this.title,
    required this.type,
  });
}

enum CalendarEventType {
  semester,   // Yarıyıl başlangıç/bitiş
  exam,       // Sınav
  registration, // Kayıt
  addDrop,    // Ders ekle/bırak
  internship, // Staj
  other,
}

class SemesterSection {
  final String title;
  final String dateRange;
  final List<CalendarEvent> events;

  const SemesterSection({
    required this.title,
    required this.dateRange,
    required this.events,
  });
}

class FacultyCalendar {
  final String name;
  final String shortName;
  final IconData icon;
  final List<SemesterSection> semesters;

  const FacultyCalendar({
    required this.name,
    required this.shortName,
    required this.icon,
    required this.semesters,
  });
}

// =============================================
// TAKVİM VERİLERİ
// =============================================
final List<FacultyCalendar> academicCalendars = [
  // ── GENEL (Tıp ve Diş Hekimliği Hariç) ──
  FacultyCalendar(
    name: 'Önlisans / Lisans / Lisansüstü',
    shortName: 'Genel',
    icon: Icons.school_rounded,
    semesters: [
      SemesterSection(
        title: 'GÜZ YARIYILI',
        dateRange: '15 Eylül 2025 – 26 Aralık 2025',
        events: [
          CalendarEvent(
            dateRange: '01 – 05 Eylül 2025',
            title: 'Ön Lisans-Lisans Yaz Okulu / Staj Sonrası Tek Ders Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '08 – 12 Eylül 2025',
            title: 'Ders Kayıt Yenileme ve Katkı Payı Ödemeleri',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '15 Eylül 2025',
            title: 'Derslerin Başlaması',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '22 – 26 Eylül 2025',
            title: 'Ders Ekle / Bırak İşlemleri',
            type: CalendarEventType.addDrop,
          ),
          CalendarEvent(
            dateRange: '26 Aralık 2025',
            title: 'Derslerin Sona Ermesi',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '05 – 16 Ocak 2026',
            title: 'Yarıyıl Sonu Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '26 – 30 Ocak 2026',
            title: 'Bütünleme Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '11 – 13 Şubat 2026',
            title: 'Tek Ders Sınavları',
            type: CalendarEventType.exam,
          ),
        ],
      ),
      SemesterSection(
        title: 'BAHAR YARIYILI',
        dateRange: '16 Şubat 2026 – 10 Haziran 2026',
        events: [
          CalendarEvent(
            dateRange: '09 – 13 Şubat 2026',
            title: 'Ders Kayıt Yenileme ve Katkı Payı Ödemeleri',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '16 Şubat 2026',
            title: 'Derslerin Başlaması',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '23 – 27 Şubat 2026',
            title: 'Ders Ekle / Bırak İşlemleri',
            type: CalendarEventType.addDrop,
          ),
          CalendarEvent(
            dateRange: '10 Haziran 2026',
            title: 'Derslerin Sona Ermesi',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '15 – 26 Haziran 2026',
            title: 'Yıl / Yarıyıl Sonu Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '06 – 10 Temmuz 2026',
            title: 'Bütünleme Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '22 – 26 Temmuz 2026',
            title: 'Tek Ders Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '27 Temmuz – 02 Ağustos 2026',
            title: 'Ek Sınavlar 1 – 2',
            type: CalendarEventType.exam,
          ),
        ],
      ),
    ],
  ),

  // ── DİŞ HEKİMLİĞİ FAKÜLTESİ ──
  FacultyCalendar(
    name: 'Diş Hekimliği Fakültesi',
    shortName: 'Diş Hek.',
    icon: Icons.local_hospital_rounded,
    semesters: [
      SemesterSection(
        title: 'GÜZ YARIYILI',
        dateRange: '22 Eylül 2025 – 09 Ocak 2026',
        events: [
          CalendarEvent(
            dateRange: '01 – 05 Eylül 2025',
            title: 'Kayıt Yenileme (Dönem IV-V)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '08 Eylül 2025',
            title: 'Stajların Başlaması',
            type: CalendarEventType.internship,
          ),
          CalendarEvent(
            dateRange: '15 – 19 Eylül 2025',
            title: 'Kayıt Yenileme (Dönem I-II-III)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '22 Eylül 2025',
            title: 'Derslerin Başlaması',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '22 Eylül – 03 Ekim 2025',
            title: 'Ders Ekle / Bırak İşlemleri',
            type: CalendarEventType.addDrop,
          ),
          CalendarEvent(
            dateRange: '24 Kasım – 19 Aralık 2025',
            title: 'I. Ara Sınav Dönemi',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '09 Ocak 2026',
            title: 'Derslerin Sona Ermesi',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '12 – 16 Ocak 2026',
            title: 'Yarıyıl Sonu Sınavları (Yarıyıllık Dersler)',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '26 – 30 Ocak 2026',
            title: 'Bütünleme Sınavları (Yarıyıllık Dersler)',
            type: CalendarEventType.exam,
          ),
        ],
      ),
      SemesterSection(
        title: 'BAHAR YARIYILI',
        dateRange: '02 Şubat 2026 – 22 Mayıs 2026',
        events: [
          CalendarEvent(
            dateRange: '26 – 30 Ocak 2026',
            title: 'Kayıt Yenileme',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '02 Şubat 2026',
            title: 'Derslerin Başlaması',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '02 – 13 Şubat 2026',
            title: 'Ders Ekle / Bırak İşlemleri',
            type: CalendarEventType.addDrop,
          ),
          CalendarEvent(
            dateRange: '06 – 30 Nisan 2026',
            title: 'II. Ara Sınav Dönemi',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '22 Mayıs 2026',
            title: 'Derslerin ve Stajların Sona Ermesi',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '01 – 19 Haziran 2026',
            title: 'Yıl Sonu Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '29 Haziran – 17 Temmuz 2026',
            title: 'Bütünleme Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '27 Temmuz 2026',
            title: 'Tek Ders Sınavı',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '29 Haziran – 28 Ağustos 2026',
            title: 'Yaz Telafi Stajları',
            type: CalendarEventType.internship,
          ),
        ],
      ),
    ],
  ),

  // ── TIP FAKÜLTESİ ──
  FacultyCalendar(
    name: 'Tıp Fakültesi',
    shortName: 'Tıp',
    icon: Icons.healing_rounded,
    semesters: [
      SemesterSection(
        title: 'GÜZ YARIYILI',
        dateRange: '1 Eylül 2025 – 09 Ocak 2026',
        events: [
          CalendarEvent(
            dateRange: '01 – 05 Temmuz 2025',
            title: 'Kayıt Yenileme (Dönem VI)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '01 Temmuz 2025',
            title: 'Stajların Başlaması (Dönem VI)',
            type: CalendarEventType.internship,
          ),
          CalendarEvent(
            dateRange: '01 – 07 Eylül 2025',
            title: 'Kayıt Yenileme (Dönem II-III-IV-V)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '01 Eylül 2025',
            title: 'Ders Kurulları, KUK ve Stajların Başlaması (Dönem II-III-IV-V)',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '15 – 20 Eylül 2025',
            title: 'Kayıt Yenileme (Dönem I)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '15 Eylül 2025',
            title: 'Derslerin Başlaması (Dönem I)',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '10 – 21 Kasım 2025',
            title: 'Ara Dönem Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '09 Ocak 2026',
            title: 'Derslerin / KUK\'ların / Stajların Sona Ermesi (Dönem I-II-III-IV-V)',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '19 – 23 Ocak 2026',
            title: 'Bütünleme Sınavları (Dönem IV-V)',
            type: CalendarEventType.exam,
          ),
        ],
      ),
      SemesterSection(
        title: 'BAHAR YARIYILI',
        dateRange: '26 Ocak 2026 – 30 Haziran 2026',
        events: [
          CalendarEvent(
            dateRange: '26 Ocak – 3 Şubat 2026',
            title: 'Kayıt Yenileme (Dönem I-II-III-IV-V)',
            type: CalendarEventType.registration,
          ),
          CalendarEvent(
            dateRange: '26 Ocak 2026',
            title: 'Derslerin / KUK\'ların / Stajların Başlaması (Dönem I-II-III-IV-V)',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '13 – 24 Nisan 2026',
            title: 'Ara Dönem Sınavları',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '12 Haziran 2026',
            title: 'Derslerin / KUK\'ların Sona Ermesi (Dönem I-II-III-IV)',
            type: CalendarEventType.semester,
          ),
          CalendarEvent(
            dateRange: '16 Haziran 2026',
            title: 'Stajların Sona Ermesi (Dönem V)',
            type: CalendarEventType.internship,
          ),
          CalendarEvent(
            dateRange: '24 – 26 Haziran 2026',
            title: 'Yıl Sonu Pratik Sınavları (Dönem I-II-III)',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '24 – 26 Haziran 2026',
            title: 'Yıl Sonu Sınavı (Dönem I-II-III)',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '24 – 30 Haziran 2026',
            title: 'Bütünleme Sınavı (Dönem IV-V)',
            type: CalendarEventType.exam,
          ),
          CalendarEvent(
            dateRange: '30 Haziran 2026',
            title: 'Stajların Sona Ermesi (Dönem VI)',
            type: CalendarEventType.internship,
          ),
          CalendarEvent(
            dateRange: '8 – 10 Temmuz 2026',
            title: 'Bütünleme Sınavları (Dönem I-II-III)',
            type: CalendarEventType.exam,
          ),
        ],
      ),
    ],
  ),
];

// =============================================
// AKADEMİK TAKVİM SAYFASI
// =============================================
class AcademicCalendarView extends StatefulWidget {
  final Color kPrimaryColor;
  const AcademicCalendarView({super.key, required this.kPrimaryColor});

  @override
  State<AcademicCalendarView> createState() => _AcademicCalendarViewState();
}

class _AcademicCalendarViewState extends State<AcademicCalendarView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: academicCalendars.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Etkinlik tipine göre renk/ikon
  Color _eventColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.semester:
        return const Color(0xFF800000);
      case CalendarEventType.exam:
        return const Color(0xFFD32F2F);
      case CalendarEventType.registration:
        return const Color(0xFF1565C0);
      case CalendarEventType.addDrop:
        return const Color(0xFF2E7D32);
      case CalendarEventType.internship:
        return const Color(0xFFE65100);
      case CalendarEventType.other:
        return AppColors.textBody;
    }
  }

  IconData _eventIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.semester:
        return Icons.play_circle_filled_rounded;
      case CalendarEventType.exam:
        return Icons.assignment_rounded;
      case CalendarEventType.registration:
        return Icons.app_registration_rounded;
      case CalendarEventType.addDrop:
        return Icons.swap_horiz_rounded;
      case CalendarEventType.internship:
        return Icons.work_rounded;
      case CalendarEventType.other:
        return Icons.info_rounded;
    }
  }

  String _eventTypeLabel(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.semester:
        return 'DÖNEM';
      case CalendarEventType.exam:
        return 'SINAV';
      case CalendarEventType.registration:
        return 'KAYIT';
      case CalendarEventType.addDrop:
        return 'EKLE/BIRAK';
      case CalendarEventType.internship:
        return 'STAJ';
      case CalendarEventType.other:
        return 'DİĞER';
    }
  }

  Widget _buildEventCard(CalendarEvent event) {
    final color = _eventColor(event.type);
    final icon = _eventIcon(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _eventTypeLabel(event.type),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.textHeader,
                    ),
                  ),

                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: AppColors.textBody.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        event.dateRange,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterSection(SemesterSection section) {
    final isGuz = section.title.contains('GÜZ');
    final gradientColors = isGuz
        ? [const Color(0xFFFF6B35), const Color(0xFFFF8C42)]
        : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Yarıyıl başlık kartı
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGuz ? Icons.wb_sunny_rounded : Icons.local_florist_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.dateRange,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Etkinlikler
        ...section.events.map((e) => _buildEventCard(e)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFacultyTab(FacultyCalendar faculty) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: faculty.semesters
          .map((s) => _buildSemesterSection(s))
          .toList(),
    );
  }

  // Renk renk legend
  Widget _buildLegend() {
    final items = [
      (CalendarEventType.semester, 'Dönem Başı/Sonu'),
      (CalendarEventType.exam, 'Sınav'),
      (CalendarEventType.registration, 'Kayıt'),
      (CalendarEventType.addDrop, 'Ekle/Bırak'),
      (CalendarEventType.internship, 'Staj'),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final color = _eventColor(item.$1);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Akademik Takvim',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              '2025 – 2026 Eğitim Öğretim Yılı',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: widget.kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          tabs: academicCalendars
              .map(
                (f) => Tab(
                  icon: Icon(f.icon, size: 18),
                  text: f.shortName,
                ),
              )
              .toList(),
        ),
      ),
      body: Column(
        children: [
          _buildLegend(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: academicCalendars
                  .map((f) => _buildFacultyTab(f))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
