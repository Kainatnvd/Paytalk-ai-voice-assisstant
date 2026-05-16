import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_card.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/api_service.dart';

/// Screen for manually entering numbers (Raast ID, Reference Number, etc.)
/// Navigated to from the dashboard when dialogue state requires numeric input.
class NumberInputScreen extends StatefulWidget {
  /// The current dialogue state: 'AWAITING_RAAST_ID', 'AWAITING_REFERENCE_NUMBER', etc.
  final String dialogueState;

  /// Pending action map from the backend containing recipient info, amount, etc.
  final Map<String, dynamic> pendingAction;

  const NumberInputScreen({
    super.key,
    required this.dialogueState,
    required this.pendingAction,
  });

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _numberController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();

    // Auto-focus the text field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _numberController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── UI Helpers ──────────────────────────────────────────────────────

  String get _screenTitle {
    switch (widget.dialogueState) {
      case 'AWAITING_RAAST_ID':
        return 'Enter Raast Number';
      case 'AWAITING_REFERENCE_NUMBER':
        return 'Enter Reference Number';
      case 'AWAITING_ACCOUNT_NUMBER':
        final type = widget.pendingAction['account_type'] ?? 'Account';
        return 'Enter $type Number';
      case 'AWAITING_PAYMENT_METHOD':
        return 'Choose Payment Method';
      default:
        return 'Enter Number';
    }
  }

  String get _screenSubtitle {
    final name = widget.pendingAction['recipient_name'] ?? '';
    final amount = widget.pendingAction['amount'] ?? '';
    switch (widget.dialogueState) {
      case 'AWAITING_RAAST_ID':
        return 'Raast account number for $name';
      case 'AWAITING_REFERENCE_NUMBER':
        return 'Bill reference for $name — PKR $amount';
      case 'AWAITING_ACCOUNT_NUMBER':
        final type = widget.pendingAction['account_type'] ?? 'Account';
        return '$type number for $name';
      default:
        return 'PKR $amount to $name';
    }
  }

  IconData get _screenIcon {
    switch (widget.dialogueState) {
      case 'AWAITING_RAAST_ID':
        return Icons.account_balance_wallet_outlined;
      case 'AWAITING_REFERENCE_NUMBER':
        return Icons.receipt_long_outlined;
      case 'AWAITING_ACCOUNT_NUMBER':
        return Icons.account_balance_outlined;
      default:
        return Icons.dialpad;
    }
  }

  String get _inputHint {
    switch (widget.dialogueState) {
      case 'AWAITING_RAAST_ID':
        return 'e.g. 03001234567';
      case 'AWAITING_REFERENCE_NUMBER':
        return 'e.g. 11223344';
      case 'AWAITING_ACCOUNT_NUMBER':
        return widget.pendingAction['account_type'] == 'Bank Transfer' ? 'e.g. PK12ALFA...' : 'e.g. 03001234567';
      default:
        return 'Enter number';
    }
  }

  String get _inputLabel {
    switch (widget.dialogueState) {
      case 'AWAITING_RAAST_ID':
        return 'Raast Account Number';
      case 'AWAITING_REFERENCE_NUMBER':
        return 'Reference Number';
      case 'AWAITING_ACCOUNT_NUMBER':
        return widget.pendingAction['account_type'] == 'Bank Transfer' ? 'Account Number or IBAN' : 'Account Number';
      default:
        return 'Number';
    }
  }

  // ── Submit Logic ───────────────────────────────────────────────────

  Future<void> _submitNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      setState(() => _errorMessage = 'Please enter a number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Send the number as text to the voice process-text endpoint
    final result = await _apiService.submitVoiceText(number);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      final data = result['data'];

      // Play audio response
      if (data['response_audio'] != null &&
          data['response_audio'].toString().isNotEmpty) {
        try {
          final audioB64 = data['response_audio'].toString();
          if (kIsWeb) {
            final dataUrl = 'data:audio/mpeg;base64,$audioB64';
            await _audioPlayer.play(UrlSource(dataUrl));
          } else {
            final bytes = base64Decode(audioB64);
            await _audioPlayer.play(BytesSource(bytes));
          }
        } catch (e) {
          debugPrint('[Audio] Playback error: $e');
        }
      }

      // Return the result data back to dashboard for state handling
      if (mounted) {
        Navigator.of(context).pop(data);
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to process number';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedGradientBlob(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          _buildIconHeader(),
                          const SizedBox(height: 40),
                          _buildTransactionSummaryCard(),
                          const SizedBox(height: 32),
                          _buildNumberInputField(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorMessage(),
                          ],
                          const SizedBox(height: 40),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                          _buildCancelButton(),
                          const SizedBox(height: 48),
                        ],
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

  /// Frosted glass app bar
  Widget _buildAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              bottom: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.onSurface,
              ),
              const SizedBox(width: 4),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  _screenTitle,
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Animated gradient icon at the top
  Widget _buildIconHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.12),
                AppColors.accent.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: Icon(_screenIcon, size: 44, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _screenTitle,
          style: AppTypography.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _screenSubtitle,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Glass card showing recipient info and amount
  Widget _buildTransactionSummaryCard() {
    final name = widget.pendingAction['recipient_name'] ?? 'Unknown';
    final amount = widget.pendingAction['amount'] ?? '0';

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Recipient avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'PKR $amount',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pending',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The main number input field with premium styling
  Widget _buildNumberInputField() {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: _numberController,
        focusNode: _focusNode,
        keyboardType: widget.dialogueState == 'AWAITING_ACCOUNT_NUMBER' 
            ? TextInputType.text 
            : TextInputType.number,
        inputFormatters: widget.dialogueState == 'AWAITING_ACCOUNT_NUMBER'
            ? [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.headlineMedium.copyWith(
          color: AppColors.onSurface,
          letterSpacing: 2.5,
          fontSize: 24,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: _inputHint,
          hintStyle: AppTypography.bodyLarge.copyWith(
            color: AppColors.textMuted.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
          labelText: _inputLabel,
          labelStyle: AppTypography.labelLarge.copyWith(
            color: AppColors.primary,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.dialpad_rounded,
              color: AppColors.primary.withOpacity(0.6),
              size: 22,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.primary.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.error.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        onSubmitted: (_) => _submitNumber(),
      ),
    );
  }

  /// Error message with icon
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient submit button
  Widget _buildSubmitButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? const SizedBox(
              height: 56,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryButtonGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _submitNumber,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  'Submit',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
    );
  }

  /// Cancel button
  Widget _buildCancelButton() {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.close, size: 18),
      label: Text(
        'Cancel',
        style: AppTypography.labelLarge.copyWith(color: AppColors.error),
      ),
      style: TextButton.styleFrom(foregroundColor: AppColors.error),
    );
  }
}
