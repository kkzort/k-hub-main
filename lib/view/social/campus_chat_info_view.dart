import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/style/app_colors.dart';
import '../../service/chat_settings_service.dart';

class CampusChatInfoView extends StatefulWidget {
  final bool isAdmin;

  const CampusChatInfoView({super.key, required this.isAdmin});

  @override
  State<CampusChatInfoView> createState() => _CampusChatInfoViewState();
}

class _CampusChatInfoViewState extends State<CampusChatInfoView> {
  final ChatSettingsService _settingsService = ChatSettingsService();

  bool _mediaUploadEnabled = false;
  bool _autoDeleteEnabled = false;
  int _autoDeleteDays = 7;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    if (mounted) {
      setState(() {
        _mediaUploadEnabled = settings['mediaUploadEnabled'] == true;
        _autoDeleteEnabled = settings['autoDeleteEnabled'] == true;
        _autoDeleteDays = settings['autoDeleteDays'] as int? ?? 7;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _settingsService.updateSettings({key: value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
        title: const Text('Grup Bilgisi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Grup ikonu ve başlık
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.groups_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kampüs Sohbet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeader,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kırıkkale Üniversitesi öğrenci sohbeti',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textBody,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Üye sayısı
                  FutureBuilder<AggregateQuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .where('isApproved', isEqualTo: true)
                        .count()
                        .get(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.count ?? 0;
                      return Text(
                        '$count üye',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Yönetici ayarları bölümü
                  if (widget.isAdmin) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Yönetici Ayarları',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHeader,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Medya paylaşımı switch
                          _buildSettingSwitch(
                            icon: Icons.photo_library_rounded,
                            title: 'Medya Paylaşımı',
                            subtitle: 'Üyelerin fotoğraf, video ve dosya göndermesine izin ver',
                            value: _mediaUploadEnabled,
                            onChanged: (val) {
                              setState(() => _mediaUploadEnabled = val);
                              _updateSetting('mediaUploadEnabled', val);
                            },
                          ),

                          const Divider(height: 1, indent: 56),

                          // Kaybolan mesajlar switch
                          _buildSettingSwitch(
                            icon: Icons.timer_outlined,
                            title: 'Kaybolan Mesajlar',
                            subtitle: 'Mesajlar belirlenen süre sonra otomatik silinir',
                            value: _autoDeleteEnabled,
                            onChanged: (val) {
                              setState(() => _autoDeleteEnabled = val);
                              _updateSetting('autoDeleteEnabled', val);
                            },
                          ),

                          // Süre seçici (sadece kaybolan mesajlar açıksa)
                          if (_autoDeleteEnabled) ...[
                            const Divider(height: 1, indent: 56),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(56, 12, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mesaj süresi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textBody,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _buildDayChip(1),
                                      const SizedBox(width: 8),
                                      _buildDayChip(7),
                                      const SizedBox(width: 8),
                                      _buildDayChip(30),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Admin değilse bilgi kartı
                  if (!widget.isAdmin) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.photo_library_rounded,
                            'Medya Paylaşımı',
                            _mediaUploadEnabled ? 'Açık' : 'Kapalı',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Kaybolan Mesajlar',
                            _autoDeleteEnabled
                                ? '$_autoDeleteDays gün'
                                : 'Kapalı',
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                ),
              ],
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

  Widget _buildDayChip(int days) {
    final isSelected = _autoDeleteDays == days;
    return GestureDetector(
      onTap: () {
        setState(() => _autoDeleteDays = days);
        _updateSetting('autoDeleteDays', days);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          '$days gün',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textHeader,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHeader,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
