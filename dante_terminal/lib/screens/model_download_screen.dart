/// Terminal-styled model download screen for first-run onboarding (BL-129).
///
/// When no .gguf model file is found on the device, this screen guides the
/// user through downloading the AI Game Master engine. It wires into
/// [ModelDownloadService] for progress streaming, pause/resume, and SHA-256
/// verification. On successful download it calls [onDownloadComplete] so the
/// parent can navigate to the game.
///
/// See also:
/// - BL-087: Model delivery strategy (hosting, download UX spec)
/// - BL-123: Model selection (Qwen2 1.5B Q4_K_M primary pick)
/// - BL-126: ModelDownloadService implementation
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/model_download_service.dart';

// ---------------------------------------------------------------------------
// Model configuration constants
// ---------------------------------------------------------------------------

/// Download URL for Qwen2 1.5B Instruct Q4_K_M (BL-123 primary pick).
const kDefaultModelUrl =
    'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/'
    'qwen2-1_5b-instruct-q4_k_m.gguf';

/// Filename stored in app documents directory.
///
/// Matches [InferenceService._findModelInDocuments]'s preferred-name list
/// so the model is auto-discovered on subsequent launches.
const kModelFileName = 'model.gguf';

// ---------------------------------------------------------------------------
// ModelDownloadScreen
// ---------------------------------------------------------------------------

/// Full-screen download UI with ASCII progress bar and retro terminal styling.
///
/// Lifecycle phases: ready -> downloading -> (verifying) -> completed -> [callback]
/// On error: error -> [retry button] -> downloading -> ...
class ModelDownloadScreen extends StatefulWidget {
  /// Called once the model file is on disk and verified. The parent widget
  /// should respond by showing the game screen (e.g. [TerminalScreen]).
  final VoidCallback onDownloadComplete;

  const ModelDownloadScreen({super.key, required this.onDownloadComplete});

  @override
  State<ModelDownloadScreen> createState() => ModelDownloadScreenState();
}

/// Visible for testing.
class ModelDownloadScreenState extends State<ModelDownloadScreen> {
  // ─── Phase machine ──────────────────────────────────────────────────
  _Phase _phase = _Phase.ready;

  // ─── Services ───────────────────────────────────────────────────────
  late ModelDownloadService _downloadService;
  StreamSubscription<double>? _progressSub;

  // ─── Progress state ─────────────────────────────────────────────────
  double _progress = 0.0;
  int _bytesDownloaded = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  // ─── Speed / ETA tracking ───────────────────────────────────────────
  double _speedBps = 0;
  int _prevSampleBytes = 0;
  DateTime _prevSampleTime = DateTime.now();
  final List<double> _recentSpeeds = [];
  Timer? _speedTimer;

  // ─── Flavor text rotation ──────────────────────────────────────────
  int _flavorIdx = 0;
  Timer? _flavorTimer;

  static const _flavorTexts = [
    'Initializing neural pathways...',
    'Loading dungeon cartography...',
    'Calibrating narrative engine...',
    'Mapping adventure manifold...',
    'Compiling story fragments...',
    'Assembling AI Game Master...',
    'Forging digital consciousness...',
    'Decrypting ancient algorithms...',
  ];

  // ─── Theme constants (match TerminalScreen) ─────────────────────────
  static const _green = Color(0xFF00FF41);
  static const _dim = Color(0xFF00AA2A);
  static const _bg = Color(0xFF0A0A0A);

  // ─── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _downloadService = ModelDownloadService();
    _flavorTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_phase == _Phase.downloading && mounted) {
        setState(() => _flavorIdx = (_flavorIdx + 1) % _flavorTexts.length);
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _speedTimer?.cancel();
    _flavorTimer?.cancel();
    _downloadService.dispose();
    super.dispose();
  }

  // ─── Download orchestration ─────────────────────────────────────────

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0.0;
      _bytesDownloaded = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _speedBps = 0;
      _recentSpeeds.clear();
    });

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final destPath = '${docsDir.path}/$kModelFileName';

      final config = ModelDownloadConfig(
        url: Uri.parse(kDefaultModelUrl),
        destinationPath: destPath,
      );

      // Reset speed sampling baseline
      _prevSampleTime = DateTime.now();
      _prevSampleBytes = 0;

      _speedTimer?.cancel();
      _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _sampleSpeed();
      });

      _progressSub?.cancel();
      _progressSub = _downloadService.progress.listen((p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _bytesDownloaded = _downloadService.bytesDownloaded;
          _totalBytes = _downloadService.totalBytes;
          if (_downloadService.status == DownloadStatus.verifying) {
            _phase = _Phase.verifying;
          }
        });
      });

      await _downloadService.download(config);

      _speedTimer?.cancel();
      if (!mounted) return;

      setState(() => _phase = _Phase.completed);

      // Brief pause to show the "loaded" message (BL-087: 3 s delay)
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onDownloadComplete();
    } catch (e) {
      _speedTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = _friendlyError(e);
      });
    }
  }

  void _sampleSpeed() {
    final now = DateTime.now();
    final ms = now.difference(_prevSampleTime).inMilliseconds;
    if (ms <= 0) return;

    final delta = _downloadService.bytesDownloaded - _prevSampleBytes;
    final bps = (delta / ms) * 1000;

    _recentSpeeds.add(bps);
    if (_recentSpeeds.length > 5) _recentSpeeds.removeAt(0);

    _prevSampleBytes = _downloadService.bytesDownloaded;
    _prevSampleTime = now;

    if (_recentSpeeds.isNotEmpty && mounted) {
      setState(() {
        _speedBps =
            _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
      });
    }
  }

  static String _friendlyError(Object error) {
    if (error is ChecksumMismatchException) {
      return 'Download corrupted during transfer. Please try again.';
    }
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Network connection lost. Check your internet and try again.';
    }
    if (msg.contains('FileSystemException') || msg.contains('No space')) {
      return 'Not enough storage space. Free up at least 1 GB and try again.';
    }
    return 'Download failed. Please check your connection and try again.';
  }

  // ─── Formatting helpers ─────────────────────────────────────────────

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _fmtSpeed(double bps) {
    if (bps <= 0) return '-- MB/s';
    if (bps < 1024) return '${bps.toStringAsFixed(0)} B/s';
    if (bps < 1024 * 1024) {
      return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  static String _fmtEta(double bps, int remaining) {
    if (bps <= 0 || remaining <= 0) return '--:--';
    final secs = (remaining / bps).round();
    if (secs < 60) return '${secs}s';
    if (secs < 3600) return '${secs ~/ 60}m ${secs % 60}s';
    return '${secs ~/ 3600}h ${(secs % 3600) ~/ 60}m';
  }

  static String _asciiBar(double progress, int width) {
    final filled = (progress * width).round().clamp(0, width);
    final empty = width - filled;
    return '[${('#' * filled)}${('-' * empty)}]';
  }

  // ─── Widget builders ────────────────────────────────────────────────

  Widget _t(
    String text, {
    double size = 14,
    bool bold = false,
    bool dim = false,
    double spacing = 0,
    Color? color,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color ?? (dim ? _dim : _green),
        letterSpacing: spacing,
        height: 1.4,
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _t('DANTE TERMINAL', size: 22, bold: true, spacing: 4),
        const SizedBox(height: 8),
        _t('\u2500' * 36),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: _green),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _t(label, bold: true),
        ),
      ),
    );
  }

  // ─── Phase screens ──────────────────────────────────────────────────

  Widget _buildReady() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _t('AI ENGINE REQUIRED', bold: true),
        const SizedBox(height: 16),
        _t('DANTE TERMINAL requires a one-time', dim: true),
        _t('download of the AI Game Master engine.', dim: true),
        _t('This enables fully offline gameplay.', dim: true),
        const SizedBox(height: 16),
        _t('Model: Qwen2-1.5B-Instruct', dim: true),
        _t('Size:  ~986 MB', dim: true),
        const SizedBox(height: 32),
        _actionButton('[ DOWNLOAD NOW ]', _startDownload),
      ],
    );
  }

  Widget _buildDownloading() {
    final pct = (_progress * 100).toStringAsFixed(1);
    final bytesStr = _fmtBytes(_bytesDownloaded);
    final totalStr = _totalBytes > 0 ? ' / ${_fmtBytes(_totalBytes)}' : '';
    final remaining = _totalBytes > 0 ? _totalBytes - _bytesDownloaded : 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _t('DOWNLOADING AI ENGINE...', bold: true),
        const SizedBox(height: 20),
        _t(_asciiBar(_progress, 30)),
        const SizedBox(height: 12),
        _t('$pct%  $bytesStr$totalStr'),
        const SizedBox(height: 12),
        _t('SPEED: ${_fmtSpeed(_speedBps)}', dim: true),
        _t('ETA:   ${_fmtEta(_speedBps, remaining)}', dim: true),
        const SizedBox(height: 24),
        _t(_flavorTexts[_flavorIdx], dim: true),
      ],
    );
  }

  Widget _buildVerifying() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _t('VERIFYING INTEGRITY...', bold: true),
        const SizedBox(height: 20),
        _t(_asciiBar(1.0, 30)),
        const SizedBox(height: 12),
        _t('Computing SHA-256 checksum...', dim: true),
      ],
    );
  }

  Widget _buildCompleted() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _t('AI ENGINE LOADED', bold: true),
        const SizedBox(height: 16),
        _t('READY TO EXPLORE.'),
        const SizedBox(height: 8),
        _t('Launching adventure...', dim: true),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _t('[ERR] DOWNLOAD FAILED', color: Colors.red, bold: true),
        const SizedBox(height: 16),
        _t(_errorMessage ?? 'Unknown error occurred.', dim: true),
        const SizedBox(height: 32),
        _actionButton('[ RETRY ]', _startDownload),
      ],
    );
  }

  // ─── Main build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: switch (_phase) {
            _Phase.ready => _buildReady(),
            _Phase.downloading => _buildDownloading(),
            _Phase.verifying => _buildVerifying(),
            _Phase.completed => _buildCompleted(),
            _Phase.error => _buildError(),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private types
// ---------------------------------------------------------------------------

enum _Phase { ready, downloading, verifying, completed, error }
