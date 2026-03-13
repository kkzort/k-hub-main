import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/verified_badge.dart';

class PremiumView extends StatefulWidget {
  const PremiumView({super.key});

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  static const String _premiumMonthlyProductId = 'khub_premium_monthly';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final Set<String> _processedPurchases = <String>{};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _storeAvailable = false;
  bool _isStoreLoading = true;
  bool _isPurchasing = false;
  String? _storeError;
  List<ProductDetails> _products = const <ProductDetails>[];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  ProductDetails? get _premiumProduct {
    for (final product in _products) {
      if (product.id == _premiumMonthlyProductId) return product;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _purchaseSub = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isPurchasing = false;
          _storeError = 'Satın alma akışı sırasında bir hata oluştu.';
        });
      },
    );
    _loadStoreProducts();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _loadStoreProducts() async {
    setState(() {
      _isStoreLoading = true;
      _storeError = null;
    });

    final available = await _inAppPurchase.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _storeAvailable = false;
        _isStoreLoading = false;
        _storeError = 'App Store / Play Store kullanılamıyor.';
      });
      return;
    }

    final response = await _inAppPurchase.queryProductDetails({
      _premiumMonthlyProductId,
    });
    if (!mounted) return;

    if (response.error != null) {
      setState(() {
        _storeAvailable = true;
        _isStoreLoading = false;
        _storeError = response.error!.message;
        _products = const <ProductDetails>[];
      });
      return;
    }

    String? productError;
    if (response.notFoundIDs.contains(_premiumMonthlyProductId)) {
      productError =
          'Premium ürünü mağazada bulunamadı. Ürün kimliğini kontrol et.';
    }

    setState(() {
      _storeAvailable = true;
      _isStoreLoading = false;
      _products = response.productDetails;
      _storeError = productError;
    });
  }

  String _storeSource() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'app_store';
      case TargetPlatform.android:
        return 'play_store';
      default:
        return 'store_unknown';
    }
  }

  Future<bool> _activatePremiumFromPurchase(PurchaseDetails purchase) async {
    final user = _currentUser;
    if (user == null) return false;

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('verifyPremiumPurchase');
      final result = await callable.call({
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'transactionDate': purchase.transactionDate,
        'purchaseStatus': purchase.status.toString().split('.').last,
        'storeSource': _storeSource(),
        'verificationData': {
          'source': purchase.verificationData.source,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
          'localVerificationData':
              purchase.verificationData.localVerificationData,
        },
      });

      final data = result.data;
      return data is Map && data['ok'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _storeError = e.message ?? 'Satın alma doğrulanamadı.';
        });
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    var hasPending = false;

    for (final purchase in purchaseDetailsList) {
      final purchaseKey =
          purchase.purchaseID ??
          '${purchase.productID}_${purchase.transactionDate ?? ''}';

      if (purchase.status == PurchaseStatus.pending) {
        hasPending = true;
      } else if (purchase.status == PurchaseStatus.error) {
        _showMessage(
          purchase.error?.message ?? 'Satın alma başarısız oldu.',
          isError: true,
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (!_processedPurchases.contains(purchaseKey)) {
          _processedPurchases.add(purchaseKey);
          final activated = await _activatePremiumFromPurchase(purchase);
          if (activated) {
            _showMessage(
              'Premium aktif edildi. Satın alma kaydın işlendi.',
            );
          } else {
            _showMessage(
              'Satın alma alındı fakat premium doğrulanamadı. Tekrar dene.',
              isError: true,
            );
          }
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }

    if (!mounted) return;
    setState(() {
      _isPurchasing = hasPending;
    });
  }

  Future<void> _buyPremium() async {
    final product = _premiumProduct;
    if (!_storeAvailable) {
      _showMessage('Mağaza şu anda kullanılamıyor.', isError: true);
      return;
    }
    if (product == null) {
      _showMessage(
        'Premium ürünü bulunamadı. Ürün kimliğini kontrol et.',
        isError: true,
      );
      return;
    }
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _storeError = null;
    });

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        if (!mounted) return;
        setState(() => _isPurchasing = false);
        _showMessage('Satın alma başlatılamadı.', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      _showMessage('Satın alma sırasında hata oluştu.', isError: true);
    }
  }

  Future<void> _restorePremium() async {
    if (_isPurchasing) return;
    try {
      setState(() => _isPurchasing = true);
      await _inAppPurchase.restorePurchases();
      _showMessage('Satın alımların geri yükleniyor...');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      _showMessage('Geri yükleme başlatılamadı.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Premium'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textHeader,
        ),
        body: Center(
          child: Text(
            'Premium icin once giris yapman gerekiyor.',
            style: TextStyle(color: AppColors.textBody),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final isPremium =
            userData?['isPremium'] == true ||
            userData?['premiumStatus'] == 'active';
        final planPrice =
            _premiumProduct?.price ??
            (_isStoreLoading ? 'Fiyat yukleniyor...' : 'Magaza fiyatı yok');
        final activatedAt = userData?['premiumActivatedAt'] as Timestamp?;
        final activatedText = activatedAt == null
            ? 'Henüz aktif değil'
            : '${activatedAt.toDate().day}.${activatedAt.toDate().month}.${activatedAt.toDate().year}';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Premium'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textHeader,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10203C),
                        Color(0xFF15386B),
                        Color(0xFF1DA1F2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DA1F2).withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const VerifiedBadge(
                              type: 'verified',
                              size: 26,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isPremium ? 'AKTIF' : 'OGRENCI PLANI',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'K-Hub Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPremium
                            ? 'Premium hesabin aktif. Mavi tik ve premium ozelliklerin hazir.'
                            : 'Mavi tik, premium rozet ve gelecek ekstra ozellikler icin ogrenci premium planini aktif et.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            '$planPrice / ay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Aktivasyon: $activatedText',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _PremiumInfoCard(
                  title: 'Aninda acilan premium haklari',
                  children: const [
                    _PremiumFeatureRow(
                      icon: Icons.verified_rounded,
                      title: 'Mavi tik',
                      subtitle:
                          'Premium alan ogrenciler profilde ve listelerde mavi tik alir.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.visibility_outlined,
                      title: 'Tum profil ziyaretcileri',
                      subtitle:
                          'Ziyaret edenlerin tamamini blur olmadan gorebilirsin.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'K-Bot AI',
                      subtitle:
                          'PDF ve fotograf yukleyip ozet cikarabilir, ana noktalar ve dokuman bazli soru-cevap alabilirsin.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Premium altyapi',
                      subtitle:
                          'Ekstra ozellikler sonradan bu planin ustune kolayca eklenebilir.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PremiumInfoCard(
                  title: 'Yakinda eklenebilecek ekstralar',
                  children: const [
                    _PremiumFeatureRow(
                      icon: Icons.palette_outlined,
                      title: 'Ozel profil temalari',
                      subtitle:
                          'Profil kartinda premium gorunum ve vurgu renkleri.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.forum_outlined,
                      title: 'Gelişmis mesaj avantajlari',
                      subtitle:
                          'Mesaj kutusunda ekstra filtre ve sabitleme ozellikleri.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.star_outline_rounded,
                      title: 'Toplululuk avantajlari',
                      subtitle:
                          'Premium kullanicilara ozel rozet ve on plana cikma alanlari.',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (isPremium ||
                            _isPurchasing ||
                            _isStoreLoading ||
                            !_storeAvailable)
                        ? null
                        : _buyPremium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DA1F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isPremium
                          ? 'Premium zaten aktif'
                          : _isPurchasing
                          ? 'Satın alma isleniyor...'
                          : _isStoreLoading
                          ? 'Magaza hazirlaniyor...'
                          : !_storeAvailable
                          ? 'Magaza kullanılamıyor'
                          : 'Premiumu satin al',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isPurchasing ? null : _restorePremium,
                    child: const Text('Satın alımları geri yükle'),
                  ),
                ),
                if (_storeError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _storeError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                Text(
                  'Not: Mağaza ürün kimliği "khub_premium_monthly" olarak beklenir. Üretimde satın alma fişi backend tarafında doğrulanmalıdır.',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PremiumInfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textHeader,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1DA1F2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1DA1F2), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
