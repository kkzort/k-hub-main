import 'package:flutter/material.dart';
import '../../core/style/app_colors.dart';


class CafeteriaView extends StatefulWidget {
  final Color kPrimaryColor;
  const CafeteriaView({super.key, required this.kPrimaryColor});
  @override
  State<CafeteriaView> createState() => _CafeteriaViewState();
}

class _CafeteriaViewState extends State<CafeteriaView> {
  late PageController _pageController;
  late int _initialPage;

  // Şubat 2026 – Kırıkkale Üniversitesi Aylık Yemek Menüsü
  final Map<String, List<Map<String, String>>> _menu = {
    '2026-02-02': [
      {'name': 'Yayla Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Fırılı Köş\'o Köfte', 'kcal': '340', 'icon': '🍖'},
      {'name': 'Erişte Pilavı', 'kcal': '280', 'icon': '🍚'},
      {'name': 'Haydari', 'kcal': '114', 'icon': '🥒', 'tag': 'Seçenek'},
      {'name': 'Yaş Pasta', 'kcal': '363', 'icon': '🍰', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-03': [
      {'name': 'Mercimek Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Fırın Tavuk', 'kcal': '398', 'icon': '🍗'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Ayran', 'kcal': '75', 'icon': '🥛', 'tag': 'Seçenek'},
      {'name': 'Şekerpare', 'kcal': '195', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-04': [
      {'name': 'Ezogelin Çorba', 'kcal': '200', 'icon': '🍲'},
      {'name': 'İzmir Köfte', 'kcal': '280', 'icon': '🍖'},
      {'name': 'Şehriye Pilavı', 'kcal': '280', 'icon': '🍚'},
      {'name': 'Havuç Tarator', 'kcal': '191', 'icon': '🥕', 'tag': 'Seçenek'},
      {'name': 'Kalburabastı', 'kcal': '272', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-05': [
      {'name': 'Şehriye Çorba', 'kcal': '219', 'icon': '🍲'},
      {'name': 'Tavuk Sote', 'kcal': '388', 'icon': '🍗'},
      {'name': 'Bulgur Pilavı', 'kcal': '240', 'icon': '🍚'},
      {'name': 'Salata', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Supangle', 'kcal': '219', 'icon': '🍫', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-06': [
      {'name': 'Tarhana Çorba', 'kcal': '148', 'icon': '🍲'},
      {'name': 'Etli Karnıbahar', 'kcal': '344', 'icon': '🥦'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Cacık', 'kcal': '146', 'icon': '🥒', 'tag': 'Seçenek'},
      {'name': 'Çiğköfte', 'kcal': '277', 'icon': '🌯', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-09': [
      {'name': 'Ezogelin Çorba', 'kcal': '200', 'icon': '🍲'},
      {'name': 'Ekmek Arası Tavuk Tantuni', 'kcal': '456', 'icon': '🌯'},
      {'name': 'Karışık Kızartma', 'kcal': '452', 'icon': '🍟'},
      {'name': 'Ayran', 'kcal': '75', 'icon': '🥛', 'tag': 'Seçenek'},
      {'name': 'Kemalpaşa', 'kcal': '251', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-10': [
      {'name': 'Mercimek Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Soslu Köfte', 'kcal': '340', 'icon': '🍖'},
      {'name': 'Erişte Pilavı', 'kcal': '280', 'icon': '🍚'},
      {'name': 'Mevsim Salata', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Ç. Puding', 'kcal': '254', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-11': [
      {'name': 'Tarhana Çorba', 'kcal': '148', 'icon': '🍲'},
      {'name': 'Tavuk Haşlama Patates', 'kcal': '387', 'icon': '🍗'},
      {'name': 'Pirinç Pilavı', 'kcal': '310', 'icon': '🍚'},
      {'name': 'Salata', 'kcal': '78', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Revani', 'kcal': '448', 'icon': '🍰', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-12': [
      {'name': 'Domates Çorba', 'kcal': '150', 'icon': '🍅'},
      {'name': 'Beyti Kebap', 'kcal': '452', 'icon': '🥩'},
      {'name': 'Bulgur Pilavı', 'kcal': '240', 'icon': '🍚'},
      {'name': 'Haydari', 'kcal': '114', 'icon': '🥒', 'tag': 'Seçenek'},
      {'name': 'Mozaik Pasta', 'kcal': '552', 'icon': '🍰', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-13': [
      {'name': 'Köylüm Çorba', 'kcal': '189', 'icon': '🍲'},
      {'name': 'Tavuk Sarma', 'kcal': '350', 'icon': '🍗'},
      {'name': 'Makarna', 'kcal': '350', 'icon': '🍝'},
      {'name': 'Ayran', 'kcal': '75', 'icon': '🥛', 'tag': 'Seçenek'},
      {'name': 'İrmik Helvası', 'kcal': '114', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-16': [
      {'name': 'Mercimek Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Et Tantuni', 'kcal': '386', 'icon': '🌯'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Ayran', 'kcal': '75', 'icon': '🥛', 'tag': 'Seçenek'},
      {'name': 'Şekerpare', 'kcal': '215', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-17': [
      {'name': 'Domates Çorba', 'kcal': '150', 'icon': '🍅'},
      {'name': 'Kanat Izgara', 'kcal': '466', 'icon': '🍗'},
      {'name': 'Pirinç Pilavı', 'kcal': '370', 'icon': '🍚'},
      {'name': 'Rus Salatası', 'kcal': '255', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Islak Kek', 'kcal': '380', 'icon': '🍫', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-18': [
      {'name': 'Şehriye Çorba', 'kcal': '219', 'icon': '🍲'},
      {'name': 'Kıymalı Pide', 'kcal': '300', 'icon': '🫓'},
      {'name': 'Karışık Kızartma', 'kcal': '452', 'icon': '🍟'},
      {'name': 'Salata', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Burma Kadayıf', 'kcal': '254', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-19': [
      {'name': 'Mercimek Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Soslu Tavuk Göğüs', 'kcal': '388', 'icon': '🍗'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Mevsim Salata', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Güllaç', 'kcal': '280', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-20': [
      {'name': 'Toyga Çorba', 'kcal': '200', 'icon': '🍲'},
      {'name': 'Ekşili Köfte', 'kcal': '300', 'icon': '🍖'},
      {'name': 'Bulgur Pilavı', 'kcal': '240', 'icon': '🍚'},
      {'name': 'Havuç Tarator', 'kcal': '191', 'icon': '🥕', 'tag': 'Seçenek'},
      {'name': 'Kalburabastı', 'kcal': '392', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-23': [
      {'name': 'Mercimek Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Fırın Tavuk', 'kcal': '386', 'icon': '🍗'},
      {'name': 'Bahar Pilavı', 'kcal': '220', 'icon': '🍚'},
      {'name': 'Kapya Biber Tarator', 'kcal': '191', 'icon': '🌶️', 'tag': 'Seçenek'},
      {'name': 'Şekerpare', 'kcal': '195', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-24': [
      {'name': 'Yayla Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Izgara Köfte', 'kcal': '400', 'icon': '🍖'},
      {'name': 'Erişte Pilavı', 'kcal': '280', 'icon': '🍚'},
      {'name': 'Salata', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Trileçe', 'kcal': '245', 'icon': '🍰', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-25': [
      {'name': 'Yüksük Çorba', 'kcal': '192', 'icon': '🍲'},
      {'name': 'Orman Kebap', 'kcal': '310', 'icon': '🥩'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Cacık', 'kcal': '146', 'icon': '🥒', 'tag': 'Seçenek'},
      {'name': 'Sütlaç', 'kcal': '570', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-26': [
      {'name': 'Ezogelin Çorba', 'kcal': '200', 'icon': '🍲'},
      {'name': 'Tavuk Sote', 'kcal': '388', 'icon': '🍗'},
      {'name': 'Bulgur Pilavı', 'kcal': '240', 'icon': '🍚'},
      {'name': 'Kış Salatası', 'kcal': '75', 'icon': '🥗', 'tag': 'Seçenek'},
      {'name': 'Kıbrıs Tatlısı', 'kcal': '448', 'icon': '🍰', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
    '2026-02-27': [
      {'name': 'Köylüm Çorba', 'kcal': '189', 'icon': '🍲'},
      {'name': 'Etli Nohut', 'kcal': '310', 'icon': '🫘'},
      {'name': 'Pirinç Pilavı', 'kcal': '350', 'icon': '🍚'},
      {'name': 'Ayran', 'kcal': '75', 'icon': '🥛', 'tag': 'Seçenek'},
      {'name': 'Kemalpaşa', 'kcal': '251', 'icon': '🍮', 'tag': 'Seçenek'},
      {'name': 'Meyve', 'kcal': '100', 'icon': '🍎', 'tag': 'Seçenek'},
      {'name': 'Ekmek', 'kcal': '125', 'icon': '🍞'},
    ],
  };

  late List<String> _sortedDates;

  @override
  void initState() {
    super.initState();
    _sortedDates = _menu.keys.toList()..sort();
    // Bugünün tarihini bul veya en yakın tarihi seç
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _initialPage = _sortedDates.indexOf(todayStr);
    if (_initialPage < 0) {
      // Bugün listede yoksa en yakın gelecek tarihi bul
      _initialPage = _sortedDates.indexWhere((d) => d.compareTo(todayStr) >= 0);
      if (_initialPage < 0) _initialPage = _sortedDates.length - 1;
    }
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _dayName(DateTime date) {
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[date.weekday - 1];
  }

  String _monthName(int month) {
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month];
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── ÜST BÖLÜM ───
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 20,
            ),
            decoration: BoxDecoration(
              color: widget.kPrimaryColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // Geri butonu ve başlık
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Yemekhane Menüsü",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text("🍽️", style: TextStyle(fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 12),
                // Tarih bilgisi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Şubat 2026 • Kırıkkale Üniversitesi",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── MENÜ KARTLARI (swipe) ───
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _sortedDates.length,
              itemBuilder: (context, index) {
                final dateStr = _sortedDates[index];
                final date = DateTime.parse(dateStr);
                final items = _menu[dateStr]!;
                final isToday = dateStr == todayStr;
                final dayStr = _dayName(date);
                final dateFormatted = _formatDate(date);

                // Toplam kalori (ana yemekler, seçenek hariç)
                int totalKcal = 0;
                for (var item in items) {
                  if (item['tag'] != 'Seçenek') {
                    totalKcal += int.tryParse(item['kcal'] ?? '0') ?? 0;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      // Tarih kartı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isToday ? widget.kPrimaryColor : AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isToday ? 60 : 15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: isToday ? Colors.white.withAlpha(50) : widget.kPrimaryColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  "${date.day}",
                                  style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900,
                                    color: isToday ? Colors.white : widget.kPrimaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dayStr,
                                    style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w800,
                                      color: isToday ? Colors.white : AppColors.textHeader,
                                    ),
                                  ),
                                  Text(
                                    dateFormatted,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isToday ? Colors.white70 : AppColors.textBody,
                                    ),
                                  ),

                                ],
                              ),
                            ),
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(60),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text("BUGÜN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            if (!isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text("$totalKcal kcal", style: TextStyle(color: Colors.orange[800], fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Yemek listesi
                      ...items.map((item) {
                        final isOptional = item['tag'] == 'Seçenek';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: isOptional ? Border.all(color: AppColors.border.withValues(alpha: 0.1)) : null,
                            boxShadow: isOptional ? null : [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(item['icon'] ?? '🍽️', style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isOptional ? FontWeight.w500 : FontWeight.w700,
                                        color: isOptional ? AppColors.textBody : AppColors.textHeader,
                                      ),
                                    ),

                                    if (isOptional)
                                      Text("Seçenek", style: TextStyle(fontSize: 10, color: AppColors.textBody.withValues(alpha: 0.7))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOptional
                                      ? Colors.grey.withAlpha(20)
                                      : Colors.green.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${item['kcal']} kcal",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isOptional ? Colors.grey : Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Swipe ipucu
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (index > 0)
                              Icon(Icons.chevron_left, size: 18, color: AppColors.textBody.withValues(alpha: 0.5)),
                            Text(
                              "  Kaydırarak günleri değiştir  ",
                              style: TextStyle(fontSize: 11, color: AppColors.textBody.withValues(alpha: 0.5)),
                            ),
                            if (index < _sortedDates.length - 1)
                              Icon(Icons.chevron_right, size: 18, color: AppColors.textBody.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
