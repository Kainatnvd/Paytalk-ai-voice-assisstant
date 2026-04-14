import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_card.dart';
import '../models/chat_message.dart';
import '../services/mock_data.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAHOmCy3NUEDc2iZJ990U3CbdMqsdc8F9nmMFax8MK3XC1E6S130UKlcR1mvGs7nLff-7DwmRjkIChFVz5ozeaN13lZB6ehdU49yyVwQn45cY2fJN3mJGdjT6IRvCFtxk4CAyuud_iDaA9z70sAhqX4ktdOH2yAY6bgixyPf8U96fNHWw4H6CYUSnlSnUnYl2KmNE-oueGs1Lz5PBUuOljLQmc8q2kgAgT5OlolfBpvcUo1Y9rBwxTgyxLXGqLqIO8_7eDkwDS_IbA'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: AppColors.outline),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, Alex', style: AppTypography.labelSmall.copyWith(fontSize: 10)),
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
              '\$24,500.00',
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
            AppColors.primary.withOpacity(0.12),
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
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: AppColors.primary.withOpacity(0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(80),
            child: ImageFiltered(
              imageFilter: ColorFilter.mode(Colors.white.withOpacity(0.4), BlendMode.softLight),
              child: Container(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceStatus() {
    return Column(
      children: [
        Text(
          'Say something...',
          style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'کچھکہیے...',
          style: AppTypography.urduText.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildMicButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.mic, size: 40, color: Colors.white),
    );
  }

  Widget _buildChatInterface() {
    final messages = MockData.chatMessages;
    return Column(
      children: messages.map((msg) => _buildChatBubble(msg)).toList(),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isAssistant = message.sender == MessageSender.assistant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAssistant)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: const Icon(Icons.smart_toy, size: 16, color: AppColors.primary),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAssistant ? Colors.white : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.04),
                    blurRadius: 10,
                  ),
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
          if (!isAssistant)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: const DecorationImage(
                  image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBmMidzxDNf9KFhePBC2p3Q3B1wkA4sbkoVT18JtC0tTbAd9vvouqALzWKQf-4dyO_XNwuP19zEgWlw7hejP9hvTrKvxeJeCKbgztVGQFI6LdrjnMv-3HLHcvx235Z38VKIveqP92hp4pf76W9Xg7RtQdZ4DPLrKxAK1_dmAOuGLLTB5fpflKpeUooS_t8FsKDBAcTPQhTi3cZUHBw3A96Ou-55xF0zTaUkf9UesikUhMVMv0HfgdE5TJgWYHDLhbHmWcjEF7wCPcA'),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: AppColors.outline),
              ),
            ),
        ],
      ),
    );
  }
}
