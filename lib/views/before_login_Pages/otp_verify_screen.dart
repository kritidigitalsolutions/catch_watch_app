import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/custom_button.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(String value, int index, AuthProvider auth) {
    if (value.isNotEmpty) {
      auth.setOtpDigit(index, value);
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      auth.setOtpDigit(index, '');
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _clearAndResetControllers(AuthProvider auth) {
    for (int i = 0; i < 6; i++) {
      _controllers[i].clear();
    }
    _focusNodes[0].requestFocus();
    auth.clearOtp();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.read<AuthProvider>().goBackToLogin(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const _CatchAndWatchLogo(),
              const SizedBox(height: 28),

              Text(
                'Welcome to Catch & Watch',
                style: text20(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your entertainment starts here.',
                style: text14(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── OTP card ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your number',
                      style: text16(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: text12(color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text:
                                'A verification code has been sent to ${auth.maskedPhone} Wrong number? ',
                          ),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () =>
                                  context.read<AuthProvider>().goBackToLogin(),
                              child: Text(
                                'Edit',
                                style: text12(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        final isFilled = auth.otpDigits[i].isNotEmpty;
                        return SizedBox(
                          width: 44,
                          height: 52,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: text18(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: isFilled
                                  ? AppColors.primary.withOpacity(0.08)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.grey300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isFilled
                                      ? AppColors.primary
                                      : AppColors.grey300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => _onDigitChanged(
                              val,
                              i,
                              context.read<AuthProvider>(),
                            ),
                          ),
                        );
                      }),
                    ),

                    if (auth.otpError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        auth.otpError!,
                        style: text12(color: AppColors.error),
                      ),
                    ],

                    // Demo hint
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Demo OTP: 123456',
                            style: text12(color: AppColors.info),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Verify button ────────────────────────────────
              AppButton(
                title: 'Verify',
                isLoading: auth.otpVerifying,
                onTap: () {
                  context.read<AuthProvider>().verifyOtp(context);
                },
              ),

              const SizedBox(height: 16),

              // ── Resend ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code?  ",
                    style: text13(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: auth.canResend
                        ? () {
                            _clearAndResetControllers(
                              context.read<AuthProvider>(),
                            );
                            context.read<AuthProvider>().resendOtp(context);
                          }
                        : null,
                    child: Text(
                      auth.canResend
                          ? 'Resend OTP'
                          : 'Resend in 00:${auth.resendSeconds.toString().padLeft(2, '0')}',
                      style: text13(
                        color: auth.canResend
                            ? AppColors.primary
                            : AppColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatchAndWatchLogo extends StatelessWidget {
  const _CatchAndWatchLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'CATCH',
                  style: text20(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ).copyWith(fontStyle: FontStyle.italic, letterSpacing: 1),
                ),
                TextSpan(
                  text: ' &\nWATCH',
                  style: text20(
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ).copyWith(fontStyle: FontStyle.italic, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
