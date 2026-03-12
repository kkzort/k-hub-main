import 'package:flutter/material.dart';

class PreviewableProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PreviewableProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.backgroundColor,
    this.placeholder,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundImage: hasImage ? NetworkImage(normalizedUrl) : null,
      backgroundColor: backgroundColor,
      child: hasImage ? null : placeholder,
    );

    if (!hasImage && onTap == null && onLongPress == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: hasImage
          ? (onLongPress ??
                () => showProfilePhotoPreview(context, normalizedUrl))
          : onLongPress,
      child: avatar,
    );
  }
}

Future<void> showProfilePhotoPreview(BuildContext context, String imageUrl) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Profil fotografi onizleme',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final mediaQuery = MediaQuery.of(dialogContext);

      return SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: Container(
                  width: mediaQuery.size.width - 32,
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    maxHeight: mediaQuery.size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }

                              final expected =
                                  loadingProgress.expectedTotalBytes;
                              final value = expected == null
                                  ? null
                                  : loadingProgress.cumulativeBytesLoaded /
                                        expected;

                              return Center(
                                child: CircularProgressIndicator(
                                  value: value,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 54,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
