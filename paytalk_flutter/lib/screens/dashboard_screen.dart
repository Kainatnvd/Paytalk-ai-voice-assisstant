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
import '../widgets/glass_card.dart';
import '../widgets/mesh_gradient_background.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../widgets/bottom_dock.dart';

import 'transaction_otp_screen.dart';
import 'transaction_pin_screen.dart';
import 'number_input_screen.dart';

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
  final GlobalKey _micKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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
    AppFloatingDock.micScrollNotifier.addListener(_scrollToMic);
  }

  @override
  void dispose() {
    AppFloatingDock.micScrollNotifier.removeListener(_scrollToMic);
    _scrollController.dispose();
    _orbController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _apiService.dispose();
    super.dispose();
  }

  void _scrollToMic() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_micKey.currentContext != null) {
        Scrollable.ensureVisible(
          _micKey.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    });
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

      // Brief delay to capture trailing audio (prevents last word being clipped)
      await Future.delayed(const Duration(milliseconds: 500));

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
            payload: data['payload'] != null ? Map<String, dynamic>.from(data['payload']) : null,
          ));
        });

        // Play audio response if available
        if (data['response_audio'] != null &&
            data['response_audio'].toString().isNotEmpty) {
          try {
            final audioB64 = data['response_audio'].toString();
            
            if (kIsWeb) {
              // On Web/Chrome, create a data URL — gTTS generates MP3 (mpeg)
              final dataUrl = 'data:audio/mpeg;base64,$audioB64';
              await _audioPlayer.play(UrlSource(dataUrl));
            } else {
              // On mobile/desktop, BytesSource works fine
              final bytes = base64Decode(audioB64);
              await _audioPlayer.play(BytesSource(bytes));
            }
            
            debugPrint('[Audio] Playing TTS response');
          } catch (e) {
            debugPrint('[Audio] Playback error: $e');
          }
        }

        // Refresh balance in case it changed
        _fetchData();

        // Check if we need to navigate to PIN screen
        if (data['dialogue_state'] == 'AWAITING_PIN') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionPinScreen(
                pendingAction: data['pending_action'],
              ),
            ),
          ).then((result) {
            if (result != null && result is Map<String, dynamic>) {
              // The PIN was successful and returned the next state (likely AWAITING_OTP)
              _handleDialogueState(result);
            }
          });
        }
        
        // Check if we need to navigate to OTP screen
        if (data['dialogue_state'] == 'AWAITING_OTP') {
          _navigateToOtp(data);
        }

        // Check if we need to navigate to Number Input screen
        if (data['dialogue_state'] == 'AWAITING_RAAST_ID' ||
            data['dialogue_state'] == 'AWAITING_REFERENCE_NUMBER' ||
            data['dialogue_state'] == 'AWAITING_ACCOUNT_NUMBER') {
          _navigateToNumberInput(data);
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

  void _handleDialogueState(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: data['response_text'],
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
          payload: data['payload'] != null ? Map<String, dynamic>.from(data['payload']) : null,
        ));
      });

      // Play audio response if available
      if (data['response_audio'] != null && data['response_audio'].toString().isNotEmpty) {
        try {
          final bytes = base64Decode(data['response_audio'].toString());
          _audioPlayer.play(BytesSource(bytes));
        } catch (e) {
          debugPrint('[Audio] Playback error: $e');
        }
      }

      if (data['dialogue_state'] == 'AWAITING_PIN') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionPinScreen(
              pendingAction: data['pending_action'],
            ),
          ),
        ).then((result) {
          if (result != null && result is Map<String, dynamic>) {
            _handleDialogueState(result);
          }
        });
      } else if (data['dialogue_state'] == 'AWAITING_OTP') {
        _navigateToOtp(data);
      } else if (data['dialogue_state'] == 'AWAITING_RAAST_ID' ||
                 data['dialogue_state'] == 'AWAITING_REFERENCE_NUMBER' ||
                 data['dialogue_state'] == 'AWAITING_ACCOUNT_NUMBER') {
        _navigateToNumberInput(data);
      }
    }
  }

  void _navigateToOtp(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionOtpScreen(
          pendingAction: data['pending_action'],
        ),
      ),
    ).then((refreshed) {
      if (refreshed == true) {
        _fetchData();
      }
    });
  }

  void _navigateToNumberInput(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NumberInputScreen(
          dialogueState: data['dialogue_state'],
          pendingAction: data['pending_action'] ?? {},
        ),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _handleDialogueState(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedGradientBlob(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchData,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
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
      ),
    );
  }

  /// Top header bar — frosted glass with liquid shine
  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.5),
                Colors.white.withOpacity(0.2),
              ],
            ),
            border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.3))),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.accent.withOpacity(0.1),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.person,
                            color: AppColors.primary, size: 22),
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
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.primaryGradient.createShader(bounds),
                            child: Text(
                              'PayTalk',
                              style: AppTypography.headlineLarge.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Balance pill — frosted glass
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.accent.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4)),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ethereal orb: multi-layered gradient rings with pulse animation
  Widget _buildEtherealOrb() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        double scale = _isRecording 
            ? 1.05 + (_orbController.value * 0.08)
            : 1.0 + (_orbController.value * 0.04);
        double translateY = -10.0 * _orbController.value;
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Layer 1: Outermost soft halo ──
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                return Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _isRecording
                            ? const Color(0xFF818CF8).withOpacity(0.2 + (_orbController.value * 0.1))
                            : const Color(0xFF818CF8).withOpacity(0.06),
                        const Color(0xFF6366F1).withOpacity(0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              }
            ),

            // ── Layer 2: Secondary ring ──
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                final ringOpacity = _isRecording 
                    ? 0.15 + (_orbController.value * 0.1) 
                    : 0.06 + (_orbController.value * 0.03);
                return Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF818CF8).withOpacity(ringOpacity),
                      width: 1.5,
                    ),
                  ),
                );
              }
            ),

            // ── Layer 3: Inner glow ring ──
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                final size = _isRecording 
                    ? 200.0 + (16 * _orbController.value) 
                    : 200.0;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _isRecording
                            ? const Color(0xFF6366F1).withOpacity(0.25 * (1 - _orbController.value * 0.5))
                            : const Color(0xFF6366F1).withOpacity(0.08),
                        _isRecording
                            ? const Color(0xFF818CF8).withOpacity(0.12)
                            : const Color(0xFF818CF8).withOpacity(0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              }
            ),

            // ── Layer 4: Recording pulse ring ──
            if (_isRecording)
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, _) {
                  return Container(
                    width: 180 + (30 * _orbController.value),
                    height: 180 + (30 * _orbController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3 * (1 - _orbController.value)),
                        width: 2,
                      ),
                    ),
                  );
                }
              ),

            // ── Center glass circle — liquid glass ──
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(_isRecording ? 0.6 : 0.4),
                        Colors.white.withOpacity(_isRecording ? 0.3 : 0.15),
                        AppColors.accent.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: _isRecording 
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.35),
                      width: _isRecording ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(_isRecording ? 0.25 : 0.1),
                        blurRadius: _isRecording ? 50 : 25,
                        spreadRadius: _isRecording ? 8 : 2,
                      ),
                      BoxShadow(
                        color: AppColors.accent.withOpacity(_isRecording ? 0.15 : 0.05),
                        blurRadius: 30,
                        spreadRadius: -5,
                        offset: const Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _orbController,
                      builder: (context, _) {
                        return ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return AppColors.accentGradient.createShader(bounds);
                          },
                          child: Icon(
                            _isRecording ? Icons.graphic_eq : Icons.auto_awesome,
                            size: _isRecording ? 44 : 36,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
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

  /// Mic button — premium gradient with liquid glass glow
  Widget _buildMicButton() {
    return Container(
      key: _micKey,
      child: GestureDetector(
        onTap: _isProcessingRecording ? null : _toggleRecording,
        child: AnimatedBuilder(
          animation: _orbController,
          builder: (context, _) {
            final pulseSize = _isRecording
                ? 110.0 + (15 * _orbController.value)
                : 100.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ring on recording
                if (_isRecording)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: pulseSize,
                    height: pulseSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.2 * (1 - _orbController.value)),
                        width: 3,
                      ),
                    ),
                  ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isRecording
                        ? const LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : AppColors.primaryButtonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? AppColors.error
                                : AppColors.primary)
                            .withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                      if (!_isRecording)
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
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
            child: _buildAssistantBubble(msg.text, payload: msg.payload),
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

  Widget _buildAssistantBubble(String text, {Map<String, dynamic>? payload}) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Text(
                  text,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.onSurface, height: 1.5),
                ),
              ),
              if (payload != null && payload.containsKey('transactions'))
                _buildTransactionList(payload['transactions'] as List<dynamic>),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<dynamic> transactions) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: transactions.map((txn) {
          final isSent = txn['type'] == 'sent';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSent ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isSent ? Colors.redAccent : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSent ? 'Sent Transfer' : 'Received Funds',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                Text(
                  'PKR ${txn['amount']}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSent ? Colors.redAccent : Colors.green,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.accent.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35)),
                ),
                child: Text(
                  text,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onPrimaryContainer, height: 1.5),
                ),
              ),
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
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.accent.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: const Icon(Icons.person, size: 16, color: AppColors.primary),
        ),
      ],
    );
  }
}
