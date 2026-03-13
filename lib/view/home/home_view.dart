import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../service/auth_service.dart';
import '../../service/storage_service.dart';
import '../../service/note_service.dart';
import '../auth/login_view.dart';
import '../auth/banned_view.dart';
import 'dart:async';
import '../admin/admin_home_view.dart';
import 'academic_calendar_view.dart';
import 'cafeteria_view.dart';
import 'campus_map_view.dart';
import 'event_calendar_view.dart';
import 'ai_chat_view.dart';
import 'k_bot_view.dart';
import '../../core/style/app_colors.dart';
import '../social/social_feed_view.dart';
import '../social/saved_posts_view.dart';
import '../social/profile_posts_scroll_view.dart';
import '../../service/post_service.dart';
import '../../service/friendship_service.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../core/widgets/verified_badge.dart';
import '../../service/profile_visit_service.dart';
import '../social/user_profile_view.dart';
import 'weather_detail_view.dart';
import 'premium_view.dart';

class HomeView extends StatefulWidget {
  final bool isAdmin;
  const HomeView({super.key, this.isAdmin = false});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Başlangıçta Ana Sayfa (Index 2)
  int _selectedIndex = 2;
  late PageController _pageController;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final NoteService _noteService = NoteService();
  final ImagePicker _imagePicker = ImagePicker();
  final currentUser = FirebaseAuth.instance.currentUser;

  // CONTROLLERS
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _chatSearchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _homeSearchController = TextEditingController();
  DateTime _chatSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSender;
  String? _replyToSenderEmail;

  String _searchText = "";
  String _homeSearchQuery = "";
  bool _isSearching = false;
  bool _isChatSearching = false;
  String _chatSearchQuery = "";
  List<Map<String, dynamic>> _searchUsers = [];
  List<Map<String, dynamic>> _searchNotes = [];

  // HAVA DURUMU
  String _weatherTemp = "--";
  String _weatherIcon = "🌤️";

  // NICKNAME
  String? _userNick;

  // RENKLER
  // RENKLER (Tema destekli)
  Color get kPrimaryColor => Theme.of(context).primaryColor;
  Color get kBackgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get kSurfaceColor => Theme.of(context).colorScheme.surface;

  // AVATARLAR
  final List<IconData> avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.face_3,
    Icons.face_6,
    Icons.emoji_emotions,
    Icons.pets,
    Icons.school,
    Icons.computer,
  ];

  // FİLTRELER
  String selectedFaculty = "Hepsi";
  String selectedDepartment = "Hepsi";
  String selectedCourse = "Hepsi";
  final Map<String, List<String>> departmentsByFaculty = {
    "Hepsi": ["Hepsi"],
    "Diş Hekimliği Fakültesi": [
      "Hepsi",
      "Ağız, Diş ve Çene Radyolojisi",
      "Ağız, Diş ve Çene Cerrahisi",
      "Restoratif Diş Tedavisi",
      "Endodonti",
      "Ortodonti",
      "Pedodonti",
      "Periodontoloji",
      "Protetik Diş Tedavisi",
      "Temel Tıp Bilimleri",
    ],
    "Eğitim Fakültesi": [
      "Hepsi",
      "Bilgisayar ve Öğretim Teknolojileri Eğitimi Anabilim Dalı",
      "Eğitim Bilimleri Bölümü",
      "Eğitim Programları ve Öğretim Anabilim Dalı",
      "Eğitim Yönetimi Anabilim Dalı",
      "Rehberlik ve Psikolojik Danışmanlık Anabilim Dalı",
      "Eğitimde Ölçme ve Değerlendirme Anabilim Dalı",
      "Eğitimin Felsefi, Sosyal ve Tarihi Temelleri Anabilim Dalı",
      "Hayat Boyu Öğrenme ve Yetişkin Eğitimi Anabilim Dalı",
      "Fen Bilgisi Eğitimi Anabilim Dalı",
      "Matematik Eğitimi Anabilim Dalı",
      "Sosyal Bilgiler Eğitimi Anabilim Dalı",
      "Türkçe Eğitimi Anabilim Dalı",
      "Sınıf Eğitimi Anabilim Dalı",
      "Okul Öncesi Eğitimi Anabilim Dalı",
      "Özel Eğitim Bölümü",
      "Görme Engelliler Eğitimi Anabilim Dalı",
      "İşitme Engelliler Eğitimi Anabilim Dalı",
      "Özel Yetenekliler Eğitimi Anabilim Dalı",
      "Zihin Engelliler Eğitimi Anabilim Dalı",
    ],
    "Güzel Sanatlar Fakültesi": [
      "Hepsi",
      "Müzik",
      "Resim",
      "İç Mimarlık ve Çevre Tasarımı",
      "Peyzaj Mimarlığı",
      "Çizgi Film ve Animasyon",
      "Geleneksel Türk Sanatları",
      "Endüstriyel Tasarım",
      "Grafik",
      "Seramik",
    ],
    "Hukuk Fakültesi": [
      "Hepsi",
      "Kamu Hukuku Bölümü",
      "Milletlerarası Hukuk Ana Bilim Dalı",
      "Genel Kamu Hukuku AnaBilim Dalı",
      "Anayasa Hukuk AnaBilim Dalı",
      "İdare Hukuku Anabilim Dalı",
      "Ceza ve Ceza Muhakemesi Hukuku Anabilim Dalı",
      "Hukuk Felsefesi ve Sosyolojisi",
      "Hukuk Tarihi Anabilim Dalı",
      "Mali Hukuk Anabilim Dalı",
      "Avrupa Birliği Hukuku Anabilim Dalı",
      "İnsan Hakları Anabilim Dalı",
      "Özel Hukuk Bölümü",
      "Medeni Hukuk",
      "İş ve Sosyal Güvenlik Hukuku",
      "Ticaret Hukuku",
      "Milletlerarası Özel Hukuk Anabilim Dalı",
      "Roma Hukuku Anabilim Dalı",
      "Medeni Usül ve İcra-İflas Hukuku Anabilim Dalı",
      "Deniz Hukuku Anabilim Dalı",
      "İslam Hukuku Anabilim Dalı",
    ],
    "İktisadi ve İdari Bilimler Fakültesi": [
      "Hepsi",
      "İşletme Bölümü",
      "Siyaset Bilimi ve Kamu Yönetimi Bölümü",
      "İktisat Bölümü",
      "Uluslararası ilişkiler Bölümü",
      "Ekonometri Bölümü",
      "Maliye Bölümü",
      "Aktüerya Bilimleri Bölümü",
    ],
    "İslami İlimler Fakültesi": [
      "Hepsi",
      "Temel İslam Bilimleri Bölümü",
      "Felsefe ve Din Bilimleri Bölümü",
      "İslam Tarihi ve Sanatları Bölümü",
    ],
    "İnsan ve Toplum Bilimleri Fakültesi": [
      "Hepsi",
      "Batı Dilleri ve Edebiyatları",
      "Bilgi ve Belge Yönetimi",
      "Doğu Dilleri ve Edebiyatları",
      "Felsefe",
      "Psikoloji",
      "Sosyoloji",
      "Tarih",
      "Türk Dili ve Edebiyatı",
    ],
    "Mühendislik Fakültesi": [
      "Hepsi",
      "Bilgisayar Mühendisliği",
      "Biyomühendislik",
      "Elektrik - Elektronik Mühendisliği",
      "Endüstri Mühendisliği",
      "İnşaat Mühendisliği",
      "Makine Mühendisliği",
      "Metalurji ve Malzeme Mühendisliği",
      "Mimarlık Bölümü",
      "Matematik Bölümü",
      "Fizik Bölümü",
      "Kimya Bölümü",
      "Biyoloji Bölümü",
      "İstatistik Bölümü",
    ],
    "Sağlık Bilimleri Fakültesi": [
      "Hepsi",
      "Beslenme ve Diyetetik Bölümü",
      "Çocuk Gelişimi Bölümü",
      "Fizyoterapi ve Rehabilitasyon Bölümü",
      "Hemşirelik Bölümü",
      "Sağlık Yönetimi Bölümü",
      "Sosyal Hizmet Bölümü",
      "Aile Danışmanlığı ve Eğitimi",
    ],
    "Spor Bilimleri Fakültesi": [
      "Hepsi",
      "Antrenörlük Eğitimi",
      "Beden Eğitimi ve Spor Öğretmenliği",
      "Rekreasyon",
      "Spor Yöneticiliği",
    ],
    "Tıp Fakültesi": [
      "Hepsi",
      "Temel Tıp Bilimleri Bölümü",
      "Dahili Tıp Bilimleri Bölümü",
      "Cerrahi Tıp Bilimleri Bölümü",
    ],
    "Veterinerlik Fakültesi": [
      "Hepsi",
      "Temel Bilimler Bölümü",
      "Klinik Öncesi Bilimler Bölümü",
      "Klinik Bilimler Bölümü",
      "Zootekni ve Hayvan Besleme Bölümü",
      "Gıda Hijyeni ve Teknolojisi Bölümü",
    ],
  };

  List<String> get departments =>
      departmentsByFaculty[selectedFaculty] ?? ["Hepsi"];
  final List<String> faculties = [
    "Hepsi",
    "Diş Hekimliği Fakültesi",
    "Eğitim Fakültesi",
    "Güzel Sanatlar Fakültesi",
    "Hukuk Fakültesi",
    "İktisadi ve İdari Bilimler Fakültesi",
    "İslami İlimler Fakültesi",
    "İnsan ve Toplum Bilimleri Fakültesi",
    "Mühendislik Fakültesi",
    "Sağlık Bilimleri Fakültesi",
    "Spor Bilimleri Fakültesi",
    "Tıp Fakültesi",
    "Veterinerlik Fakültesi",
  ];
  final List<String> courses = ["Hepsi"];
  // Bildirimler her zaman açık

  StreamSubscription? _banSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 2);
    _loadChatSeenAt();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.toLowerCase());
    });
    _chatSearchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _chatSearchQuery = _chatSearchController.text.trim().toLowerCase();
      });
    });
    _fetchWeather();
    _listenBanStatus();
  }

  void _listenBanStatus() {
    if (currentUser == null) return;
    _banSubscription = _authService.banStatusStream(currentUser!.uid).listen((
      banInfo,
    ) {
      if (banInfo != null && mounted) {
        _authService.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => BannedView(banReason: banInfo['banReason']),
          ),
          (route) => false,
        );
      }
    });
  }

  // Bildirim ayarları kaldırıldı — her zaman açık

  Future<void> _loadChatSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('chat_seen_at_ms') ?? 0;
    if (!mounted) return;
    setState(() {
      _chatSeenAt = DateTime.fromMillisecondsSinceEpoch(millis);
    });
  }

  Future<void> _markChatSeenNow() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chat_seen_at_ms', now.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() {
      _chatSeenAt = now;
    });
  }

  void _setReplyTarget({
    required String messageId,
    required String senderName,
    required String senderEmail,
    required String text,
  }) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToSender = senderName;
      _replyToSenderEmail = senderEmail;
      _replyToText = text;
    });
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToMessageId = null;
      _replyToSender = null;
      _replyToSenderEmail = null;
      _replyToText = null;
    });
  }

  Map<String, dynamic> _safeStringDynamicMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Timestamp? _safeTimestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }

  Future<void> _reportChatMessage({
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'type': 'chat_message',
      'status': 'pending',
      'messageId': messageId,
      'messageText': data['text'] ?? '',
      'reportedUserEmail': data['senderEmail'] ?? '',
      'reportedUserName': data['senderName'] ?? '',
      'reporterEmail': currentUser?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mesaj şikayet edildi.')));
  }

  Future<void> _showMessageActions({
    required Offset globalPosition,
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'copy', child: Text('Kopyala')),
        PopupMenuItem<String>(value: 'reply', child: Text('Cevap Ver')),
        PopupMenuItem<String>(value: 'report', child: Text('Şikayet Et')),
      ],
    );

    if (selection == 'copy') {
      await Clipboard.setData(
        ClipboardData(text: (data['text'] ?? '').toString()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı.')));
      return;
    }

    if (selection == 'reply') {
      _setReplyTarget(
        messageId: messageId,
        senderName: (data['senderName'] ?? 'Öğrenci').toString(),
        senderEmail: (data['senderEmail'] ?? '').toString(),
        text: (data['text'] ?? '').toString(),
      );
      return;
    }

    if (selection == 'report') {
      await _reportChatMessage(messageId: messageId, data: data);
    }
  }

  // Bildirimler her zaman açık — izin verildikten sonra kapanmaz

  void _toggleChatSearch() {
    setState(() {
      _isChatSearching = !_isChatSearching;
      if (!_isChatSearching) {
        _chatSearchController.clear();
      }
    });
  }

  Future<void> _handleChatMenuAction(String value) async {
    if (value == 'clear_search') {
      if (!mounted) return;
      setState(() {
        _isChatSearching = false;
      });
      _chatSearchController.clear();
      return;
    }

    if (value == 'mark_seen') {
      await _markChatSeenNow();
      return;
    }

    if (value == 'latest') {
      if (_chatScrollController.hasClients) {
        await _chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// WMO hava durumu kodu → emoji
  static String _wmoIcon(int code) {
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

  /// Kırıkkale hava durumunu çek (cache + timeout) — Open-Meteo API
  Future<void> _fetchWeather() async {
    // 1. Cache'den hızlı yükle
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTemp = prefs.getString('weather_temp');
      final cachedIcon = prefs.getString('weather_icon');
      if (cachedTemp != null && cachedIcon != null && mounted) {
        setState(() {
          _weatherTemp = cachedTemp;
          _weatherIcon = cachedIcon;
        });
      }
    } catch (_) {}

    // 2. API'den güncelle (8 sn timeout)
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast'
              '?latitude=39.8468&longitude=33.5153'
              '&current=temperature_2m,weather_code'
              '&timezone=Europe/Istanbul',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        final temp = (current['temperature_2m'] as num?)?.round() ?? '--';
        final code = (current['weather_code'] as num?)?.toInt() ?? 0;

        final icon = _wmoIcon(code);
        final tempStr = '$temp°C';
        if (mounted) {
          setState(() {
            _weatherTemp = tempStr;
            _weatherIcon = icon;
          });
        }
        // Cache'e kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('weather_temp', tempStr);
        await prefs.setString('weather_icon', icon);
        await prefs.setString('weather_cache', response.body);
        await prefs.setInt(
          'weather_cache_time',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      // Timeout veya hata — cache'den gösterilmeye devam eder
    }
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _chatController.dispose();
    _chatSearchController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // --- LOGIC: CHAT MESAJ GÖNDERME ---
  void _sendMessage() async {
    if (_chatController.text.trim().isNotEmpty) {
      String message = _chatController.text.trim();
      _chatController.clear();

      String userName = currentUser?.displayName ?? "Öğrenci";
      String? userImage;

      try {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (uDoc.exists) {
          userName = uDoc.data()?['name'] ?? userName;
          userImage = uDoc.data()?['photoUrl'];
        }
      } catch (_) {}

      await FirebaseFirestore.instance.collection('messages').add({
        'text': message,
        'senderEmail': currentUser?.email,
        'senderName': userName,
        'senderImage': userImage,
        'replyToMessageId': _replyToMessageId,
        'replyToText': _replyToText,
        'replyToSender': _replyToSender,
        'replyToEmail': _replyToSenderEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _clearReplyTarget();

      // Mesaj atınca hafif kaydırma efekti
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // --- LOGIC: NOT İŞLEMLERİ ---
  Future<void> _toggleLike(String docId, List<dynamic> likedBy) async {
    final uid = currentUser!.uid;
    final isLiked = likedBy.contains(uid);
    await _noteService.toggleLike(docId, uid, isLiked);
  }

  Future<void> _toggleSave(String docId, List<dynamic> savedBy) async {
    final uid = currentUser!.uid;
    final isSaved = savedBy.contains(uid);
    await _noteService.toggleSave(docId, uid, isSaved);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
  }

  // ==========================================
  // --- 0. SEKME: NOTLAR ---
  // ==========================================
  Widget _buildNotesPage() {
    Query notesQuery = FirebaseFirestore.instance.collection('notes');
    if (selectedDepartment != "Hepsi") {
      notesQuery = notesQuery.where(
        'department',
        isEqualTo: selectedDepartment,
      );
    }
    if (selectedFaculty != "Hepsi") {
      notesQuery = notesQuery.where('faculty', isEqualTo: selectedFaculty);
    }
    if (selectedCourse != "Hepsi") {
      notesQuery = notesQuery.where('course', isEqualTo: selectedCourse);
    }
    if (selectedDepartment == "Hepsi" &&
        selectedFaculty == "Hepsi" &&
        selectedCourse == "Hepsi") {
      notesQuery = notesQuery.orderBy('createdAt', descending: true);
    }

    return Column(
      children: [
        // --- HEADER SECTION ---
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ders Notları",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeader,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Search Bar — Glass style
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Notlarda ara...",
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      "Tümü",
                      selectedDepartment == "Hepsi" &&
                          selectedFaculty == "Hepsi" &&
                          selectedCourse == "Hepsi",
                      onTap: () => setState(() {
                        selectedDepartment = "Hepsi";
                        selectedFaculty = "Hepsi";
                        selectedCourse = "Hepsi";
                      }),
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      selectedFaculty == "Hepsi"
                          ? "Fakülte"
                          : (selectedFaculty.length > 13
                                ? "${selectedFaculty.substring(0, 13)}..."
                                : selectedFaculty),
                      selectedFaculty != "Hepsi",
                      hasDropdown: true,
                      onTap: () => _showSearchableSelector(
                        context: context,
                        title: "Fakülte Seç",
                        items: faculties,
                        selected: selectedFaculty,
                        onSelected: (val) => setState(() {
                          selectedFaculty = val;
                          selectedDepartment = "Hepsi";
                        }),
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      selectedDepartment == "Hepsi"
                          ? "Bölüm"
                          : (selectedDepartment.length > 13
                                ? "${selectedDepartment.substring(0, 13)}..."
                                : selectedDepartment),
                      selectedDepartment != "Hepsi",
                      hasDropdown: true,
                      onTap: () => _showSearchableSelector(
                        context: context,
                        title: "Bölüm Seç",
                        items: departments,
                        selected: selectedDepartment,
                        onSelected: (val) =>
                            setState(() => selectedDepartment = val),
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      selectedCourse == "Hepsi"
                          ? "Ders"
                          : (selectedCourse.length > 10
                                ? "${selectedCourse.substring(0, 10)}..."
                                : selectedCourse),
                      selectedCourse != "Hepsi",
                      hasDropdown: true,
                      onTap: () => _showSearchableSelector(
                        context: context,
                        title: "Ders Seç",
                        items: courses,
                        selected: selectedCourse,
                        onSelected: (val) =>
                            setState(() => selectedCourse = val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- NOTES LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: notesQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Hata: ${snapshot.error}",
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snapshot.data?.docs ?? [];

              if (_searchText.isNotEmpty) {
                docs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = (data['title'] ?? '').toString().toLowerCase();
                  String desc = (data['content'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_searchText) ||
                      desc.contains(_searchText);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "Buna uygun not bulunamadı.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return _buildStitchNoteCard(data, docs[index].id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected, {
    bool hasDropdown = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.glass,
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textBody,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (hasDropdown) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.textBody,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStitchNoteCard(Map<String, dynamic> data, String noteId) {
    final List<dynamic> likedBy = data['likedBy'] ?? [];
    final List<dynamic> savedBy = data['savedBy'] ?? [];
    final bool isLiked = likedBy.contains(currentUser?.uid);
    final bool isSaved = savedBy.contains(currentUser?.uid);
    final int likes = data['likes'] ?? 0;
    final int commentsCount = data['commentsCount'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteDetailView(
              noteId: noteId,
              data: data,
              currentUserEmail: currentUser?.email,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppColors.glassBlur,
              sigmaY: AppColors.glassBlur,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildNoteCardHeader(data),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? "Başlıksız",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeader,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if ((data['course'] ?? '').toString().isNotEmpty ||
                            (data['content'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "${data['course'] ?? ''} ${(data['course'] ?? '').toString().isNotEmpty && (data['content'] ?? '').toString().isNotEmpty ? '·' : ''} ${data['content'] ?? ''}"
                                  .trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textBody,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // File Preview
                  if (data['fileUrl'] != null) ...[
                    const SizedBox(height: 12),
                    if (data['fileType'] == 'image')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['fileUrl'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (data['fileType'] == 'pdf')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppColors.error,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  data['fileName'] ?? 'Dökümanı Görüntüle',
                                  style: TextStyle(
                                    color: AppColors.textHeader,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // Footer / Action Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(noteId, likedBy),
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isLiked
                                    ? AppColors.error
                                    : AppColors.textTertiary,
                                size: 22,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "$likes",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "$commentsCount",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _toggleSave(noteId, savedBy),
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCardHeader(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final userEmail = data['userEmail'] as String?;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchNoteUserData(userId, userEmail),
      builder: (context, snapshot) {
        final userData = snapshot.data;
        final photoUrl = userData?['photoUrl'] ?? data['userImage'];
        final badge = VerifiedBadge.fromUserData(userData, size: 16);
        final foundUserId = userData?['uid'] ?? userId;

        final isOwnNote = foundUserId == currentUser?.uid;

        return Row(
          children: [
            PreviewableProfileAvatar(
              imageUrl: photoUrl?.toString(),
              radius: 20,
              backgroundColor: AppColors.surfaceSecondary,
              placeholder: Icon(
                Icons.person,
                color: AppColors.textTertiary,
                size: 20,
              ),
              onTap: () => _navigateToNoteUser(foundUserId, userEmail),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToNoteUser(foundUserId, userEmail),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            data['userName'] ?? "İsimsiz",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textHeader,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[const SizedBox(width: 4), badge],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${_formatDate(data['createdAt'] as Timestamp?).isNotEmpty ? _formatDate(data['createdAt'] as Timestamp?) : 'Tarih Bilinmiyor'} • ${data['department'] ?? 'Genel'}",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Takip Et butonu
            if (!isOwnNote && foundUserId != null)
              _NoteFollowButton(
                currentUserId: currentUser!.uid,
                targetUserId: foundUserId!,
              ),
          ],
        );
      },
    );
  }

  final Map<String, Map<String, dynamic>?> _noteUserCache = {};

  Future<Map<String, dynamic>?> _fetchNoteUserData(
    String? userId,
    String? userEmail,
  ) async {
    final cacheKey = userId ?? userEmail ?? '';
    if (cacheKey.isEmpty) return null;
    if (_noteUserCache.containsKey(cacheKey)) return _noteUserCache[cacheKey];

    try {
      if (userId != null && userId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (doc.exists) {
          _noteUserCache[cacheKey] = doc.data();
          return doc.data();
        }
      }
      if (userEmail != null && userEmail.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          data['uid'] = snap.docs.first.id;
          _noteUserCache[cacheKey] = data;
          return data;
        }
      }
    } catch (_) {}
    _noteUserCache[cacheKey] = null;
    return null;
  }

  void _navigateToNoteUser(String? userId, String? userEmail) async {
    String? uid = userId;
    if ((uid == null || uid.isEmpty) && userEmail != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) uid = snap.docs.first.id;
    }
    if (uid != null && uid.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileView(userId: uid!)),
      );
    }
  }

  // ==========================================
  // --- 1. SEKME: CHAT (Kampüs Sohbet) ---
  // ==========================================
  // ignore: unused_element
  Widget _buildChatPage() {
    return Column(
      children: [
        // --- CUSTOM APP BAR ---
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              IconButton(onPressed: () {}, icon: Icon(Icons.arrow_back)),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kampüs Sohbet",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeader,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleChatSearch,
                icon: Icon(
                  _isChatSearching ? Icons.close_rounded : Icons.search,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _handleChatMenuAction,
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'latest',
                    child: Text('En Son Mesaja Git'),
                  ),
                  PopupMenuItem<String>(
                    value: 'mark_seen',
                    child: Text('Cevap Bildirimlerini Temizle'),
                  ),
                  PopupMenuItem<String>(
                    value: 'clear_search',
                    child: Text('Aramayi Temizle'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
        if (_isChatSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: TextField(
                controller: _chatSearchController,
                decoration: const InputDecoration(
                  hintText: "Mesajlarda ara...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

        Expanded(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: currentUser == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .get(),
            builder: (context, userSnap) {
              if (currentUser == null) {
                return const Center(child: Text('Sohbet için giriş yapın.'));
              }
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userSnap.hasData || !userSnap.data!.exists) {
                return const Center(
                  child: Text('Kullanıcı bilgisi bulunamadı.'),
                );
              }

              final userData = userSnap.data!.data() ?? <String, dynamic>{};
              final bool isAdmin = userData['role'] == 'admin';
              final Timestamp? approvedAt =
                  userData['approvedAt'] as Timestamp?;
              final Timestamp? createdAt = userData['createdAt'] as Timestamp?;
              final DateTime chatStartAt = isAdmin
                  ? DateTime.fromMillisecondsSinceEpoch(0)
                  : (approvedAt?.toDate() ??
                        createdAt?.toDate() ??
                        DateTime.now());

              final Query messageQuery = FirebaseFirestore.instance
                  .collection('messages')
                  .where(
                    'createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(chatStartAt),
                  )
                  .orderBy('createdAt', descending: true);

              return StreamBuilder<QuerySnapshot>(
                stream: messageQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "Sohbet yüklenemedi: ${snapshot.error}\n\nEğer indeksi henüz oluşturmadıysanız, loglardaki linke tıklayarak oluşturun.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final List<QueryDocumentSnapshot> filteredDocs;
                  if (_chatSearchQuery.isEmpty) {
                    filteredDocs = docs;
                  } else {
                    filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final text = (data['text'] ?? '')
                          .toString()
                          .toLowerCase();
                      final sender = (data['senderName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final replyText = (data['replyToText'] ?? '')
                          .toString()
                          .toLowerCase();
                      return text.contains(_chatSearchQuery) ||
                          sender.contains(_chatSearchQuery) ||
                          replyText.contains(_chatSearchQuery);
                    }).toList();
                  }

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        _chatSearchQuery.isEmpty
                            ? "Henüz mesaj yok."
                            : "\"$_chatSearchQuery\" için mesaj bulunamadı.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _chatScrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          filteredDocs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderEmail'] == currentUser?.email;
                      final t = data['createdAt'] as Timestamp?;
                      final messageDate = (t?.toDate() ?? DateTime.now());
                      final shouldShowDate = index == filteredDocs.length - 1
                          ? true
                          : !_isSameDay(
                              messageDate,
                              ((filteredDocs[index + 1].data()
                                              as Map<
                                                String,
                                                dynamic
                                              >)['createdAt']
                                          as Timestamp?)
                                      ?.toDate() ??
                                  DateTime.now(),
                            );
                      final timeStr = t != null
                          ? DateFormat('HH:mm').format(t.toDate())
                          : "";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (shouldShowDate)
                            _buildChatDateSeparator(
                              _chatDateLabel(messageDate),
                            ),
                          _buildStitchChatBubble(
                            messageId: filteredDocs[index].id,
                            data: data,
                            isMe: isMe,
                            timeStr: timeStr,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // --- INPUT BAR ---
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: true,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _replyToMessageId == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('reply_preview'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _replyToSender ?? "Öğrenci",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyToText ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textBody,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _clearReplyTarget,
                                  icon: const Icon(Icons.close, size: 18),
                                  splashRadius: 18,
                                ),
                              ],
                            ),
                          ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: const InputDecoration(
                            hintText: "Mesaj yazın...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchChatBubble({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
    required String timeStr,
  }) {
    final String sender = data['senderName'] ?? "Öğrenci";
    final String msg = data['text'] ?? "";
    final String senderEmail = (data['senderEmail'] ?? '').toString();
    final String? replyToText = data['replyToText']?.toString();
    final String? replyToSender = data['replyToSender']?.toString();

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              GestureDetector(
                onTap: () => _showUserProfileBottomSheet(
                  senderEmail.isNotEmpty ? senderEmail : sender,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: (data['senderImage'] != null)
                      ? NetworkImage(data['senderImage'])
                      : null,
                  backgroundColor: AppColors.primaryLight,
                  child: (data['senderImage'] == null)
                      ? Icon(Icons.person, size: 18, color: AppColors.primary)
                      : null,
                ),
              ),
              SizedBox(width: 8),
            ],
            Flexible(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 250) {
                    _setReplyTarget(
                      messageId: messageId,
                      senderName: sender,
                      senderEmail: senderEmail,
                      text: msg,
                    );
                  }
                },
                onLongPressStart: (details) {
                  _showMessageActions(
                    globalPosition: details.globalPosition,
                    messageId: messageId,
                    data: data,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replyToText != null && replyToText.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.14)
                                : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: isMe
                                    ? Colors.white70
                                    : AppColors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyToSender ?? "Öğrenci",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyToText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : AppColors.textBody,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!isMe)
                        Text(
                          sender,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (!isMe) SizedBox(height: 4),
                      Text(
                        msg,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textHeader,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 4),
                            Icon(
                              Icons.done_all_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isMe) ...[
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showUserProfileBottomSheet(
                  senderEmail.isNotEmpty ? senderEmail : sender,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: (data['senderImage'] != null)
                      ? NetworkImage(data['senderImage'])
                      : null,
                  backgroundColor: AppColors.primaryLight,
                  child: (data['senderImage'] == null)
                      ? Icon(Icons.person, size: 18, color: AppColors.primary)
                      : null,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _chatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(target, today)) return 'BUGÜN';
    if (_isSameDay(target, yesterday)) return 'DÜN';
    return DateFormat('dd.MM.yyyy').format(target);
  }

  Widget _buildChatDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- 2. SEKME: ANA SAYFA ---
  // ==========================================
  // ─── ANA SAYFA ARAMA METOTLARI ───
  Future<void> _performHomeSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchUsers = [];
        _searchNotes = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final q = query.trim().toLowerCase();

    // Kullanıcı araması (nick ve isim ile, admin dahil)
    final userSnap = await FirebaseFirestore.instance.collection('users').get();
    final users = userSnap.docs
        .map((d) => {'uid': d.id, ...d.data()})
        .where(
          (u) =>
              u['uid'] != currentUser?.uid &&
              (u['isApproved'] == true || u['role'] == 'admin') &&
              ((u['nick'] ?? '').toString().toLowerCase().contains(q) ||
                  (u['name'] ?? '').toString().toLowerCase().contains(q)),
        )
        .toList();

    // Not araması (başlık, ders, fakülte, bölüm)
    final noteSnap = await FirebaseFirestore.instance
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .get();
    final notes = noteSnap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where(
          (n) =>
              (n['title'] ?? '').toString().toLowerCase().contains(q) ||
              (n['course'] ?? '').toString().toLowerCase().contains(q) ||
              (n['faculty'] ?? '').toString().toLowerCase().contains(q) ||
              (n['department'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();

    setState(() {
      _searchUsers = users;
      _searchNotes = notes;
      _isSearching = false;
    });
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: TextField(
                controller: _homeSearchController,
                onChanged: (val) {
                  setState(() => _homeSearchQuery = val);
                  _performHomeSearch(val);
                },
                decoration: InputDecoration(
                  hintText: "Kullanıcı veya not ara...",
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  suffixIcon: _homeSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textTertiary,
                            size: 18,
                          ),
                          onPressed: () {
                            _homeSearchController.clear();
                            setState(() {
                              _homeSearchQuery = '';
                              _searchUsers = [];
                              _searchNotes = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
        if (!_isSearching && _homeSearchQuery.isNotEmpty) _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchResults() {
    final hasUsers = _searchUsers.isNotEmpty;
    final hasNotes = _searchNotes.isNotEmpty;

    if (!hasUsers && !hasNotes) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Text(
            "Sonuç bulunamadı",
            style: TextStyle(color: AppColors.textBody),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Users
          if (hasUsers) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                "Kullanıcılar",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textBody,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ..._searchUsers.map((u) {
              final nick = u['nick']?.toString() ?? 'Kullanıcı';
              final name = u['name']?.toString() ?? '';
              final otherUid = u['uid']?.toString() ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage:
                      (u['photoUrl'] != null &&
                          u['photoUrl'].toString().isNotEmpty)
                      ? NetworkImage(u['photoUrl'])
                      : null,
                  child:
                      (u['photoUrl'] == null ||
                          u['photoUrl'].toString().isEmpty)
                      ? Icon(Icons.person, color: AppColors.primary, size: 20)
                      : null,
                ),
                title: Text(
                  "@$nick",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                    fontSize: 14,
                  ),
                ),
                subtitle: name.isNotEmpty
                    ? Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textBody,
                        ),
                      )
                    : null,
                trailing: currentUser != null && otherUid.isNotEmpty
                    ? _buildFollowButton(otherUid, u)
                    : null,
                onTap: () {
                  if (otherUid.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileView(userId: otherUid),
                      ),
                    );
                    return;
                  }
                  _showUserProfileBottomSheet(nick);
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              );
            }),
            if (hasNotes) const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          // Notes
          if (hasNotes) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                "Notlar",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textBody,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ..._searchNotes.map((n) {
              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  n['title']?.toString() ?? 'Başlıksız Not',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "${n['faculty'] ?? ''} • ${n['department'] ?? ''} • ${n['course'] ?? ''}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textBody),
                ),
                onTap: () {
                  final noteId = n['id']?.toString() ?? '';
                  // Clear search first
                  _homeSearchController.clear();
                  setState(() {
                    _homeSearchQuery = '';
                    _searchUsers = [];
                    _searchNotes = [];
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteDetailView(
                        noteId: noteId,
                        data: n,
                        currentUserEmail: currentUser?.email,
                      ),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(String otherUid, Map<String, dynamic> otherUser) {
    final friendshipService = FriendshipService();
    return StreamBuilder<DocumentSnapshot>(
      stream: friendshipService.watchFriendship(currentUser!.uid, otherUid),
      builder: (context, snap) {
        final exists = snap.data?.exists ?? false;
        final data = exists ? snap.data!.data() as Map<String, dynamic>? : null;
        final status = data?['status'] ?? '';

        if (status == 'accepted') {
          return SizedBox(
            height: 32,
            child: TextButton.icon(
              onPressed: null,
              icon: Icon(Icons.check, size: 16, color: AppColors.success),
              label: Text(
                'Takip',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          );
        }

        if (status == 'pending') {
          final isRequester = data?['requesterId'] == currentUser!.uid;
          return SizedBox(
            height: 32,
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                isRequester ? 'İstek Gönderildi' : 'Bekliyor',
                style: TextStyle(fontSize: 12, color: AppColors.textBody),
              ),
            ),
          );
        }

        return SizedBox(
          height: 32,
          child: ElevatedButton(
            onPressed: () => _handleFollow(otherUid, otherUser),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: Text('Takip Et'),
          ),
        );
      },
    );
  }

  Future<void> _handleFollow(
    String otherUid,
    Map<String, dynamic> otherUser,
  ) async {
    if (currentUser == null) return;
    final friendshipService = FriendshipService();

    // Kullanıcı bilgilerini al
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final myData = myDoc.data() ?? {};

    // Takip isteği gönder (direkt kabul et - takip sistemi)
    final id = friendshipService.getFriendshipId(currentUser!.uid, otherUid);
    await FirebaseFirestore.instance.collection('friendships').doc(id).set({
      'requesterId': currentUser!.uid,
      'receiverId': otherUid,
      'requesterName': myData['nick'] ?? myData['name'] ?? '',
      'receiverName': otherUser['nick'] ?? otherUser['name'] ?? '',
      'requesterPhoto': myData['photoUrl'],
      'receiverPhoto': otherUser['photoUrl'],
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Bildirim oluştur
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'follow',
      'fromUid': currentUser!.uid,
      'fromName': myData['nick'] ?? myData['name'] ?? '',
      'fromPhoto': myData['photoUrl'],
      'toUid': otherUid,
      'message':
          '${myData['nick'] ?? myData['name'] ?? 'Birisi'} seni takip etmeye başladı',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${otherUser['nick'] ?? otherUser['name']} takip edildi!',
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildHomePage() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        // Update class-level nick so it can be used by the FAB
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && userData?['nick'] != _userNick) {
            setState(() {
              _userNick = userData?['nick'];
            });
          }
        });

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hoşgeldin Başlığı
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hoş Geldin 👋",
                          style: TextStyle(
                            color: AppColors.textBody,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userData?['nick'] ??
                              currentUser?.displayName?.split(' ').first ??
                              'Öğrenci',
                          style: TextStyle(
                            color: AppColors.textHeader,
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const WeatherDetailView(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.05),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glass,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.glassBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _weatherIcon,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _weatherTemp,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHeader,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── ARAMA ÇUBUĞU ───
              _buildSearchBar(),
              const SizedBox(height: 28),

              // SLIDER ALANI (ÖNE ÇIKANLAR)
              if (_homeSearchQuery.isEmpty)
                Text(
                  "Öne Çıkanlar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeader,
                    letterSpacing: -0.3,
                  ),
                ),
              if (_homeSearchQuery.isEmpty) ...[
                const SizedBox(height: 12),
                _buildSliderSection(),

                const SizedBox(height: 28),

                // FIRSATLAR VE DUYURULAR
                Text(
                  "Fırsatlar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeader,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                _buildOpportunitiesSection(AppColors.isDark),

                const SizedBox(height: 32),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return data['type'] == 'slider';
        }).toList();

        if (docs.isEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    "Şu an öne çıkan bir içerik yok",
                    style: TextStyle(
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: docs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailView(data: data),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowMedium,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: DecorationImage(
                      image: NetworkImage(data['imageUrl'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    padding: EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (data['description'] != null &&
                              data['description'].toString().isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                data['description'] ?? '',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOpportunitiesSection(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        }
        if (!snapshot.hasData) return SizedBox();
        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return data['type'] == 'opportunity';
        }).toList();

        if (docs.isEmpty) {
          return Text(
            "Şu an aktif fırsat bulunmuyor.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnnouncementDetailView(data: data),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppColors.glassBlur,
                      sigmaY: AppColors.glassBlur,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['imageUrl'] ?? '',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                        title: Text(
                          data['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeader,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          data['description'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Tool metadata: accent color + description per tool
  static final Map<String, _ToolMeta> _toolMeta = {
    'Liderlik Tablosu': _ToolMeta(
      const Color(0xFF1565C0),
      const Color(0xFF29B6F6),
      'En aktif öğrencileri gör',
    ),
    'Akademik Takvim': _ToolMeta(
      const Color(0xFF0288D1),
      const Color(0xFF26C6DA),
      'Sınav ve ders tarihleri',
    ),
    'Yemekhane': _ToolMeta(
      const Color(0xFF00838F),
      const Color(0xFF4DD0E1),
      'Günlük menüyü incele',
    ),
    'İnteraktif Harita': _ToolMeta(
      const Color(0xFF0277BD),
      const Color(0xFF00BCD4),
      'Kampüste yolunu bul',
    ),
    'Etkinlik Takvimi': _ToolMeta(
      const Color(0xFF0097A7),
      const Color(0xFF4DB6AC),
      'Etkinlikleri takip et',
    ),
    'Yapay Zeka': _ToolMeta(
      const Color(0xFF00ACC1),
      const Color(0xFF69F0AE),
      'AI ile sohbet et',
    ),
    'K-Bot': _ToolMeta(
      const Color(0xFF0F274A),
      const Color(0xFF1DA1F2),
      'Premium PDF ve fotoğraf özeti',
    ),
  };

  Widget _buildToolCard(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? badgeText,
    bool isLocked = false,
  }) {
    final meta =
        _toolMeta[title] ?? _ToolMeta(AppColors.primary, AppColors.primary, '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: meta.color1.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [meta.color1, meta.color2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: meta.color1.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (badgeText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? AppColors.textTertiary.withValues(alpha: 0.12)
                        : meta.color1.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isLocked
                          ? AppColors.textTertiary.withValues(alpha: 0.18)
                          : meta.color1.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLocked ? Icons.lock_outline : Icons.workspace_premium,
                        size: 13,
                        color: isLocked ? AppColors.textTertiary : meta.color1,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isLocked
                              ? AppColors.textTertiary
                              : meta.color1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textHeader,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (meta.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  meta.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- 3. SEKME: ARAÇLAR (LİDERLİK BURADA!) ---
  // ==========================================

  // İkon adı (String) ile gerçek IconData'yı eşleştiren yardımcı fonksiyon
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'how_to_vote':
        return Icons.how_to_vote;
      case 'smart_toy':
        return Icons.smart_toy;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'calendar_month':
        return Icons.calendar_month;
      case 'event_note':
        return Icons.event_note;
      case 'event_available':
        return Icons.event_available;
      case 'map':
        return Icons.map;
      case 'manage_search':
        return Icons.manage_search;
      case 'build':
        return Icons.build;
      case 'restaurant':
        return Icons.restaurant;
      case 'school':
        return Icons.school;
      case 'library_books':
        return Icons.library_books;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'wifi':
        return Icons.wifi;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.widgets; // Varsayılan ikon
    }
  }

  void _showPremiumToolSheet(String toolTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DA1F2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF1DA1F2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$toolTitle premium aracı',
                        style: TextStyle(
                          color: AppColors.textHeader,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bu aracı kullanmak için premium plan gerekiyor. Premium ile mavi tik, PDF özeti ve yeni AI özellikleri açılır.',
                  style: TextStyle(
                    color: AppColors.textBody,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPremiumView();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DA1F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Premiuma git',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildToolsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Araçlar",
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Kampüs hayatını kolaylaştır",
                      style: TextStyle(color: AppColors.textBody, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tools')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Hata: ${snapshot.error}",
                    style: TextStyle(color: AppColors.textBody),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final toolItems = (snapshot.data?.docs ?? [])
                  .map(
                    (doc) => Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();

              final hasKBot = toolItems.any((tool) => tool['title'] == 'K-Bot');
              if (!hasKBot) {
                toolItems.add({
                  'title': 'K-Bot',
                  'iconName': 'auto_awesome',
                  'order': 999,
                  'isActive': true,
                });
              }

              toolItems.sort((a, b) {
                final left = (a['order'] as num?)?.toInt() ?? 0;
                final right = (b['order'] as num?)?.toInt() ?? 0;
                return left.compareTo(right);
              });

              if (toolItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.widgets_outlined,
                        size: 64,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Aktif bir araç bulunamadı.",
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                itemCount: toolItems.length,
                itemBuilder: (context, index) {
                  final tool = toolItems[index];
                  String title = tool['title'] ?? 'Bilinmeyen';
                  String iconName = tool['iconName'] ?? 'widgets';
                  IconData iconData = _getIconData(iconName);
                  final isPremiumTool = title == 'K-Bot';

                  return _buildToolCard(title, iconData, () async {
                    if (isPremiumTool) {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser!.uid)
                          .get();
                      final userData = userDoc.data();
                      final hasPremiumAccess =
                          _isPremiumUserData(userData) ||
                          userData?['role'] == 'admin';
                      if (!hasPremiumAccess) {
                        if (!mounted) return;
                        _showPremiumToolSheet(title);
                        return;
                      }
                    }

                    Widget? targetPage;
                    if (title == "Liderlik Tablosu") {
                      targetPage = LeaderboardView(
                        kPrimaryColor: AppColors.primary,
                      );
                    } else if (title == "Akademik Takvim") {
                      targetPage = AcademicCalendarView(
                        kPrimaryColor: AppColors.primary,
                      );
                    } else if (title == "Yemekhane") {
                      targetPage = CafeteriaView(
                        kPrimaryColor: AppColors.primary,
                      );
                    } else if (title == "İnteraktif Harita") {
                      targetPage = CampusMapView(
                        kPrimaryColor: AppColors.primary,
                      );
                    } else if (title == "Etkinlik Takvimi") {
                      targetPage = EventCalendarView(
                        kPrimaryColor: AppColors.primary,
                      );
                    } else if (title == "Yapay Zeka") {
                      targetPage = AiChatView(kPrimaryColor: AppColors.primary);
                    } else if (title == "K-Bot") {
                      targetPage = KBotView(kPrimaryColor: AppColors.primary);
                    }

                    if (targetPage != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => targetPage!),
                      );
                    }
                  }, badgeText: isPremiumTool ? 'PREMIUM' : null);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- 4. SEKME: PROFİL & AYARLAR ---
  // ==========================================
  Widget _buildProfilePage() {
    final PostService profilePostService = PostService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        String name =
            userData?['nick'] ??
            userData?['name'] ??
            currentUser?.displayName ??
            "Kullanıcı";
        String fullName =
            userData?['name'] ?? currentUser?.displayName ?? "Kullanıcı";
        String email = currentUser?.email ?? "";

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              pinned: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeader,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (VerifiedBadge.fromUserData(userData) != null) ...[
                    const SizedBox(width: 5),
                    VerifiedBadge.fromUserData(userData, size: 18)!,
                  ],
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => _showProfileVisitorsSheet(),
                  icon: Icon(
                    Icons.visibility_outlined,
                    color: AppColors.textHeader,
                  ),
                  tooltip: "Profil Ziyaretçileri",
                ),
                IconButton(
                  onPressed: _showGeneralSettingsSheet,
                  icon: Icon(Icons.menu_rounded, color: AppColors.textHeader),
                  tooltip: "Ayarlar",
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Avatar + Stats Row (Instagram style) ───
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showProfilePhotoOptions(),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: AppColors.primaryLight,
                                backgroundImage: userData?['photoUrl'] != null
                                    ? NetworkImage(userData!['photoUrl'])
                                    : null,
                                child: userData?['photoUrl'] == null
                                    ? Icon(
                                        avatarIcons[(userData?['avatarIndex']
                                                is int)
                                            ? userData!['avatarIndex']
                                            : 0],
                                        size: 42,
                                        color: AppColors.primary,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Gönderi sayısı
                              StreamBuilder<QuerySnapshot>(
                                stream: profilePostService.getUserPosts(
                                  currentUser!.uid,
                                ),
                                builder: (ctx, snap) => _buildInstagramStat(
                                  '${snap.data?.docs.length ?? 0}',
                                  'Gönderi',
                                ),
                              ),
                              // Takipçi sayısı (arkadaşlarım — iki yönlü)
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('friendships')
                                    .where(
                                      'receiverId',
                                      isEqualTo: currentUser!.uid,
                                    )
                                    .where('status', isEqualTo: 'accepted')
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final count1 = snap.data?.docs.length ?? 0;
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('friendships')
                                        .where(
                                          'requesterId',
                                          isEqualTo: currentUser!.uid,
                                        )
                                        .where('status', isEqualTo: 'accepted')
                                        .snapshots(),
                                    builder: (ctx2, snap2) {
                                      final total =
                                          count1 +
                                          (snap2.data?.docs.length ?? 0);
                                      return _buildInstagramStat(
                                        '$total',
                                        'Takipçi',
                                      );
                                    },
                                  );
                                },
                              ),
                              // Takip sayısı (arkadaşlarım — iki yönlü)
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('friendships')
                                    .where(
                                      'requesterId',
                                      isEqualTo: currentUser!.uid,
                                    )
                                    .where('status', isEqualTo: 'accepted')
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final count1 = snap.data?.docs.length ?? 0;
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('friendships')
                                        .where(
                                          'receiverId',
                                          isEqualTo: currentUser!.uid,
                                        )
                                        .where('status', isEqualTo: 'accepted')
                                        .snapshots(),
                                    builder: (ctx2, snap2) {
                                      final total =
                                          count1 +
                                          (snap2.data?.docs.length ?? 0);
                                      return _buildInstagramStat(
                                        '$total',
                                        'Takip',
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ─── İsim + Tik ───
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textHeader,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (VerifiedBadge.fromUserData(userData) != null) ...[
                          const SizedBox(width: 4),
                          VerifiedBadge.fromUserData(userData)!,
                        ],
                      ],
                    ),

                    // ─── Bio ───
                    if ((userData?['bio'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          userData!['bio'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textBody,
                            height: 1.4,
                          ),
                        ),
                      ),

                    // ─── Sosyal Medya Linkleri ───
                    if (_hasSocialLinksData(userData?['socialLinks']))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final platform in const [
                              'instagram',
                              'linkedin',
                              'x',
                              'tiktok',
                              'snapchat',
                              'facebook',
                            ])
                              if (_socialValue(
                                userData?['socialLinks'],
                                platform,
                              ).isNotEmpty)
                                _buildSocialIcon(
                                  platform,
                                  _buildSocialUrl(
                                    _socialValue(
                                      userData?['socialLinks'],
                                      platform,
                                    ),
                                    platform,
                                  ),
                                ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ─── Beğeni & Not İstatistikleri ───
                    Row(
                      children: [
                        // Toplam beğeni (notlardan)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notes')
                              .where('userEmail', isEqualTo: email)
                              .snapshots(),
                          builder: (ctx, snap) {
                            int totalLikes = 0;
                            for (final doc in snap.data?.docs ?? []) {
                              final d = doc.data() as Map<String, dynamic>;
                              totalLikes += (d['likes'] ?? 0) as int;
                            }
                            return Row(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalLikes beğeni',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textBody,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        // Paylaşılan not sayısı
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notes')
                              .where('userEmail', isEqualTo: email)
                              .snapshots(),
                          builder: (ctx, snap) {
                            return Row(
                              children: [
                                Icon(
                                  Icons.description_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${snap.data?.docs.length ?? 0} not',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textBody,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ─── Profili Düzenle + Ayarlar Butonları ───
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () => _showEditProfileDialog(
                                userData?['bio']?.toString() ?? "",
                                (userData?['avatarIndex'] is int)
                                    ? userData!['avatarIndex']
                                    : 0,
                                _safeStringDynamicMap(userData?['socialLinks']),
                                currentNick:
                                    userData?['nick']?.toString() ?? '',
                                nickLastChangedAt: _safeTimestamp(
                                  userData?['nickLastChangedAt'],
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textHeader,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Profili Düzenle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SavedPostsView(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHeader,
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    _buildPremiumUpsellCard(userData),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Divider(color: AppColors.divider, height: 1),
            ),
            // Gönderi grid tab bar
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.background,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textHeader,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons.grid_on_rounded,
                    color: AppColors.textHeader,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
          body: _buildProfilePostsGrid(profilePostService),
        );
      },
    );
  }

  Widget _buildInstagramStat(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textHeader,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textBody)),
      ],
    );
  }

  bool _isPremiumUserData(Map<String, dynamic>? userData) {
    return userData?['isPremium'] == true ||
        userData?['premiumStatus'] == 'active';
  }

  void _openPremiumView() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumView()),
    );
  }

  Widget _buildPremiumUpsellCard(Map<String, dynamic>? userData) {
    final isPremium = _isPremiumUserData(userData);
    final isAdmin = userData?['role'] == 'admin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF0F274A), const Color(0xFF1D4E89)]
              : [
                  const Color(0xFF1DA1F2).withValues(alpha: 0.16),
                  const Color(0xFF1DA1F2).withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremium
              ? const Color(0xFF1DA1F2).withValues(alpha: 0.35)
              : const Color(0xFF1DA1F2).withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isPremium
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFF1DA1F2).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: isPremium ? Colors.white : const Color(0xFF1DA1F2),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isPremium
                            ? 'Premium hesabın aktif'
                            : 'Premium öğrenci planı',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isPremium
                              ? Colors.white
                              : AppColors.textHeader,
                        ),
                      ),
                    ),
                    if (!isAdmin && VerifiedBadge.hasBlueBadge(userData)) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(type: 'verified', size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Mavi tik tanımlandı. Profil ziyaretçilerinin tamamı ve premium altyapın hazır.'
                      : 'Premium ile mavi tik al, tüm profil ziyaretçilerini gör ve ileride gelecek ekstra özellikleri aç.',
                  style: TextStyle(
                    color: isPremium
                        ? Colors.white.withValues(alpha: 0.88)
                        : AppColors.textBody,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _openPremiumView,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.white : AppColors.primary,
              foregroundColor: isPremium
                  ? const Color(0xFF12315A)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              isPremium ? 'Yönet' : 'Al',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePostsGrid(PostService postService) {
    return StreamBuilder<QuerySnapshot>(
      stream: postService.getUserPosts(currentUser!.uid),
      builder: (context, snapshot) {
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 56,
                  color: AppColors.border,
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz gönderi yok',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'İlk gönderini paylaş!',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data = posts[index].data() as Map<String, dynamic>;
            final mediaUrls = data['mediaUrls'] != null
                ? List<String>.from(data['mediaUrls'])
                : [data['imageUrl'] ?? ''];
            final hasMultiple = mediaUrls.length > 1;
            final isVideo = data['isVideo'] == true;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePostsScrollView(
                    userId: currentUser!.uid,
                    posts: posts,
                    initialIndex: index,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      color: AppColors.background,
                      child: Icon(Icons.broken_image, color: AppColors.border),
                    ),
                  ),
                  if (hasMultiple)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.collections_rounded,
                        color: Colors.white,
                        size: 18,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  if (isVideo)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 20,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGeneralSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    "Ayarlar",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeader,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsCard([
                    if (widget.isAdmin)
                      _buildSettingsItem(
                        Icons.admin_panel_settings_rounded,
                        "Admin Paneli",
                        () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminHomeView(),
                            ),
                          );
                        },
                        subtitle: "Uygulamayı yönet",
                      ),
                    _buildSettingsItem(
                      Icons.bookmark_rounded,
                      "Kaydedilen Gönderiler",
                      () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedPostsView(),
                          ),
                        );
                      },
                      subtitle: "Kaydettiğin gönderileri görüntüle",
                    ),
                    _buildSettingsSwitch(
                      Icons.dark_mode_rounded,
                      "Gece Modu",
                      AppColors.isDark,
                      (val) {
                        AppColors.toggleTheme();
                      },
                    ),
                    _buildSettingsItem(
                      Icons.description_rounded,
                      "Paylaştığım Notlar",
                      () {
                        Navigator.pop(ctx);
                        _showMyNotesBottomSheet();
                      },
                    ),
                    _buildSettingsItem(
                      Icons.bookmark_outline_rounded,
                      "Kaydettiğim Notlar",
                      () {
                        Navigator.pop(ctx);
                        _showSavedNotesBottomSheet();
                      },
                    ),
                    _buildSettingsItem(
                      Icons.support_agent_rounded,
                      "Destek Merkezi",
                      () {
                        Navigator.pop(ctx);
                        Future.delayed(const Duration(milliseconds: 180), () {
                          if (!mounted) return;
                          _showHelpAndSupportSheet();
                        });
                      },
                      subtitle: "Yardım, rehber ve iletişim",
                    ),
                    _buildSettingsItem(
                      Icons.logout_rounded,
                      "Çıkış Yap",
                      () async {
                        Navigator.pop(ctx);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('remember_me', false);
                        await prefs.remove('saved_email');
                        await _authService.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginView(),
                            ),
                          );
                        }
                      },
                      color: Colors.red,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@algow.net',
      queryParameters: {'subject': 'K-Hub Destek Talebi'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("E-posta uygulaması açılamadı.")),
    );
  }

  void _showHelpAndSupportSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    "Yardım ve Destek",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeader,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Destek için aşağıdaki iletişim bilgisini kullanabilirsin.",
                    style: TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 14),
                  _buildSettingsCard([
                    _buildSettingsItem(
                      Icons.email_outlined,
                      "Destek E-postası",
                      _sendSupportEmail,
                      subtitle: "info@algow.net",
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    "Hızlı Kullanım Rehberi",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeader,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildQuickGuideCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickGuideCard() {
    return _buildSettingsCard([
      _buildGuideStepItem(
        icon: Icons.home_rounded,
        title: "Ana Sayfa",
        description: "Duyurular, notlar ve önemli içerikleri buradan takip et.",
      ),
      _buildGuideStepItem(
        icon: Icons.add_circle_rounded,
        title: "Paylaşım Ekle",
        description: "Not veya gönderi paylaşmak için ekleme alanını kullan.",
      ),
      _buildGuideStepItem(
        icon: Icons.chat_bubble_rounded,
        title: "Mesajlar",
        description: "Arkadaşlarınla mesajlaş ve kampüs sohbetlerini takip et.",
      ),
      _buildGuideStepItem(
        icon: Icons.search_rounded,
        title: "Arama ve Filtre",
        description: "Üstteki arama ile içerikleri hızlıca bul.",
      ),
      _buildGuideStepItem(
        icon: Icons.person_rounded,
        title: "Profil ve Ayarlar",
        description: "Profilini düzenle, tema ve hesap ayarlarını yönet.",
      ),
    ]);
  }

  Widget _buildGuideStepItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: AppColors.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.textHeader,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlur,
          sigmaY: AppColors.glassBlur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (i) {
              if (i.isOdd)
                return Divider(
                  height: 0.5,
                  indent: 52,
                  color: AppColors.glassBorder,
                );
              return children[i ~/ 2];
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color ?? AppColors.textHeader,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSwitch(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textHeader,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _showMyNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Paylaştığım Notlar",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeader,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notes')
                    .where('userEmail', isEqualTo: currentUser?.email)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz bir not paylaşmadın.",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var note = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        child: ListTile(
                          title: Text(
                            note['title'] ?? "",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(note['course'] ?? ""),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_rounded, color: Colors.red),
                            onPressed: () => FirebaseFirestore.instance
                                .collection('notes')
                                .doc(docs[index].id)
                                .delete(),
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
      ),
    );
  }

  void _showSavedNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Kaydettiğim Notlar",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeader,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notes')
                    .where('savedBy', arrayContains: currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz bir not kaydetmedin.",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return _buildStitchNoteCard(data, docs[index].id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PROFİL FOTOĞRAFI SEÇENEK MENÜSÜ ---
  void _showProfilePhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "Profil Fotoğrafı",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.photo_library, color: AppColors.primary),
              ),
              title: Text("Galeriden Seç & Düzenle"),
              subtitle: Text(
                "Kırp, döndür, aynala",
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfilePhoto();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AFF0000),
                child: Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: Text(
                "Fotoğrafı Kaldır",
                style: TextStyle(color: Colors.red),
              ),
              subtitle: Text(
                "Varsayılan avatara dön",
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeProfilePhoto();
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- PROFİL FOTOĞRAFI YÜKLEME (EDİTÖRLÜ) ---
  Future<void> _pickAndUploadProfilePhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    // CROPER - kırp, döndür, aynala
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Düzenle',
          toolbarColor: Color(0xFF800000),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Color(0xFF800000),
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          showCropGrid: true,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );

    if (cropped == null) return; // Kullanıcı iptal etti

    final file = File(cropped.path);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Fotoğraf yükleniyor...")));

    final url = await _storageService.uploadProfilePhoto(
      file,
      currentUser!.uid,
    );
    if (url != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'photoUrl': url});
      // PP propagation — tüm koleksiyonlarda güncelle
      await _propagateProfilePhoto(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Profil fotoğrafı güncellendi!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // --- PROFİL FOTOĞRAFI KALDIRMA ---
  Future<void> _removeProfilePhoto() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .update({'photoUrl': FieldValue.delete()});
    // PP propagation — tüm koleksiyonlardan kaldır
    await _propagateProfilePhoto(null);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı kaldırıldı.")),
      );
    }
  }

  /// Profil fotoğrafı değiştiğinde tüm koleksiyonlarda güncelle
  Future<void> _propagateProfilePhoto(String? newUrl) async {
    final uid = currentUser!.uid;
    final email = currentUser!.email ?? '';
    final fs = FirebaseFirestore.instance;

    try {
      // 1. Posts — authorPhoto
      final posts = await fs
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .get();
      for (final doc in posts.docs) {
        await doc.reference.update({
          'authorPhoto': newUrl ?? FieldValue.delete(),
        });
      }

      // 2. Post comments — authorPhoto (subcollection)
      for (final postDoc in posts.docs) {
        final comments = await postDoc.reference
            .collection('comments')
            .where('authorId', isEqualTo: uid)
            .get();
        for (final c in comments.docs) {
          await c.reference.update({
            'authorPhoto': newUrl ?? FieldValue.delete(),
          });
        }
      }

      // 3. Stories — authorPhoto
      final stories = await fs
          .collection('stories')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in stories.docs) {
        await doc.reference.update({
          'authorPhoto': newUrl ?? FieldValue.delete(),
        });
      }

      // 4. Friendships — requester/receiver photo
      final friendsReq = await fs
          .collection('friendships')
          .where('requesterId', isEqualTo: uid)
          .get();
      for (final doc in friendsReq.docs) {
        await doc.reference.update({
          'requesterPhoto': newUrl ?? FieldValue.delete(),
        });
      }
      final friendsRec = await fs
          .collection('friendships')
          .where('receiverId', isEqualTo: uid)
          .get();
      for (final doc in friendsRec.docs) {
        await doc.reference.update({
          'receiverPhoto': newUrl ?? FieldValue.delete(),
        });
      }

      // 5. Notifications — fromUserPhoto
      final notifs = await fs
          .collection('notifications')
          .where('fromUserId', isEqualTo: uid)
          .get();
      for (final doc in notifs.docs) {
        await doc.reference.update({
          'fromUserPhoto': newUrl ?? FieldValue.delete(),
        });
      }

      // 6. Notes — userImage
      final notes = await fs
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in notes.docs) {
        await doc.reference.update({
          'userImage': newUrl ?? FieldValue.delete(),
        });
      }

      // 7. Campus chat messages — senderImage
      final msgs = await fs
          .collection('messages')
          .where('senderEmail', isEqualTo: email)
          .get();
      for (final doc in msgs.docs) {
        await doc.reference.update({
          'senderImage': newUrl ?? FieldValue.delete(),
        });
      }

      // 8. DM conversations — participantPhotos
      final convs = await fs
          .collection('conversations')
          .where('participantIds', arrayContains: uid)
          .get();
      for (final doc in convs.docs) {
        await doc.reference.update({
          'participantPhotos.$uid': newUrl ?? FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('PP propagation error: $e');
    }
  }

  // --- YARDIMCI METOTLAR ---

  void _showEditProfileDialog(
    String currentBio,
    int currentAvatarIndex,
    Map<String, dynamic> currentSocialLinks, {
    String currentNick = '',
    Timestamp? nickLastChangedAt,
  }) {
    TextEditingController bioController = TextEditingController(
      text: currentBio,
    );
    TextEditingController nickController = TextEditingController(
      text: currentNick,
    );
    String socialText(String key) => (currentSocialLinks[key] ?? '').toString();
    TextEditingController instagramController = TextEditingController(
      text: socialText('instagram'),
    );
    TextEditingController linkedinController = TextEditingController(
      text: socialText('linkedin'),
    );
    TextEditingController xController = TextEditingController(
      text: socialText('x').isNotEmpty
          ? socialText('x')
          : socialText('twitter'),
    );
    TextEditingController tiktokController = TextEditingController(
      text: socialText('tiktok'),
    );
    TextEditingController snapchatController = TextEditingController(
      text: socialText('snapchat'),
    );
    TextEditingController facebookController = TextEditingController(
      text: socialText('facebook'),
    );
    int selectedAvatarIndex = currentAvatarIndex;

    // Cooldown calculation
    final DateTime? lastChange = nickLastChangedAt?.toDate();
    final DateTime now = DateTime.now();
    final int daysLeft = lastChange == null
        ? 0
        : 15 - now.difference(lastChange).inDays;
    final bool nickLocked = daysLeft > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Profili Düzenle",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textHeader,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textBody),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Avatar Seçimi",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeader,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(
                            avatarIcons.length,
                            (index) => GestureDetector(
                              onTap: () => setModalState(
                                () => selectedAvatarIndex = index,
                              ),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedAvatarIndex == index
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: selectedAvatarIndex == index
                                      ? AppColors.primary
                                      : Colors.grey[200],
                                  child: Icon(
                                    avatarIcons[index],
                                    color: selectedAvatarIndex == index
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        // ─── Nick Alanı ───
                        Row(
                          children: [
                            Text(
                              "Kullanıcı Adı (Nick)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textHeader,
                              ),
                            ),
                            SizedBox(width: 8),
                            if (nickLocked)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "$daysLeft gün kaldı",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "Değiştirilebilir",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: nickController,
                          enabled: !nickLocked,
                          maxLength: 20,
                          decoration: InputDecoration(
                            hintText: nickLocked
                                ? "$daysLeft gün sonra değiştirebilirsiniz"
                                : "ahmet_42",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixText: "@",
                            prefixStyle: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            filled: true,
                            fillColor: nickLocked
                                ? Colors.grey.withValues(alpha: 0.07)
                                : AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          "Hakkımda (Bio)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeader,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: bioController,
                          maxLength: 150,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Kendinizden bahsedin...",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          "Sosyal Medya Bağlantıları",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeader,
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildSocialMediaField(
                          "Instagram Kullanıcı Adı veya URL",
                          "instagram",
                          instagramController,
                        ),
                        SizedBox(height: 12),
                        _buildSocialMediaField(
                          "LinkedIn Profil URL",
                          "linkedin",
                          linkedinController,
                        ),
                        SizedBox(height: 12),
                        _buildSocialMediaField(
                          "X (Twitter) Kullanıcı Adı veya URL",
                          "x",
                          xController,
                        ),
                        SizedBox(height: 12),
                        _buildSocialMediaField(
                          "TikTok Kullanıcı Adı veya URL",
                          "tiktok",
                          tiktokController,
                        ),
                        SizedBox(height: 12),
                        _buildSocialMediaField(
                          "Snapchat Kullanıcı Adı veya URL",
                          "snapchat",
                          snapchatController,
                        ),
                        SizedBox(height: 12),
                        _buildSocialMediaField(
                          "Facebook Kullanıcı Adı veya URL",
                          "facebook",
                          facebookController,
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              _saveProfileChanges(
                                currentUser!.uid,
                                nickController.text,
                                bioController.text,
                                selectedAvatarIndex,
                                instagramController.text,
                                linkedinController.text,
                                xController.text,
                                tiktokController.text,
                                snapchatController.text,
                                facebookController.text,
                                nickLocked: nickLocked,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: Text(
                              "Kaydet",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // ─── Hesabı Sil ───
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tehlikeli Bölge',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hesabınızı sildiğinizde tüm verileriniz (notlar, postlar, mesajlar, arkadaşlıklar) kalıcı olarak silinir ve geri alınamaz.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textBody,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showDeleteAccountDialog();
                                  },
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Hesabımı ve Tüm Verilerimi Sil',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(
                                      color: Colors.red.withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add some extra space so keyboard doesn't block the last inputs
                        SizedBox(
                          height:
                              MediaQuery.of(context).viewInsets.bottom + 100,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hesabı Sil',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu işlem geri alınamaz. Tüm verileriniz (notlar, postlar, mesajlar, arkadaşlıklar) kalıcı olarak silinecektir.',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
                const SizedBox(height: 16),
                Text(
                  'Doğrulama için e-posta ve şifrenizi girin:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: AppColors.textHeader),
                  decoration: InputDecoration(
                    hintText: 'E-posta adresiniz',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppColors.textBody,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: AppColors.textHeader),
                  decoration: InputDecoration(
                    hintText: 'Şifreniz',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: AppColors.textBody,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('İptal', style: TextStyle(color: AppColors.textBody)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      if (email.isEmpty || password.isEmpty) {
                        setDialogState(
                          () => errorText = 'E-posta ve şifre boş bırakılamaz.',
                        );
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        // Re-authenticate
                        final user = FirebaseAuth.instance.currentUser!;
                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: password,
                        );
                        await user.reauthenticateWithCredential(credential);
                        // Delete all data then account
                        await _deleteAccountAndData(user.uid, email);
                        if (ctx.mounted) Navigator.pop(ctx);
                        // Navigate to login
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginView(),
                            ),
                            (route) => false,
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg = 'Bir hata oluştu.';
                        if (e.code == 'wrong-password' ||
                            e.code == 'invalid-credential') {
                          msg = 'Şifre yanlış. Lütfen tekrar deneyin.';
                        } else if (e.code == 'user-mismatch') {
                          msg = 'E-posta adresi hesabınızla eşleşmiyor.';
                        } else if (e.code == 'invalid-email') {
                          msg = 'Geçersiz e-posta adresi.';
                        } else if (e.code == 'too-many-requests') {
                          msg = 'Çok fazla deneme. Lütfen biraz bekleyin.';
                        }
                        setDialogState(() {
                          isLoading = false;
                          errorText = msg;
                        });
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText = 'Hata: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hesabı Sil',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccountAndData(String uid, String email) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Kullanıcının postlarını sil (alt koleksiyonlar dahil)
    final posts = await firestore
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .get();
    for (final post in posts.docs) {
      // Yorumları sil
      final comments = await post.reference.collection('comments').get();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }
      batch.delete(post.reference);
    }

    // 2. Kullanıcının notlarını sil
    final notes = await firestore
        .collection('notes')
        .where('email', isEqualTo: email)
        .get();
    for (final note in notes.docs) {
      batch.delete(note.reference);
    }

    // 3. Arkadaşlıkları sil
    final friendships1 = await firestore
        .collection('friendships')
        .where('requesterId', isEqualTo: uid)
        .get();
    for (final doc in friendships1.docs) {
      batch.delete(doc.reference);
    }
    final friendships2 = await firestore
        .collection('friendships')
        .where('receiverId', isEqualTo: uid)
        .get();
    for (final doc in friendships2.docs) {
      batch.delete(doc.reference);
    }

    // 4. DM konuşmalarını sil
    final convos = await firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get();
    for (final convo in convos.docs) {
      final messages = await convo.reference.collection('messages').get();
      for (final msg in messages.docs) {
        batch.delete(msg.reference);
      }
      batch.delete(convo.reference);
    }

    // 5. Kullanıcının mesajlarını (topluluk) sil
    final communityMessages = await firestore
        .collection('messages')
        .where('senderEmail', isEqualTo: email)
        .get();
    for (final msg in communityMessages.docs) {
      batch.delete(msg.reference);
    }

    // 6. Kullanıcı dokümanını sil
    batch.delete(firestore.collection('users').doc(uid));

    // Batch commit
    await batch.commit();

    // 7. Firebase Auth hesabını sil
    await FirebaseAuth.instance.currentUser?.delete();
  }

  void _showProfileVisitorsSheet() {
    final visitService = ProfileVisitService();
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profil Ziyaretçileri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeader,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Profiline bakanları gör',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: visitService.getVisitors(myUid),
                builder: (ctx, snap) {
                  if (!snap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final visitors = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final aTime =
                          (a.data() as Map<String, dynamic>)['visitedAt']
                              as Timestamp?;
                      final bTime =
                          (b.data() as Map<String, dynamic>)['visitedAt']
                              as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });
                  if (visitors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 48,
                            color: AppColors.border,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Henüz ziyaretçi yok',
                            style: TextStyle(color: AppColors.textBody),
                          ),
                        ],
                      ),
                    );
                  }

                  // Premium / mavi tik kontrolü
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(myUid)
                        .get(),
                    builder: (ctx, userSnap) {
                      final myData =
                          userSnap.data?.data() as Map<String, dynamic>?;
                      final hasVisitorAccess =
                          VerifiedBadge.hasBlueBadge(myData) ||
                          myData?['role'] == 'admin';

                      final now = DateTime.now();
                      int last24HoursCount = 0;
                      int last7DaysCount = 0;
                      DateTime? latestVisitAt;
                      for (final doc in visitors) {
                        final data = doc.data() as Map<String, dynamic>;
                        final visitedAt = (data['visitedAt'] as Timestamp?)
                            ?.toDate();
                        if (visitedAt == null) continue;
                        if (latestVisitAt == null ||
                            visitedAt.isAfter(latestVisitAt)) {
                          latestVisitAt = visitedAt;
                        }
                        if (visitedAt.isAfter(
                          now.subtract(const Duration(hours: 24)),
                        )) {
                          last24HoursCount++;
                        }
                        if (visitedAt.isAfter(
                          now.subtract(const Duration(days: 7)),
                        )) {
                          last7DaysCount++;
                        }
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount:
                            visitors.length + (hasVisitorAccess ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (hasVisitorAccess && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: _buildVisitorStatsCard(
                                totalCount: visitors.length,
                                last24HoursCount: last24HoursCount,
                                last7DaysCount: last7DaysCount,
                                latestVisitAt: latestVisitAt,
                              ),
                            );
                          }

                          final visitorIndex =
                              hasVisitorAccess ? index - 1 : index;
                          final visit = visitors[visitorIndex].data()
                              as Map<String, dynamic>;
                          final visitorId = visit['visitorId'] as String;
                          final visitedAt = (visit['visitedAt'] as Timestamp?)
                              ?.toDate();
                          final bool shouldBlur =
                              !hasVisitorAccess && visitorIndex >= 2;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(visitorId)
                                .get(),
                            builder: (ctx, vSnap) {
                              if (!vSnap.hasData)
                                return const SizedBox(height: 56);
                              final vData =
                                  vSnap.data?.data() as Map<String, dynamic>? ??
                                  {};
                              final vName =
                                  vData['nick'] ?? vData['name'] ?? 'Kullanıcı';
                              final vPhoto = vData['photoUrl'];
                              final timeStr = visitedAt != null
                                  ? '${visitedAt.day}.${visitedAt.month}.${visitedAt.year} ${visitedAt.hour.toString().padLeft(2, '0')}:${visitedAt.minute.toString().padLeft(2, '0')}'
                                  : '';

                              return Stack(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: vPhoto != null
                                          ? NetworkImage(vPhoto)
                                          : null,
                                      backgroundColor:
                                          AppColors.surfaceSecondary,
                                      child: vPhoto == null
                                          ? Icon(
                                              Icons.person,
                                              color: AppColors.textTertiary,
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      vName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textHeader,
                                      ),
                                    ),
                                    subtitle: Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textBody,
                                      ),
                                    ),
                                    trailing: VerifiedBadge.fromUserData(vData),
                                    onTap: shouldBlur
                                        ? null
                                        : () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => UserProfileView(
                                                  userId: visitorId,
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                  if (shouldBlur)
                                    Positioned.fill(
                                      child: ClipRect(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 8,
                                            sigmaY: 8,
                                          ),
                                          child: Container(
                                            color: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // Premium tanitim bolumu
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .get(),
              builder: (ctx, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final hasVisitorAccess =
                    VerifiedBadge.hasBlueBadge(data) ||
                    data?['role'] == 'admin';
                if (hasVisitorAccess) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1DA1F2).withValues(alpha: 0.15),
                        const Color(0xFF1DA1F2).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1DA1F2).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF1DA1F2),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium ile tümünü gör',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textHeader,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Premium alarak mavi tik kazan ve tüm ziyaretçileri aç.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openPremiumView();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DA1F2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorStatsCard({
    required int totalCount,
    required int last24HoursCount,
    required int last7DaysCount,
    required DateTime? latestVisitAt,
  }) {
    final latestVisitText = latestVisitAt == null
        ? 'Henüz veri yok'
        : '${latestVisitAt.day.toString().padLeft(2, '0')}.${latestVisitAt.month.toString().padLeft(2, '0')}.${latestVisitAt.year} ${latestVisitAt.hour.toString().padLeft(2, '0')}:${latestVisitAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İstatistikler',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeader,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildVisitorStatItem(
                  icon: Icons.groups_rounded,
                  label: 'Toplam',
                  value: '$totalCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVisitorStatItem(
                  icon: Icons.schedule_rounded,
                  label: '24 Saat',
                  value: '$last24HoursCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVisitorStatItem(
                  icon: Icons.calendar_today_rounded,
                  label: '7 Gün',
                  value: '$last7DaysCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.update_rounded,
                size: 14,
                color: AppColors.textBody,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Son ziyaret: $latestVisitText',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeader,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaField(
    String hintText,
    String platform,
    TextEditingController controller,
  ) {
    final brand = _socialBrand(platform);
    final Color brandColor = brand['color'] as Color;
    final IconData brandIcon = brand['icon'] as IconData;
    final String platformLabel = brand['label'] as String;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: FaIcon(brandIcon, color: brandColor, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                platformLabel,
                style: TextStyle(
                  color: AppColors.textHeader,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: true,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: "Panodan Yapistir",
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = clip?.text ?? '';
                  if (text.isEmpty) return;
                  final selection = controller.selection;
                  if (!selection.isValid) {
                    controller.text = '${controller.text}$text';
                    return;
                  }
                  final newText = controller.text.replaceRange(
                    selection.start,
                    selection.end,
                    text,
                  );
                  final caret = selection.start + text.length;
                  controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: caret),
                  );
                },
              ),
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfileChanges(
    String uid,
    String nick,
    String bio,
    int avatarIndex,
    String instagram,
    String linkedin,
    String x,
    String tiktok,
    String snapchat,
    String facebook, {
    bool nickLocked = false,
  }) async {
    final nickTrimmed = nick.trim();
    final Map<String, dynamic> data = {
      'bio': bio,
      'avatarIndex': avatarIndex,
      'socialLinks': {
        'instagram': instagram.trim(),
        'linkedin': linkedin.trim(),
        'x': x.trim(),
        'twitter': x.trim(), // Eski verilerle uyumluluk için
        'tiktok': tiktok.trim(),
        'snapchat': snapchat.trim(),
        'facebook': facebook.trim(),
      },
    };

    if (!nickLocked && nickTrimmed.isNotEmpty) {
      final nickRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
      if (!nickRegex.hasMatch(nickTrimmed)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Nick 3-20 karakter olmalı, sadece harf/rakam/_ içerebilir!",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      data['nick'] = nickTrimmed;
      data['nickLastChangedAt'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil güncellendi ✅"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── Başka bir kullanıcının profilini göster ───
  void _showUserProfileBottomSheet(String userIdentifier) async {
    Future<String?> findUserIdByField(String field, String value) async {
      if (value.trim().isEmpty) return null;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    }

    String? userId;
    userId = await findUserIdByField('email', userIdentifier);
    userId ??= await findUserIdByField('nick', userIdentifier);
    userId ??= await findUserIdByField('name', userIdentifier);

    if (!mounted) return;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı profili bulunamadı.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileView(userId: userId!)),
    );
  }

  bool _hasSocialLinksData(dynamic links) {
    if (links == null) return false;
    if (links is! Map) return false;
    final m = Map<String, dynamic>.from(links);
    return _socialValue(m, 'instagram').isNotEmpty ||
        _socialValue(m, 'linkedin').isNotEmpty ||
        _socialValue(m, 'x').isNotEmpty ||
        _socialValue(m, 'tiktok').isNotEmpty ||
        _socialValue(m, 'snapchat').isNotEmpty ||
        _socialValue(m, 'facebook').isNotEmpty;
  }

  String _socialValue(dynamic links, String platform) {
    if (links == null || links is! Map) return '';
    final map = Map<String, dynamic>.from(links);
    if (platform == 'x') {
      return (map['x'] ?? map['twitter'] ?? '').toString().trim();
    }
    return (map[platform] ?? '').toString().trim();
  }

  Map<String, dynamic> _socialBrand(String platform) {
    switch (platform) {
      case 'instagram':
        return {
          'icon': FontAwesomeIcons.instagram,
          'color': const Color(0xFFE4405F),
          'label': 'Instagram',
        };
      case 'linkedin':
        return {
          'icon': FontAwesomeIcons.linkedinIn,
          'color': const Color(0xFF0A66C2),
          'label': 'LinkedIn',
        };
      case 'x':
        return {
          'icon': FontAwesomeIcons.xTwitter,
          'color': AppColors.isDark
              ? const Color(0xFFE7E9EA)
              : const Color(0xFF111111),
          'label': 'X',
        };
      case 'tiktok':
        return {
          'icon': FontAwesomeIcons.tiktok,
          'color': AppColors.isDark
              ? const Color(0xFFE7E9EA)
              : const Color(0xFF111111),
          'label': 'TikTok',
        };
      case 'snapchat':
        return {
          'icon': FontAwesomeIcons.snapchat,
          'color': const Color(0xFFFFD600),
          'label': 'Snapchat',
        };
      case 'facebook':
        return {
          'icon': FontAwesomeIcons.facebookF,
          'color': const Color(0xFF1877F2),
          'label': 'Facebook',
        };
      default:
        return {
          'icon': FontAwesomeIcons.link,
          'color': Colors.grey,
          'label': 'Link',
        };
    }
  }

  String _buildSocialUrl(String? handle, String platform) {
    if (handle == null || handle.isEmpty) return '';
    if (handle.startsWith('http')) return handle;
    final normalized = handle.replaceAll('@', '');
    switch (platform) {
      case 'instagram':
        return 'https://instagram.com/$normalized';
      case 'linkedin':
        return 'https://linkedin.com/in/$normalized';
      case 'x':
        return 'https://x.com/$normalized';
      case 'tiktok':
        return 'https://www.tiktok.com/@$normalized';
      case 'snapchat':
        return 'https://www.snapchat.com/add/$normalized';
      case 'facebook':
        return 'https://www.facebook.com/$normalized';
      default:
        return handle;
    }
  }

  Widget _buildSocialIcon(String platform, String url) {
    final brand = _socialBrand(platform);
    final Color color = brand['color'] as Color;
    final String label = brand['label'] as String;
    final IconData icon = brand['icon'] as IconData;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: FaIcon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog(Map<String, dynamic>? userData) {
    final tC = TextEditingController(), cC = TextEditingController();
    String f = selectedFaculty == "Hepsi" ? faculties[1] : selectedFaculty;
    String d = selectedDepartment == "Hepsi"
        ? ((departmentsByFaculty[f]?.length ?? 0) > 1
              ? departmentsByFaculty[f]![1]
              : "Hepsi")
        : selectedDepartment;
    String crs = courses.contains(selectedCourse) ? selectedCourse : "Hepsi";
    File? selectedFile;
    String? selectedFileName;
    bool isUploading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Not Ekle",
      pageBuilder: (ctx, anim1, anim2) => StatefulBuilder(
        builder: (context, setDialogState) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: AppColors.textHeader),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              "Not Ekle",
              style: TextStyle(
                color: AppColors.textHeader,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                _buildFormLabel("Fakülte"),
                _buildFormSelector(
                  f,
                  () => _showSearchableSelector(
                    context: context,
                    title: "Fakülte Seç",
                    items: faculties.where((e) => e != "Hepsi").toList(),
                    selected: f,
                    onSelected: (val) => setDialogState(() {
                      f = val;
                      final deptList = departmentsByFaculty[f] ?? ["Hepsi"];
                      d = deptList.length > 1 ? deptList[1] : "Hepsi";
                    }),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormLabel("Bölüm"),
                          _buildFormDropdown<String>(
                            value: d,
                            items: (departmentsByFaculty[f] ?? ["Hepsi"])
                                .where((e) => e != "Hepsi")
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e.length > 15
                                          ? "${e.substring(0, 15)}..."
                                          : e,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => setDialogState(() => d = val!),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormLabel("Ders"),
                          _buildFormDropdown<String>(
                            value: crs,
                            items: courses
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => crs = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _buildFormLabel("Başlık"),
                _buildFormTextField(tC, "Notunuz için etkileyici bir başlık"),
                SizedBox(height: 20),
                _buildFormLabel("İçerik (opsiyonel)"),
                _buildFormTextField(
                  cC,
                  "Not içeriği hakkında kısa bilgi...",
                  maxLines: 4,
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    _buildFileAddButton(
                      Icons.image_rounded,
                      "Görsel Ekle",
                      () async {
                        final picked = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          final cropped = await ImageCropper().cropImage(
                            sourcePath: picked.path,
                            uiSettings: [
                              AndroidUiSettings(
                                toolbarTitle: 'Görseli Düzenle',
                                toolbarColor: const Color(0xFF0288D1),
                                toolbarWidgetColor: Colors.white,
                                activeControlsWidgetColor: const Color(
                                  0xFF800000,
                                ),
                                cropStyle: CropStyle.rectangle,
                                lockAspectRatio: false,
                              ),
                              IOSUiSettings(title: 'Görseli Düzenle'),
                            ],
                          );
                          if (cropped != null) {
                            setDialogState(() {
                              selectedFile = File(cropped.path);
                              selectedFileName = picked.name;
                            });
                          }
                        }
                      },
                    ),
                    SizedBox(width: 12),
                    _buildFileAddButton(
                      Icons.picture_as_pdf_rounded,
                      "PDF Ekle",
                      () async {
                        final result = await _pickPdfFile();
                        if (result != null) {
                          setDialogState(() {
                            selectedFile = result['file'];
                            selectedFileName = result['name'];
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (selectedFileName != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => setDialogState(() {
                            selectedFile = null;
                            selectedFileName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isUploading) ...[
                  SizedBox(height: 20),
                  LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ],
                SizedBox(height: 100),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isUploading
                ? null
                : () async {
                    if (tC.text.isEmpty) return;
                    setDialogState(() => isUploading = true);
                    String? fileUrl;
                    String? fileType;
                    if (selectedFile != null && selectedFileName != null) {
                      fileUrl = await _storageService.uploadNoteFile(
                        selectedFile!,
                        selectedFileName!,
                      );
                      final ext = selectedFileName!
                          .split('.')
                          .last
                          .toLowerCase();
                      fileType = ext == 'pdf' ? 'pdf' : 'image';
                    }
                    // Kullanıcının profil fotoğrafını Firestore'dan al
                    String? noteUserImage;
                    try {
                      final uDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser!.uid)
                          .get();
                      if (uDoc.exists) {
                        noteUserImage = uDoc.data()?['photoUrl'];
                      }
                    } catch (_) {}

                    await FirebaseFirestore.instance.collection('notes').add({
                      'department': d,
                      'faculty': f,
                      'course': crs,
                      'title': tC.text,
                      'content': cC.text,
                      'userName': userData?['nick'] ?? "Anonim",
                      'userEmail': currentUser?.email,
                      'userId': currentUser!.uid,
                      'userImage': noteUserImage,
                      'createdAt': FieldValue.serverTimestamp(),
                      'likes': 0,
                      'likedBy': [],
                      'savedBy': [],
                      if (fileUrl != null) 'fileUrl': fileUrl,
                      if (fileType != null) 'fileType': fileType,
                      if (selectedFileName != null)
                        'fileName': selectedFileName,
                    });
                    if (mounted) Navigator.pop(ctx);
                  },
            backgroundColor: AppColors.primary,
            label: const Row(
              children: [
                Text(
                  "Paylaş",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textHeader,
        ),
      ),
    );
  }

  Widget _buildFormTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: AppColors.textHeader, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFormSelector(String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.textBody, fontSize: 14),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildFileAddButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aranabilir seçici popup (100+ bölüm için)
  void _showSearchableSelector({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String selected,
    required Function(String) onSelected,
  }) {
    String searchText = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = searchText.isEmpty
                ? items
                : items
                      .where(
                        (e) =>
                            e.toLowerCase().contains(searchText.toLowerCase()),
                      )
                      .toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, sc) => Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Bölüm ara...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (val) => setSheetState(() => searchText = val),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: sc,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final isSel = item == selected;
                        return ListTile(
                          dense: true,
                          title: Text(
                            item,
                            style: TextStyle(
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSel ? kPrimaryColor : null,
                            ),
                          ),
                          trailing: isSel
                              ? Icon(
                                  Icons.check_circle,
                                  color: kPrimaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.first;
      if (f.path == null) return null;
      return {'file': File(f.path!), 'name': f.name};
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // --- ANA SCAFFOLD ---
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            _buildNotesPage(), // 0
            const SocialFeedView(), // 1
            _buildHomePage(), // 2
            _buildToolsPage(), // 3
            _buildProfilePage(), // 4
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () => _showAddNoteDialog({'nick': _userNick}),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.isDark
                      ? const Color(0xFF0C0F14).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: AppColors.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFD0D5E0).withValues(alpha: 0.45),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : const Color(0xFF1A2540).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Üst kenar — cam gibi ince ışık yansıması
                    Positioned(
                      top: 0,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.isDark
                                ? [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.0),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                          ),
                        ),
                      ),
                    ),
                    // Nav içeriği
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            0,
                            Icons.description_outlined,
                            Icons.description_rounded,
                            "Notlar",
                          ),
                          _buildNavItem(
                            1,
                            Icons.explore_outlined,
                            Icons.explore_rounded,
                            "Keşfet",
                          ),
                          _buildNavItem(
                            2,
                            Icons.home_outlined,
                            Icons.home_rounded,
                            "Ana Sayfa",
                          ),
                          _buildNavItem(
                            3,
                            Icons.apps_outlined,
                            Icons.apps_rounded,
                            "Araçlar",
                          ),
                          _buildNavItem(
                            4,
                            Icons.person_outline_rounded,
                            Icons.person_rounded,
                            "Profil",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildChatNavItem() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(150)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasReplyNotice = false;
        if (snapshot.hasData && currentUser?.email != null) {
          final currentEmail = currentUser!.email!;
          for (final doc in snapshot.data!.docs) {
            final m = doc.data() as Map<String, dynamic>;
            final replyToEmail = (m['replyToEmail'] ?? '').toString();
            final senderEmail = (m['senderEmail'] ?? '').toString();
            final createdAt = m['createdAt'] as Timestamp?;
            if (replyToEmail == currentEmail &&
                senderEmail != currentEmail &&
                createdAt != null &&
                createdAt.toDate().isAfter(_chatSeenAt)) {
              hasReplyNotice = true;
              break;
            }
          }
        }
        return _buildNavItem(
          1,
          Icons.chat_bubble_outline,
          Icons.chat_bubble_rounded,
          "Sohbet",
          showDot: hasReplyNotice && _selectedIndex != 1,
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool showDot = false,
  }) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (AppColors.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.10))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? (AppColors.isDark ? Colors.white : AppColors.primary)
                      : (AppColors.isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF8892A2)),
                  size: isSelected ? 24 : 22,
                ),
                if (showDot)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (AppColors.isDark ? Colors.white : AppColors.primary)
                    : (AppColors.isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF8892A2)),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolMeta {
  final Color color1;
  final Color color2;
  final String description;
  const _ToolMeta(this.color1, this.color2, this.description);
}

// --- YENİ EKRAN: LİDERLİK TABLOSU ---
class LeaderboardView extends StatefulWidget {
  final Color kPrimaryColor;
  const LeaderboardView({super.key, required this.kPrimaryColor});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textHeader),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Liderlik Tablosu",
          style: TextStyle(
            color: AppColors.textHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notes').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: widget.kPrimaryColor),
            );
          }

          Map<String, int> userLikes = {};
          Map<String, String> userDepartments = {};
          Map<String, String?> userImages = {};
          Map<String, String?> userEmails = {};

          for (var doc in snapshot.data!.docs) {
            try {
              var data = doc.data() as Map<String, dynamic>;
              String uName = (data['userName'] ?? "Öğrenci").toString().trim();
              final likes = (data['likes'] is int) ? data['likes'] as int : 0;
              if (uName.isEmpty || likes <= 0) continue;

              userLikes[uName] = (userLikes[uName] ?? 0) + likes;
              if (data['department'] != null) {
                userDepartments[uName] = data['department'];
              }
              final noteImage = _normalizeImageUrl(data['userImage']);
              if (noteImage != null) {
                userImages[uName] = noteImage;
              }
              final email = (data['userEmail'] ?? '').toString().trim();
              if (email.isNotEmpty) {
                userEmails[uName] = email;
              }
            } catch (_) {}
          }

          var sortedUsers =
              userLikes.entries.where((entry) => entry.value > 0).toList()
                ..sort((a, b) => b.value.compareTo(a.value));

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              final imageLookup = <String, String>{};
              for (final doc in userSnapshot.data?.docs ?? const []) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  final photoUrl = _normalizeImageUrl(data['photoUrl']);
                  if (photoUrl == null) continue;
                  final nick = (data['nick'] ?? '').toString().trim();
                  final name = (data['name'] ?? '').toString().trim();
                  final email = (data['email'] ?? '').toString().trim();
                  if (nick.isNotEmpty) imageLookup[nick.toLowerCase()] = photoUrl;
                  if (name.isNotEmpty) imageLookup[name.toLowerCase()] = photoUrl;
                  if (email.isNotEmpty) {
                    imageLookup[email.toLowerCase()] = photoUrl;
                  }
                } catch (_) {}
              }

              for (final userName in userLikes.keys) {
                userImages[userName] ??= imageLookup[userName.toLowerCase()];
                final userEmail = userEmails[userName];
                if (userImages[userName] == null &&
                    userEmail != null &&
                    userEmail.isNotEmpty) {
                  userImages[userName] = imageLookup[userEmail.toLowerCase()];
                }
              }

              return Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: sortedUsers.isEmpty
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildPodium(sortedUsers, userImages),
                                SizedBox(height: 30),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "SIRALAMA",
                                      style: TextStyle(
                                        color: AppColors.textBody,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                _buildRankList(
                                  sortedUsers,
                                  userDepartments,
                                  userImages,
                                ),
                                SizedBox(height: 40),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPodium(
    List<MapEntry<String, int>> users,
    Map<String, String?> images,
  ) {
    if (users.isEmpty) return const SizedBox.shrink();

    final top = users.take(3).toList();
    if (top.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: _buildPodiumItem(
            user: top[0],
            rank: 1,
            image: images[top[0].key],
            avatarSize: 100,
            borderColor: const Color(0xFFFFD700),
            isFirst: true,
          ),
        ),
      );
    }

    if (top.length == 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildPodiumItem(
                user: top[1],
                rank: 2,
                image: images[top[1].key],
                avatarSize: 76,
                borderColor: const Color(0xFFC0C0C0),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                child: _buildPodiumItem(
                  user: top[0],
                  rank: 1,
                  image: images[top[0].key],
                  avatarSize: 100,
                  borderColor: const Color(0xFFFFD700),
                  isFirst: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildPodiumItem(
              user: top[1],
              rank: 2,
              image: images[top[1].key],
              avatarSize: 76,
              borderColor: const Color(0xFFC0C0C0),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
              child: _buildPodiumItem(
                user: top[0],
                rank: 1,
                image: images[top[0].key],
                avatarSize: 100,
                borderColor: const Color(0xFFFFD700),
                isFirst: true,
              ),
            ),
          ),
          Expanded(
            child: _buildPodiumItem(
              user: top[2],
              rank: 3,
              image: images[top[2].key],
              avatarSize: 76,
              borderColor: const Color(0xFFCD7F32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required MapEntry<String, int> user,
    required int rank,
    required String? image,
    required double avatarSize,
    required Color borderColor,
    bool isFirst = false,
  }) {
    final nameParts = user.key.trim().split(RegExp(r'\s+'));
    String nameObj = nameParts.first;
    if (nameParts.length > 1 && nameParts.last.isNotEmpty) {
      nameObj += " ${nameParts.last[0]}.";
    }

    final likesStr = user.value > 999
        ? "${(user.value / 1000).toStringAsFixed(1)}k"
        : "${user.value}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "ŞAMPİYON",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isFirst) SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 4),
              ),
              child: _buildLeaderboardAvatar(
                imageUrl: image,
                radius: avatarSize / 2,
              ),
            ),
            if (!isFirst)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$rank",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isFirst)
              Positioned(
                bottom: -10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$rank",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          nameObj,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textHeader,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 14),
            SizedBox(width: 4),
            Text(
              likesStr,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankList(
    List<MapEntry<String, int>> users,
    Map<String, String> departments,
    Map<String, String?> images,
  ) {
    final List<Widget> listItems = [];
    final currentUserName = FirebaseAuth.instance.currentUser?.displayName;

    for (int i = 3; i < users.length; i++) {
      var user = users[i];
      String dept = departments[user.key] ?? "ÖĞRENCİ";
      bool isCurrentUser = user.key == currentUserName;

      listItems.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? (AppColors.isDark
                      ? AppColors.error.withValues(alpha: 0.16)
                      : Colors.red.shade50)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCurrentUser
                  ? (AppColors.isDark
                        ? AppColors.error.withValues(alpha: 0.45)
                        : Colors.red.shade200)
                  : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(
                  alpha: AppColors.isDark ? 0.35 : 0.04,
                ),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  "${i + 1}",
                  style: TextStyle(
                    color: isCurrentUser ? AppColors.error : AppColors.textBody,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 12),
              _buildLeaderboardAvatar(imageUrl: images[user.key], radius: 20),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textHeader,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      dept.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.favorite, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text(
                "${user.value}",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: listItems);
  }

  String? _normalizeImageUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty || url == 'null') return null;
    return url;
  }

  Widget _buildLeaderboardAvatar({
    required String? imageUrl,
    required double radius,
  }) {
    final safeUrl = _normalizeImageUrl(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceSecondary,
      child: safeUrl == null
          ? Icon(Icons.person, color: AppColors.textTertiary)
          : ClipOval(
              child: Image.network(
                safeUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person, color: AppColors.textTertiary),
              ),
            ),
    );
  }
}

// --- DETAY SAYFASI ---
class NoteDetailView extends StatefulWidget {
  final String noteId;
  final Map<String, dynamic> data;
  final String? currentUserEmail;

  const NoteDetailView({
    super.key,
    required this.noteId,
    required this.data,
    this.currentUserEmail,
  });

  @override
  State<NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<NoteDetailView> {
  final TextEditingController _commentController = TextEditingController();

  void _showPublicProfile(String userName) async {
    Future<String?> findUserIdByField(String field, String value) async {
      if (value.trim().isEmpty) return null;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    }

    String? userId;
    userId = await findUserIdByField('nick', userName);
    userId ??= await findUserIdByField('name', userName);

    if (!mounted) return;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı profili bulunamadı.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileView(userId: userId!)),
    );
  }

  Widget _buildDetailActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    if (_commentController.text.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      String finalName = user?.displayName ?? "Öğrenci";
      String? commentUserImage;
      try {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (uDoc.exists) {
          finalName = uDoc.data()?['name'] ?? finalName;
          commentUserImage = uDoc.data()?['photoUrl'];
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .collection('comments')
          .add({
            'text': _commentController.text.trim(),
            'userName': finalName,
            'userImage': commentUserImage,
            'userEmail': user?.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update comment count
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .update({'commentsCount': FieldValue.increment(1)});

      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "İçeriği Şikayet Et",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeader,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Bu içerikte topluluk kurallarını ihlal eden bir durum mu var?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textBody),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "İptal",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('reports')
                          .add({
                            'noteId': widget.noteId,
                            'reporterEmail': widget.currentUserEmail,
                            'reason': 'Uygunsuz İçerik',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Şikayetiniz alındı.")),
                        );
                      }
                    },
                    child: Text(
                      "ŞİKAYET ET",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      await Gal.putImageBytes(response.bodyBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Görsel kaydedildi.")));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Kaydedilemedi.")));
      }
    }
  }

  void _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showImageOptions(String imageUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.download_rounded, color: AppColors.primary),
              title: Text('Galeriye Kaydet'),
              onTap: () {
                Navigator.pop(context);
                _saveImageToGallery(imageUrl);
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser_rounded, color: Colors.blue),
              title: Text('Tarayıcıda Aç'),
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse(imageUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeader,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Not Detayı",
          style: TextStyle(
            color: AppColors.textHeader,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showReportDialog,
            icon: Icon(Icons.flag_outlined, color: Colors.grey),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.noteId)
            .snapshots(),
        builder: (context, noteSnapshot) {
          if (!noteSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final noteData = noteSnapshot.data!.data() as Map<String, dynamic>;
          final currentUser = FirebaseAuth.instance.currentUser;
          final likedBy = noteData['likedBy'] ?? [];
          final savedBy = noteData['savedBy'] ?? [];
          final isLiked = likedBy.contains(currentUser?.uid);
          final isSaved = savedBy.contains(currentUser?.uid);

          // Recalculate dateStr with the streamed noteData
          Timestamp? streamedTimestamp = noteData['createdAt'] as Timestamp?;
          String streamedDateStr = streamedTimestamp != null
              ? DateFormat(
                  'dd.MM.yyyy, HH:mm',
                ).format(streamedTimestamp.toDate())
              : "";

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12),
                      // User Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: (noteData['userImage'] != null)
                                ? NetworkImage(noteData['userImage'])
                                : null,
                            backgroundColor: AppColors.primaryLight,
                            child: (noteData['userImage'] == null)
                                ? Icon(Icons.person, color: AppColors.primary)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  noteData['userName'] ?? "İsimsiz",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textHeader,
                                  ),
                                ),
                                Text(
                                  "$streamedDateStr \u2022 ${noteData['department'] ?? 'Genel'}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Title & Content
                      Text(
                        noteData['title'] ?? "Başlıksız",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textHeader,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        noteData['content'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textBody,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 24),
                      // File Preview
                      if (noteData['fileUrl'] != null) ...[
                        if (noteData['fileType'] == 'image')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: GestureDetector(
                              onLongPress: () =>
                                  _showImageOptions(noteData['fileUrl']),
                              child: Image.network(
                                noteData['fileUrl'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text('Görsel yüklenemedi'),
                                ),
                              ),
                            ),
                          )
                        else if (noteData['fileType'] == 'pdf')
                          GestureDetector(
                            onTap: () => _openPdf(noteData['fileUrl']),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      noteData['fileName'] ?? 'Dökümanı Aç',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      SizedBox(height: 32),
                      // Action Row (Like, Save, Download)
                      Row(
                        children: [
                          _buildDetailActionButton(
                            icon: isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: "${noteData['likes'] ?? 0}",
                            color: isLiked ? Colors.red : Colors.grey,
                            onTap: () {
                              if (currentUser != null) {
                                NoteService().toggleLike(
                                  widget.noteId,
                                  currentUser.uid,
                                  isLiked,
                                );
                              }
                            },
                          ),
                          SizedBox(width: 24),
                          _buildDetailActionButton(
                            icon: isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            label: isSaved ? "Kaydedildi" : "Kaydet",
                            color: isSaved ? AppColors.primary : Colors.grey,
                            onTap: () {
                              if (currentUser != null) {
                                NoteService().toggleSave(
                                  widget.noteId,
                                  currentUser.uid,
                                  isSaved,
                                );
                              }
                            },
                          ),
                          const Spacer(),
                          if (noteData['fileUrl'] != null)
                            _buildDetailActionButton(
                              icon: Icons.download_for_offline_rounded,
                              label: "Dosya",
                              color: AppColors.primary,
                              onTap: () {
                                if (noteData['fileType'] == 'pdf') {
                                  _openPdf(noteData['fileUrl']);
                                } else {
                                  _saveImageToGallery(noteData['fileUrl']);
                                }
                              },
                            ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.background,
                      ),
                      SizedBox(height: 24),
                      Text(
                        "Yorumlar",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHeader,
                        ),
                      ),
                      SizedBox(height: 16),
                      // Comments List
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notes')
                            .doc(widget.noteId)
                            .collection('comments')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final comments = snapshot.data?.docs ?? [];
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Colors.grey[300],
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Henüz yorum yapılmamış.\nİlk yorumu sen yap!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              var c =
                                  comments[index].data()
                                      as Map<String, dynamic>;
                              Timestamp? ct = c['createdAt'] as Timestamp?;
                              String fTime = ct != null
                                  ? DateFormat('HH:mm').format(ct.toDate())
                                  : "";
                              return Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: (c['userImage'] != null)
                                          ? NetworkImage(c['userImage'])
                                          : null,
                                      backgroundColor: AppColors.primaryLight,
                                      child: (c['userImage'] == null)
                                          ? Icon(
                                              Icons.person,
                                              size: 18,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.isDark
                                              ? AppColors.surface
                                              : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(20),
                                            bottomLeft: Radius.circular(20),
                                            bottomRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showPublicProfile(
                                                        c['userName'] ??
                                                            "Öğrenci",
                                                      ),
                                                  child: Text(
                                                    c['userName'] ?? "Öğrenci",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: AppColors.primary,
                                                      decoration:
                                                          TextDecoration.none,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  fTime,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              c['text'] ?? "",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textBody,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.isDark ? AppColors.surface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: true,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: "Yorum yaz...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sendComment,
                          icon: Icon(
                            Icons.send_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AnnouncementDetailView extends StatelessWidget {
  final Map<String, dynamic> data;
  const AnnouncementDetailView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeader,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Detaylar",
          style: TextStyle(
            color: AppColors.textHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['imageUrl'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.network(
                    data['imageUrl'],
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textHeader,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    data['fullContent'] ?? data['description'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textBody,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notlardaki Takip Et Butonu ───
class _NoteFollowButton extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;

  const _NoteFollowButton({
    required this.currentUserId,
    required this.targetUserId,
  });

  @override
  State<_NoteFollowButton> createState() => _NoteFollowButtonState();
}

class _NoteFollowButtonState extends State<_NoteFollowButton> {
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final fs = FirebaseFirestore.instance;
      // Takip edip etmediğimizi kontrol et (friendship koleksiyonu)
      final q1 = await fs
          .collection('friendships')
          .where('requesterId', isEqualTo: widget.currentUserId)
          .where('receiverId', isEqualTo: widget.targetUserId)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        if (mounted)
          setState(() {
            _isFollowing = true;
            _isLoading = false;
          });
        return;
      }
      final q2 = await fs
          .collection('friendships')
          .where('requesterId', isEqualTo: widget.targetUserId)
          .where('receiverId', isEqualTo: widget.currentUserId)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        if (mounted)
          setState(() {
            _isFollowing = true;
            _isLoading = false;
          });
        return;
      }
      if (mounted)
        setState(() {
          _isFollowing = false;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final fs = FirebaseFirestore.instance;
      if (_isFollowing) {
        // Takibi bırak
        final q1 = await fs
            .collection('friendships')
            .where('requesterId', isEqualTo: widget.currentUserId)
            .where('receiverId', isEqualTo: widget.targetUserId)
            .get();
        for (final d in q1.docs) {
          await d.reference.delete();
        }
        final q2 = await fs
            .collection('friendships')
            .where('requesterId', isEqualTo: widget.targetUserId)
            .where('receiverId', isEqualTo: widget.currentUserId)
            .get();
        for (final d in q2.docs) {
          await d.reference.delete();
        }
        if (mounted)
          setState(() {
            _isFollowing = false;
            _isLoading = false;
          });
      } else {
        // Takip et
        final currentUserDoc = await fs
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        final targetUserDoc = await fs
            .collection('users')
            .doc(widget.targetUserId)
            .get();
        final currentData = currentUserDoc.data() ?? {};
        final targetData = targetUserDoc.data() ?? {};

        await FriendshipService().follow(
          requesterId: widget.currentUserId,
          receiverId: widget.targetUserId,
          requesterName: currentData['name'] ?? 'Kullanıcı',
          receiverName: targetData['name'] ?? 'Kullanıcı',
          requesterPhoto: currentData['photoUrl'],
          receiverPhoto: targetData['photoUrl'],
        );
        if (mounted)
          setState(() {
            _isFollowing = true;
            _isLoading = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isFollowing ? AppColors.surfaceSecondary : AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _isFollowing ? 'Takip' : 'Takip Et',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _isFollowing ? AppColors.textBody : Colors.white,
          ),
        ),
      ),
    );
  }
}
