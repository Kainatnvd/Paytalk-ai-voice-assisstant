import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/api_service.dart';

/// Security Screen — exact replication of security_fixed_layout wireframe.
/// OTP verification view for high-value transactions with voice input.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _balance = '\$24,500.00';
  int _secondsLeft = 42;
  Timer? _countdownTimer;
  bool _isRecording = false;
  bool _isProcessing = false;
  List<String> _otpDigits = ['', '', '', '', '', ''];
  int _activeDigit = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startCountdown();
    _fetchBalance();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchBalance() async {
    final result = await _apiService.getBalance();
    if (mounted && result.containsKey('balance')) {
      setState(() {
        _balance = '${result['currency']} ${result['balance']}';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;

    if (_isRecording) {
      setState(() => _isProcessing = true);
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        await _processVoiceOtp(path);
      }

      if (mounted) setState(() => _isProcessing = false);
    } else {
      if (await _audioRecorder.hasPermission()) {
        String? filePath;
        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          filePath = p.join(directory.path, 'otp_voice.wav');
        }

        const config = RecordConfig(encoder: AudioEncoder.wav);
        await _audioRecorder.start(config, path: filePath ?? '');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _processVoiceOtp(String filePath) async {
    final result = await _apiService.processVoice(filePath);
    if (mounted && result['status'] == 'success') {
      final data = result['data'];
      final transcription = data['transcription'] ?? '';

      // Extract digits from transcription
      final digits = transcription.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 6) {
        setState(() {
          for (int i = 0; i < 6; i++) {
            _otpDigits[i] = digits[i];
          }
          _activeDigit = 6;
        });
      }

      // Play audio response
      if (data['response_audio'] != null &&
          data['response_audio'].toString().isNotEmpty) {
        try {
          final bytes = base64Decode(data['response_audio']);
          await _audioPlayer.play(BytesSource(bytes));
        } catch (_) {}
      }
    }
  }

  Future<void> _resendOtp() async {
    await _apiService.sendOtp('');
    if (mounted) {
      setState(() {
        _secondsLeft = 60;
        _otpDigits = ['', '', '', '', '', ''];
        _activeDigit = 0;
      });
      _countdownTimer?.cancel();
      _startCountdown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP has been resent'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedGradientBlob(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildTransactionBadge(),
                      const SizedBox(height: 24),
                      _buildConfirmingAmount(),
                      const SizedBox(height: 48),
                      _buildOtpPrompt(),
                      const SizedBox(height: 32),
                      _buildOtpDigits(),
                      const SizedBox(height: 48),
                      _buildVoiceOrb(),
                      const SizedBox(height: 64),
                      _buildBentoDetails(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header: avatar + PayTalk + shield + balance
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.1)),
                ),
                child: const Icon(Icons.person,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text('PayTalk',
                  style: AppTypography.headlineMedium
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                _balance,
                style: AppTypography.headlineSmall
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "High Value Transaction" badge
  Widget _buildTransactionBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(0.5 + _pulseController.value * 0.5),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            'HIGH VALUE TRANSACTION',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Confirming amount + recipient
  Widget _buildConfirmingAmount() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.displayLarge.copyWith(fontSize: 40),
            children: [
              const TextSpan(text: 'Confirming '),
              TextSpan(
                text: '\$5,200.00',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: const Color(0xFF64748B),
            ),
            children: [
              const TextSpan(text: 'Sending to '),
              TextSpan(
                text: 'Sophia Martinez',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' for Real Estate Deposit.'),
            ],
          ),
        ),
      ],
    );
  }

  /// OTP speaking prompt (English + Urdu)
  Widget _buildOtpPrompt() {
    return Column(
      children: [
        Text(
          'Please speak your 6-digit OTP',
          style: AppTypography.headlineMedium
              .copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'براہ کرم اپنا 6 ہندسوں کا OTP بولیں',
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 18,
            color: AppColors.primary.withOpacity(0.6),
            height: 2.2,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  /// 6-digit OTP input grid
  Widget _buildOtpDigits() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool isActive = index == _activeDigit;
        bool isFilled = _otpDigits[index].isNotEmpty;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 52,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? [
                          Colors.white.withOpacity(0.6),
                          Colors.white.withOpacity(0.3),
                        ]
                      : [
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0.15),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withOpacity(0.6)
                      : Colors.white.withOpacity(0.3),
                  width: isActive ? 2 : 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 15,
                        )
                      ]
                    : null,
              ),
          child: Center(
            child: isActive && !isFilled
                ? AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Text(
                        '|',
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 28,
                          color: AppColors.primary.withOpacity(
                              0.3 + _pulseController.value * 0.7),
                        ),
                      );
                    },
                  )
                : Text(
                    isFilled ? _otpDigits[index] : '0',
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 28,
                      color: isFilled
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
          ),
          ),
        ),
        );
      }),
    );
  }

  /// Voice orb with circular progress + timer
  Widget _buildVoiceOrb() {
    double progress = _secondsLeft / 60.0;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            SizedBox(
              width: 176,
              height: 176,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: AppColors.primary,
                backgroundColor: const Color(0xFFF8FAFC),
                strokeCap: StrokeCap.round,
              ),
            ),
            // Voice orb
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inner pulse on recording - made more visible
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 128 + (20 * _pulseController.value),
                            height: 128 + (20 * _pulseController.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(
                                  0.15 * (1 - _pulseController.value)),
                            ),
                          );
                        },
                      ),
                    Icon(
                      _isRecording ? Icons.graphic_eq : Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                    // Ping rings
                    if (_isRecording)
                      ...List.generate(2, (i) {
                        return AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            double scale =
                                1.0 + (_pulseController.value * 0.3 * (i + 1));
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(
                                        0.2 * (1 - _pulseController.value)),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Timer display
        Text(
          '0:${_secondsLeft.toString().padLeft(2, '0')}',
          style: AppTypography.headlineLarge
              .copyWith(color: AppColors.primary, fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'SECONDS LEFT',
          style: AppTypography.caption.copyWith(
            color: const Color(0xFF94A3B8),
            fontSize: 9,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  /// Bento detail panels: Security Protocol card + Location card + buttons
  Widget _buildBentoDetails() {
    return Column(
      children: [
        // ── Security Protocol Card ──
        BentoCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_user,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURITY PROTOCOL',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Voice Biomarker Active',
                        style: AppTypography.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Our AI is matching your unique vocal pattern and 6-digit code against your encrypted profile.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Location Card with Buttons ──
        BentoCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSACTION LOCATION',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trusted Network • Pakistan',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Cancel + Resend OTP buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        foregroundColor: const Color(0xFF64748B),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                              color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Text('Cancel',
                          style: AppTypography.labelLarge.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _resendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text('Resend OTP',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
