import 'package:flutter/material.dart';
import '../../core/style/app_colors.dart';


class AiChatView extends StatefulWidget {
  final Color kPrimaryColor;
  const AiChatView({super.key, required this.kPrimaryColor});

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // Basit kampüs asistanı – offline çalışır, keyword matching
  final Map<String, String> _responses = {
    'merhaba': 'Merhaba! 👋 Ben K-Hub Kampüs Asistanınız. Size nasıl yardımcı olabilirim?',
    'selam': 'Selam! 😊 Ben K-Hub yapay zeka asistanıyım. Kampüs hakkında soru sorabilirsiniz!',
    'yemekhane': '🍽️ Yemekhane Bilgileri:\n\n• Çalışma Saatleri: 07:30 - 20:00\n• Öğle yemeği: 11:30 - 14:00\n• Akşam yemeği: 17:00 - 19:30\n• Menüyü görmek için Araçlar > Yemekhane ekranını ziyaret edebilirsiniz.',
    'kütüphane': '📚 Kütüphane Bilgileri:\n\n• Çalışma Saatleri: 08:00 - 23:00\n• 50.000+ kitap koleksiyonu\n• Bireysel ve grup çalışma odaları\n• Dijital kaynak erişimi\n• Sessiz alan mevcut',
    'sınav': '📝 Sınav Bilgileri:\n\nAkademik takvime göre sınav tarihleri:\n• Güz yarıyılı sonu: Ocak\n• Bahar yarıyılı sonu: Haziran\n• Bütünleme sınavları: Sınav döneminden 2 hafta sonra\n\nDetaylar için Araçlar > Akademik Takvim sayfasına bakın.',
    'kayıt': '📋 Kayıt İşlemleri:\n\n• Ders kayıt yenileme her dönem başında yapılır\n• Katkı payı ödemeleri kayıt haftasında yapılmalıdır\n• Ders ekle/bırak kayıttan 1 hafta sonra açılır\n\nDetaylar için Akademik Takvimi kontrol edin.',
    'burs': '💰 Burs Bilgileri:\n\n• KYK burs başvuruları her yıl Eylül-Ekim aylarında\n• Üniversite başarı bursu: GPA 3.0+\n• Spor bursu: Üniversite takımlarına katılım\n• Daha fazla bilgi için Öğrenci İşleri\'ne başvurun.',
    'kulüp': '🎭 Öğrenci Kulüpleri:\n\n• Bilişim Kulübü\n• Müzik Topluluğu\n• Fotoğrafçılık Kulübü\n• Girişimcilik Kulübü\n• Spor Kulüpleri\n\nKulüpler hakkında bilgi için Öğrenci Merkezi\'ni ziyaret edin.',
    'ulaşım': '🚌 Ulaşım Bilgileri:\n\n• Kampüs servisi: Şehir merkezinden her 30 dakikada\n• İlk sefer: 07:00 | Son sefer: 22:00\n• Otobüs hatları: 11, 23, 45\n• Kampüs içi ring servisi mevcut',
    'wifi': '📶 WiFi Bilgileri:\n\n• Ağ adı: KampusWiFi\n• Öğrenci numarası ve şifre ile giriş\n• Eduroam desteği mevcut\n• Sorun yaşarsanız IT Destek: it@universite.edu.tr',
    'staj': '💼 Staj Bilgileri:\n\n• Zorunlu staj süreleri bölüme göre değişir\n• Staj başvuru dönemi: Şubat-Mart\n• Staj defterleri dönem sonunda teslim\n• Detaylar için bölüm staj koordinatörüne başvurun.',
    'not': '📝 Not Sistemi:\n\n• AA: 90-100 (4.0)\n• BA: 85-89 (3.5)\n• BB: 80-84 (3.0)\n• CB: 75-79 (2.5)\n• CC: 70-74 (2.0)\n• DC: 60-69 (1.5)\n• DD: 50-59 (1.0)\n• FF: 0-49 (0.0)',
    'spor': '⚽ Spor Tesisleri:\n\n• Kapalı spor salonu: 07:00 - 22:00\n• Fitness salonu: 07:00 - 22:00\n• Yüzme havuzu: 10:00 - 20:00\n• Açık saha: Gün boyunca\n• Öğrenci kartı ile ücretsiz kullanım',
    'etkinlik': '🎉 Etkinlikler:\n\nGüncel etkinlikleri görmek için Araçlar > Etkinlik Takvimi sayfasını ziyaret edebilirsiniz.\n\nÖnemli etkinlikler ayrıca bildiri olarak da gönderilmektedir.',
    'teşekkür': 'Rica ederim! 😊 Başka sorularınız varsa her zaman yardımcı olmaktan mutluluk duyarım.',
    'teşekkürler': 'Rica ederim! 😊 Her zaman buradayım. Başka bir şey sormak ister misiniz?',
  };

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': DateTime.now(),
      });
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Simüle edilmiş düşünme süresi
    await Future.delayed(const Duration(milliseconds: 800));

    final response = _getResponse(text);

    setState(() {
      _isTyping = false;
      _messages.add({
        'text': response,
        'isUser': false,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  String _getResponse(String input) {
    final lower = input.toLowerCase();

    for (var entry in _responses.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Genel soru kalıpları
    if (lower.contains('nasıl') || lower.contains('nerede') || lower.contains('ne zaman')) {
      return '🤔 Bu konuda kesin bilgi veremiyorum, ancak size yardımcı olabilecek bazı kaynaklar:\n\n• Öğrenci İşleri: 0312 XXX XXXX\n• Bilgi Hattı: info@universite.edu.tr\n• K-Hub uygulamasındaki diğer araçlara göz atabilirsiniz.';
    }

    if (lower.contains('saat') || lower.contains('çalışma')) {
      return '🕐 Genel Çalışma Saatleri:\n\n• Derslikler: 08:00 - 22:00\n• Kütüphane: 08:00 - 23:00\n• Yemekhane: 07:30 - 20:00\n• Spor Merkezi: 07:00 - 22:00\n• Öğrenci İşleri: 08:30 - 17:30';
    }

    return '🤖 Size daha iyi yardımcı olabilmem için şu konularda soru sorabilirsiniz:\n\n• 🍽️ Yemekhane\n• 📚 Kütüphane\n• 📝 Sınavlar & Notlar\n• 📋 Kayıt İşlemleri\n• 💰 Burslar\n• 🎭 Kulüpler\n• 🚌 Ulaşım\n• 📶 WiFi\n• 💼 Staj\n• ⚽ Spor\n• 🎉 Etkinlikler';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Hoşgeldin mesajı
    _messages.add({
      'text':
          '🤖 Merhaba! Ben K-Hub Kampüs Asistanı.\n\nSize kampüs hakkında sorular konusunda yardımcı olabilirim. Örneğin:\n\n• "Yemekhane saatleri ne?"\n• "Kütüphane nerede?"\n• "Sınav tarihleri"\n• "WiFi nasıl bağlanırım?"\n\nSormak istediğiniz bir şey var mı? 😊',
      'isUser': false,
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, size: 22),
            SizedBox(width: 8),
            Text("Kampüs Asistanı"),
          ],
        ),
        backgroundColor: widget.kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Mesajlar
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  // Typing indicator
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.kPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Düşünüyorum...",
                            style: TextStyle(
                              color: AppColors.textBody,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: isUser
                           ? widget.kPrimaryColor
                           : AppColors.surface,

                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomRight: isUser
                            ? Radius.zero
                            : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.smart_toy,
                                    size: 14, color: widget.kPrimaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  "K-Hub AI",
                                  style: TextStyle(
                                    color: widget.kPrimaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          msg['text'] as String,
                          style: TextStyle(
                            color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Hızlı sorular
          if (_messages.length <= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickButton("🍽️ Yemekhane"),
                    _quickButton("📚 Kütüphane"),
                    _quickButton("📝 Sınav"),
                    _quickButton("📶 WiFi"),
                    _quickButton("🚌 Ulaşım"),
                    _quickButton("⚽ Spor"),
                  ],
                ),
              ),
            ),
          // Mesaj girişi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Bir soru sorun...",
                      hintStyle: TextStyle(color: AppColors.textBody),
                      fillColor: AppColors.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: widget.kPrimaryColor,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickButton(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () {
          _controller.text = label;
          _sendMessage();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.kPrimaryColor,
          side: BorderSide(color: widget.kPrimaryColor.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
