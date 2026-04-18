import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_card.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

import 'transaction_otp_screen.dart';

/// Dashboard Screen — exact replication of dashboard_light_theme wireframe.
/// Voice assistant hub with ethereal orb, mic button, and chat bubbles.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _balance = '...';
  String _userName = 'User';
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isProcessingRecording = false;
  List<ChatMessage> _messages = [];

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _fetchData();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final balanceResult = await _apiService.getBalance();
    final userName = await _apiService.currentUserName;

    if (mounted) {
      setState(() {
        if (balanceResult.containsKey('balance')) {
          _balance =
              '${balanceResult['currency'] ?? 'PKR'} ${balanceResult['balance']}';
        } else {
          _balance = 'Error';
        }
        _userName = userName ?? 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isProcessingRecording) return;

    if (_isRecording) {
      setState(() => _isProcessingRecording = true);
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        await _processVoice(path);
      }

      if (mounted) {
        setState(() => _isProcessingRecording = false);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          path = p.join(directory.path, 'voice_command.wav');
        }

        const config = RecordConfig(encoder: AudioEncoder.wav);
        await _audioRecorder.start(config, path: path ?? '');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _processVoice(String filePath) async {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Analyzing voice command...',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
    });

    final result = await _apiService.processVoice(filePath);

    if (mounted) {
      if (result['status'] == 'success') {
        final data = result['data'];
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: data['transcription'],
            sender: MessageSender.user,
            timestamp: DateTime.now(),
          ));
          _messages.add(ChatMessage(
            text: data['response_text'],
            sender: MessageSender.assistant,
            timestamp: DateTime.now(),
          ));
        });

        // Play audio response if available
        if (data['response_audio'] != null &&
            data['response_audio'].toString().isNotEmpty) {
          try {
            final bytes = base64Decode(data['response_audio']);
            // BytesSource works on all platforms (Web, Android, iOS, Windows)
            await _audioPlayer.play(BytesSource(bytes));
          } catch (_) {}
        }

        // Refresh balance in case it changed
        _fetchData();

        // Check if we need to navigate to OTP screen
        if (data['dialogue_state'] == 'AWAITING_OTP') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionOtpScreen(
                pendingAction: data['pending_action'],
              ),
            ),
          ).then((refreshed) {
            if (refreshed == true) {
              _fetchData(); // Refresh balance and history
            }
          });
        }
      } else {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: result['message'] ?? 'Voice processing failed',
            sender: MessageSender.assistant,
            timestamp: DateTime.now(),
          ));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Ambient Orb Glow ──
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.5 - 300,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primary.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchData,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          _buildEtherealOrb(),
                          const SizedBox(height: 32),
                          _buildVoiceStatus(),
                          const SizedBox(height: 24),
                          _buildMicButton(),
                          const SizedBox(height: 48),
                          _buildChatInterface(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top header bar matching wireframe: Avatar + "Hello, Alex" + PayTalk + Balance pill
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border(
            bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Profile avatar
                GestureDetector(
                  onLongPress: () async {
                    await _apiService.logout();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHighest,
                      border:
                          Border.all(color: AppColors.outline),
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.primary, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'PayTalk',
                        style: AppTypography.headlineLarge.copyWith(
                          color: AppColors.primary,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Balance pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Text(
              _balance,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.onPrimaryContainer,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ethereal orb: radial gradient circles with pulse animation
  Widget _buildEtherealOrb() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        // More dramatic animation when recording
        double scale = _isRecording 
            ? 1.05 + (_orbController.value * 0.08)
            : 1.0 + (_orbController.value * 0.05);
        double translateY = -12.0 * _orbController.value;
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow - significantly more visible when recording
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                return Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _isRecording
                            ? AppColors.primary.withOpacity(0.3 + (_orbController.value * 0.1))
                            : AppColors.primary.withOpacity(0.12),
                        AppColors.primary.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              }
            ),
            // Inner pulse - adds a "breathing" effect
            if (_isRecording)
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, _) {
                  return Container(
                    width: 200 + (20 * _orbController.value),
                    height: 200 + (20 * _orbController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.2 * (1 - _orbController.value)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                }
              ),
            // Center glass circle
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.45),
                border: Border.all(
                    color: AppColors.primary.withOpacity(_isRecording ? 0.3 : 0.1),
                    width: _isRecording ? 2 : 1),
                boxShadow: _isRecording ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ] : null,
              ),
              child: _isRecording ? Center(
                child: Icon(Icons.graphic_eq, color: AppColors.primary.withOpacity(0.6), size: 40),
              ) : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Voice status text matching wireframe: "Say something..." + Urdu
  Widget _buildVoiceStatus() {
    return Column(
      children: [
        Text(
          _isRecording
              ? 'Listening...'
              : (_isProcessingRecording
                  ? 'Processing...'
                  : 'Say something...'),
          style: AppTypography.headlineMedium
              .copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          _isRecording ? 'سن رہا ہوں...' : 'کچھ کہیے...',
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 20,
            color: AppColors.textMuted.withOpacity(0.7),
            height: 2,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  /// Mic button matching wireframe: large circular primary btn with shadow
  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _isProcessingRecording ? null : _toggleRecording,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring on recording
          if (_isRecording)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.1),
                  width: 4,
                ),
              ),
            ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _isRecording ? Colors.redAccent : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording
                          ? Colors.redAccent
                          : AppColors.primary)
                      .withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              size: 36,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Chat interface matching wireframe: AI bubble (left) + User bubble (right)
  Widget _buildChatInterface() {
    if (_messages.isEmpty) {
      // Default welcome message like wireframe
      return Column(
        children: [
          _buildAssistantBubble(
            'How can I help you manage your funds today, $_userName?',
          ),
          const SizedBox(height: 16),
          _buildUserBubble(
            "What's my spending limit for this week?",
          ),
        ],
      );
    }

    return Column(
      children: _messages.map((msg) {
        if (msg.sender == MessageSender.assistant) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAssistantBubble(msg.text),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildUserBubble(msg.text),
          );
        }
      }).toList(),
    );
  }

  Widget _buildAssistantBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondaryContainer,
            border: Border.all(
                color: AppColors.onSecondaryContainer.withOpacity(0.1)),
          ),
          child: const Icon(Icons.smart_toy,
              size: 16, color: AppColors.onSecondaryContainer),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurface, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onPrimaryContainer, height: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // User avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceContainerHighest,
            border: Border.all(color: AppColors.outline),
          ),
          child: const Icon(Icons.person, size: 16, color: AppColors.primary),
        ),
      ],
    );
  }
}
