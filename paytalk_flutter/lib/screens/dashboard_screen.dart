import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_card.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String _balance = 'Loading...';
  List<Transaction> _transactions = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    final balanceResult = await _apiService.getBalance();
    final transactionsResult = await _apiService.getTransactions();

    if (mounted) {
      setState(() {
        if (balanceResult.containsKey('balance')) {
          _balance = '${balanceResult['currency']} ${balanceResult['balance']}';
        } else {
          _balance = 'Error';
        }
        _transactions = transactionsResult;
        _isLoading = false;
      });
    }
  }

  bool _isProcessingRecording = false;

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
        final directory = await getTemporaryDirectory();
        final path = p.join(directory.path, 'voice_command.wav');
        
        const config = RecordConfig(encoder: AudioEncoder.wav);
        await _audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _processVoice(String filePath) async {
    // Add user message to UI immediately for feedback
    setState(() {
      _messages.add(ChatMessage(
        text: "Analyzing voice command...",
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
    });

    final result = await _apiService.processVoice(filePath);

    if (mounted) {
      if (result['status'] == 'success') {
        final data = result['data'];
        setState(() {
          // Update user message with real transcription
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: data['transcription'],
            sender: MessageSender.user,
            timestamp: DateTime.now(),
          ));
          
          // Add assistant response
          _messages.add(ChatMessage(
            text: data['response_text'],
            sender: MessageSender.assistant,
            timestamp: DateTime.now(),
          ));
        });

        // Play audio response if available
        if (data['response_audio'] != null) {
          final bytes = base64Decode(data['response_audio']);
          final tempDir = await getTemporaryDirectory();
          final responseFile = File(p.join(tempDir.path, 'response.mp3'));
          await responseFile.writeAsBytes(bytes);
          await _audioPlayer.play(DeviceFileSource(responseFile.path));
        }

        // Refresh data in case balance or transactions changed
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 48),
                          _buildEtherealOrb(),
                          const SizedBox(height: 48),
                          _buildVoiceStatus(),
                          const SizedBox(height: 32),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onLongPress: () async {
                  await _apiService.logout();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: NetworkImage('https://i.pravatar.cc/150?u=paytalk'),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: AppColors.outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, User', style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                  Text('PayTalk', style: AppTypography.headlineLarge.copyWith(color: AppColors.primary)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Text(
              _balance,
              style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtherealOrb() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _isRecording ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.12),
            AppColors.primary.withOpacity(0.04),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: _isRecording ? Colors.red.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: AppColors.primary.withOpacity(0.05)),
          ),
          child: _isRecording ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : null,
        ),
      ),
    );
  }

  Widget _buildVoiceStatus() {
    return Column(
      children: [
        Text(
          _isRecording ? 'Listening...' : 'Say something...',
          style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          _isRecording ? 'سن رہا ہوں...' : 'کچھ کہیے...',
          style: AppTypography.urduText.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.redAccent : AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.redAccent : AppColors.primary).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 40, color: Colors.white),
      ),
    );
  }

  Widget _buildChatInterface() {
    if (_messages.isNotEmpty) {
      return Column(
        children: _messages.map((msg) => _buildChatBubble(msg)).toList(),
      );
    }
    
    // Fallback to recent transactions if no chat
    if (_transactions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTypography.labelSmall),
          const SizedBox(height: 16),
          ..._transactions.take(3).map((txn) => _buildTransactionCard(txn)),
        ],
      );
    }
    
    return const Center(child: Text('Start a voice conversation.'));
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isAssistant = message.sender == MessageSender.assistant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAssistant ? Colors.white : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.onSurface.withOpacity(0.04), blurRadius: 10),
                ],
                border: Border.all(color: AppColors.outline),
              ),
              child: Text(
                message.text,
                style: AppTypography.bodyMedium.copyWith(
                  color: isAssistant ? AppColors.onSurface : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
              child: Icon(
                txn.type == TransactionType.expense ? Icons.call_made : Icons.call_received,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title, style: AppTypography.headlineMedium.copyWith(fontSize: 16)),
                  Text(txn.date, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                ],
              ),
            ),
            Text(
              '${txn.type == TransactionType.expense ? "-" : "+"}${txn.amount}',
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 16,
                color: txn.type == TransactionType.expense ? Colors.redAccent : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


