import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/style/app_colors.dart';

class WeatherDetailView extends StatefulWidget {
  const WeatherDetailView({super.key});

  @override
  State<WeatherDetailView> createState() => _WeatherDetailViewState();
}

class _WeatherDetailViewState extends State<WeatherDetailView>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _weatherData;
  bool _loading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _apiUrl =
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=39.8468&longitude=33.5153'
      '&current=temperature_2m,weather_code,relative_humidity_2m,'
      'wind_speed_10m,surface_pressure,apparent_temperature'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
      'sunrise,sunset,uv_index_max'
      '&hourly=temperature_2m,weather_code'
      '&timezone=Europe/Istanbul&forecast_days=3';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fetchWeatherData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeatherData() async {
    // 1. Cache'den hızlı yükle
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('weather_detail_cache');
      if (cached != null && mounted) {
        final data = json.decode(cached);
        if (data['current'] != null) {
          setState(() {
            _weatherData = data;
            _loading = false;
          });
          _fadeController.forward();
          _slideController.forward();
        }
      }
    } catch (_) {}

    // 2. API'den güncelle (8 sn timeout)
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Cache'e kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('weather_detail_cache', response.body);
        await prefs.setInt(
            'weather_cache_time', DateTime.now().millisecondsSinceEpoch);

        if (mounted) {
          setState(() {
            _weatherData = data;
            _loading = false;
          });
          if (!_fadeController.isCompleted) {
            _fadeController.forward();
            _slideController.forward();
          }
        }
      }
    } catch (_) {
      if (mounted && _weatherData == null) {
        setState(() => _loading = false);
      }
    }
  }

  // ── WMO kod eşlemeleri ──

  String _getWeatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code == 1) return '🌤️';
    if (code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 57) return '🌦️';
    if (code >= 61 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '🌨️';
    if (code >= 80 && code <= 82) return '🌧️';
    if (code >= 85 && code <= 86) return '🌨️';
    if (code >= 95) return '⛈️';
    return '🌤️';
  }

  String _getWeatherDesc(int code) {
    if (code == 0) return 'Güneşli';
    if (code == 1) return 'Açık';
    if (code == 2) return 'Parçalı Bulutlu';
    if (code == 3) return 'Kapalı';
    if (code == 45 || code == 48) return 'Sisli';
    if (code >= 51 && code <= 55) return 'Çiseleme';
    if (code == 56 || code == 57) return 'Dondurucu Çiseleme';
    if (code >= 61 && code <= 65) return 'Yağmurlu';
    if (code == 66 || code == 67) return 'Dondurucu Yağmur';
    if (code >= 71 && code <= 77) return 'Karlı';
    if (code >= 80 && code <= 82) return 'Sağanak';
    if (code >= 85 && code <= 86) return 'Kar Sağanağı';
    if (code == 95) return 'Gök Gürültülü';
    if (code == 96 || code == 99) return 'Dolu';
    return 'Açık';
  }

  String _getDayName(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);

      if (target == today) return 'Bugün';
      if (target == today.add(const Duration(days: 1))) return 'Yarın';

      const days = [
        'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
        'Cuma', 'Cumartesi', 'Pazar'
      ];
      return days[date.weekday - 1];
    } catch (_) {
      return dateStr;
    }
  }

  Color _getWeatherGradientStart(int code) {
    if (code == 0) return const Color(0xFF4A90D9);
    if (code <= 2) return const Color(0xFF5B9BD5);
    if (code == 3) return const Color(0xFF6B7B8D);
    if (code == 45 || code == 48) return const Color(0xFF8090A0);
    if (code >= 51 && code <= 67) return const Color(0xFF4A6B8A);
    if (code >= 71 && code <= 86) return const Color(0xFF8BA4B8);
    if (code >= 95) return const Color(0xFF3D4F5F);
    return const Color(0xFF5A9BD5);
  }

  Color _getWeatherGradientEnd(int code) {
    if (code == 0) return const Color(0xFF87CEEB);
    if (code <= 2) return const Color(0xFF9BC4E2);
    if (code == 3) return const Color(0xFF95A5B5);
    if (code == 45 || code == 48) return const Color(0xFFB0BEC5);
    if (code >= 51 && code <= 67) return const Color(0xFF7A9AB5);
    if (code >= 71 && code <= 86) return const Color(0xFFB8CCE0);
    if (code >= 95) return const Color(0xFF5C7080);
    return const Color(0xFF87C4E8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hava durumu yükleniyor...',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _weatherData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('😕', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Hava durumu alınamadı',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _fetchWeatherData();
                        },
                        icon: Icon(Icons.refresh, color: AppColors.primary),
                        label: Text('Tekrar Dene',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final current = _weatherData!['current'];
    final daily = _weatherData!['daily'];
    final hourly = _weatherData!['hourly'];

    final currentTemp =
        '${(current['temperature_2m'] as num?)?.round() ?? '--'}';
    final currentCode = (current['weather_code'] as num?)?.toInt() ?? 0;
    final feelsLike =
        '${(current['apparent_temperature'] as num?)?.round() ?? '--'}';
    final humidity = '${current['relative_humidity_2m'] ?? '--'}';
    final windSpeed =
        '${(current['wind_speed_10m'] as num?)?.round() ?? '--'}';
    final pressure =
        '${(current['surface_pressure'] as num?)?.round() ?? '--'}';

    // Günlük verilerden UV indeks
    final dailyUv = daily['uv_index_max'] as List?;
    final uvIndex = dailyUv != null && dailyUv.isNotEmpty
        ? '${(dailyUv[0] as num?)?.round() ?? '--'}'
        : '--';

    // Günlük max/min
    final dailyMax = daily['temperature_2m_max'] as List?;
    final dailyMin = daily['temperature_2m_min'] as List?;
    final maxTemp = dailyMax != null && dailyMax.isNotEmpty
        ? '${(dailyMax[0] as num?)?.round() ?? '--'}'
        : '--';
    final minTemp = dailyMin != null && dailyMin.isNotEmpty
        ? '${(dailyMin[0] as num?)?.round() ?? '--'}'
        : '--';

    // Günlük tahmin sayısı
    final dailyTimes = daily['time'] as List? ?? [];
    final dayCount = dailyTimes.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: _buildHeroHeader(
                currentTemp, currentCode, feelsLike, maxTemp, minTemp,
              ),
            ),

            // Detay Bilgileri
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Detaylar',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildDetailsGrid(
                humidity, windSpeed, pressure, uvIndex,
              ),
            ),

            // Saatlik Tahmin
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Saatlik Tahmin',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildHourlyForecast(hourly),
            ),

            // Günlük Tahmin
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Günlük Tahmin',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildDayForecastCard(daily, index);
                },
                childCount: dayCount,
              ),
            ),

            // Alt boşluk
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    String temp, int code, String feelsLike,
    String maxTemp, String minTemp,
  ) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _getWeatherGradientStart(code),
                  _getWeatherGradientEnd(code),
                  AppColors.background,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Geri butonu + Konum
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Kırıkkale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() => _loading = true);
                          _fetchWeatherData();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Hava durumu ikonu
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Text(
                      _getWeatherIcon(code),
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sıcaklık
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '$temp°',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Durum açıklaması
                  Text(
                    _getWeatherDesc(code),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Min / Max / Hissedilen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniStat('↑ $maxTemp°', 'Maks'),
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white24,
                      ),
                      _buildMiniStat('↓ $minTemp°', 'Min'),
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white24,
                      ),
                      _buildMiniStat('$feelsLike°', 'Hissedilen'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsGrid(
    String humidity,
    String windSpeed,
    String pressure,
    String uvIndex,
  ) {
    final items = [
      _DetailItem(Icons.water_drop_outlined, 'Nem', '%$humidity'),
      _DetailItem(Icons.air, 'Rüzgar', '$windSpeed km/s'),
      _DetailItem(Icons.compress, 'Basınç', '$pressure hPa'),
      _DetailItem(Icons.wb_sunny_outlined, 'UV İndeks', uvIndex),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(
                milliseconds: 500 + items.indexOf(item) * 100),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 15 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: (MediaQuery.of(context).size.width - 42) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeader,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHourlyForecast(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List? ?? [];
    final temps = hourly['temperature_2m'] as List? ?? [];
    final codes = hourly['weather_code'] as List? ?? [];

    if (times.isEmpty) return const SizedBox();

    // Şu andan itibaren saatleri göster (en fazla 24)
    final now = DateTime.now();
    int startIdx = 0;
    for (int i = 0; i < times.length; i++) {
      try {
        final t = DateTime.parse(times[i]);
        if (t.isAfter(now) || t.isAtSameMomentAs(now)) {
          startIdx = i;
          break;
        }
      } catch (_) {}
    }
    final endIdx =
        (startIdx + 24).clamp(0, times.length);
    final visibleCount = endIdx - startIdx;

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visibleCount,
        itemBuilder: (context, index) {
          final i = startIdx + index;
          final timeStr = times[i] as String;
          final temp = (temps[i] as num?)?.round() ?? '--';
          final code = (codes[i] as num?)?.toInt() ?? 0;

          // "2024-01-01T14:00" → "14:00"
          String hourStr = '--:--';
          try {
            final dt = DateTime.parse(timeStr);
            hourStr =
                '${dt.hour.toString().padLeft(2, '0')}:00';
          } catch (_) {}

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration:
                Duration(milliseconds: 400 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hourStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getWeatherIcon(code),
                    style: const TextStyle(fontSize: 28),
                  ),
                  Text(
                    '$temp°',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeader,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayForecastCard(Map<String, dynamic> daily, int index) {
    final times = daily['time'] as List? ?? [];
    final weatherCodes = daily['weather_code'] as List? ?? [];
    final maxTemps = daily['temperature_2m_max'] as List? ?? [];
    final minTemps = daily['temperature_2m_min'] as List? ?? [];
    final sunrises = daily['sunrise'] as List? ?? [];
    final sunsets = daily['sunset'] as List? ?? [];

    final date = index < times.length ? times[index] as String : '';
    final code = index < weatherCodes.length
        ? (weatherCodes[index] as num?)?.toInt() ?? 0
        : 0;
    final maxTemp = index < maxTemps.length
        ? '${(maxTemps[index] as num?)?.round() ?? '--'}'
        : '--';
    final minTemp = index < minTemps.length
        ? '${(minTemps[index] as num?)?.round() ?? '--'}'
        : '--';

    String sunrise = '';
    String sunset = '';
    if (index < sunrises.length) {
      try {
        final dt = DateTime.parse(sunrises[index]);
        sunrise =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    if (index < sunsets.length) {
      try {
        final dt = DateTime.parse(sunsets[index]);
        sunset =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final dayName = _getDayName(date);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + index * 150),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          children: [
            // Üst kısım: Gün, ikon, sıcaklık
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeader,
                        ),
                      ),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(_getWeatherIcon(code),
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getWeatherDesc(code),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$maxTemp°',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeader,
                      ),
                    ),
                    Text(
                      '$minTemp°',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Alt kısım: Detaylar
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (sunrise.isNotEmpty)
                    _buildSmallDetail(
                        Icons.wb_sunny_outlined, sunrise),
                  if (sunset.isNotEmpty)
                    _buildSmallDetail(
                        Icons.nightlight_outlined, sunset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  _DetailItem(this.icon, this.label, this.value);
}
