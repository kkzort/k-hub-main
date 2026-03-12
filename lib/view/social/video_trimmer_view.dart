import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import '../../core/style/app_colors.dart';

class VideoTrimmerView extends StatefulWidget {
  final File videoFile;
  final int? maxDurationSeconds;

  const VideoTrimmerView({
    super.key,
    required this.videoFile,
    this.maxDurationSeconds,
  });

  @override
  State<VideoTrimmerView> createState() => _VideoTrimmerViewState();
}

class _VideoTrimmerViewState extends State<VideoTrimmerView> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isTrimming = false;

  double _startPosition = 0.0; // 0.0 - 1.0 (normalized)
  double _endPosition = 1.0;   // 0.0 - 1.0 (normalized)
  Duration _videoDuration = Duration.zero;
  Duration _selectedStart = Duration.zero;
  Duration _selectedEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    _controller.setLooping(true);

    _videoDuration = _controller.value.duration;

    // Max duration varsa o kadar seçim yap, yoksa tamamını seç
    _startPosition = 0.0;
    if (widget.maxDurationSeconds != null) {
      final maxMs = widget.maxDurationSeconds! * 1000;
      if (_videoDuration.inMilliseconds <= maxMs) {
        _endPosition = 1.0;
      } else {
        _endPosition = maxMs / _videoDuration.inMilliseconds;
      }
    } else {
      _endPosition = 1.0;
    }

    _updateSelectedRange();
    _controller.play();
    _controller.seekTo(_selectedStart);

    // Video pozisyonunu dinle
    _controller.addListener(_onVideoProgress);

    if (mounted) setState(() => _isInitialized = true);
  }

  void _updateSelectedRange() {
    _selectedStart = Duration(
      milliseconds: (_startPosition * _videoDuration.inMilliseconds).round(),
    );
    _selectedEnd = Duration(
      milliseconds: (_endPosition * _videoDuration.inMilliseconds).round(),
    );
  }

  void _onVideoProgress() {
    if (!_controller.value.isPlaying) return;
    final pos = _controller.value.position;
    if (pos >= _selectedEnd) {
      _controller.seekTo(_selectedStart);
    }
  }

  Duration get _selectedDuration => _selectedEnd - _selectedStart;

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    final ms = (d.inMilliseconds % 1000 ~/ 100);
    return '${s.toString().padLeft(2, '0')}.${ms}s';
  }

  Future<void> _trimAndReturn() async {
    if (_isTrimming) return;
    setState(() => _isTrimming = true);

    try {
      _controller.pause();

      // Video compress ile trim et
      final startMs = _selectedStart.inMilliseconds;
      final durationMs = _selectedDuration.inMilliseconds;

      final info = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        startTime: startMs,
        duration: durationMs,
      );

      if (info?.file != null && mounted) {
        Navigator.pop(context, info!.file!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video kırpma başarısız oldu.'), backgroundColor: Colors.red),
          );
          setState(() => _isTrimming = false);
        }
      }
    } catch (e) {
      debugPrint('Video trim error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isTrimming = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video Kırp', style: TextStyle(color: Colors.white)),
        actions: [
          if (_isInitialized && !_isTrimming)
            TextButton(
              onPressed: _trimAndReturn,
              child: Text(
                'Tamam',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isInitialized
          ? Column(
              children: [
                // Video önizleme
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),

                // Trimming kontrolleri
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Süre bilgisi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Başlangıç: ${_formatDuration(_selectedStart)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (widget.maxDurationSeconds == null || _selectedDuration.inSeconds <= widget.maxDurationSeconds!)
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.maxDurationSeconds != null
                                  ? '${_selectedDuration.inSeconds}s / ${widget.maxDurationSeconds}s'
                                  : '${_selectedDuration.inSeconds}s',
                              style: TextStyle(
                                color: (widget.maxDurationSeconds == null || _selectedDuration.inSeconds <= widget.maxDurationSeconds!)
                                    ? AppColors.primary
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'Bitiş: ${_formatDuration(_selectedEnd)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Range Slider
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayColor: AppColors.primary.withValues(alpha: 0.2),
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 10,
                            elevation: 4,
                          ),
                          rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                        ),
                        child: RangeSlider(
                          values: RangeValues(_startPosition, _endPosition),
                          min: 0.0,
                          max: 1.0,
                          onChanged: (values) {
                            double newStart = values.start;
                            double newEnd = values.end;

                            // Max duration varsa aşmasın
                            if (widget.maxDurationSeconds != null) {
                              final maxRange = (widget.maxDurationSeconds! * 1000) /
                                  _videoDuration.inMilliseconds;

                              if (newEnd - newStart > maxRange) {
                                if ((newStart - _startPosition).abs() > (newEnd - _endPosition).abs()) {
                                  newEnd = newStart + maxRange;
                                  if (newEnd > 1.0) {
                                    newEnd = 1.0;
                                    newStart = newEnd - maxRange;
                                  }
                                } else {
                                  newStart = newEnd - maxRange;
                                  if (newStart < 0.0) {
                                    newStart = 0.0;
                                    newEnd = newStart + maxRange;
                                  }
                                }
                              }
                            }

                            setState(() {
                              _startPosition = newStart;
                              _endPosition = newEnd;
                              _updateSelectedRange();
                            });
                            _controller.seekTo(_selectedStart);
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Video toplam süre
                      Text(
                        'Toplam: ${_videoDuration.inSeconds}s',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Trim butonu
                if (_isTrimming)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'Video kırpılıyor...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
