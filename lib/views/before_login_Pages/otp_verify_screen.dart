import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../res/app_colors.dart';
import '../../utils/custom_button.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with CodeAutoFill {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    listenForCode(); // Removed await as it's a void function
    _printAppSignature();
    // Ensure focus on the first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      setState(() {
        _pinController.text = code!;
      });
      // Automatically verify once filled
      context.read<AuthProvider>().verifyFromAutoFill(code!, context);
    }
  }

  void _printAppSignature() async {
    String signature = await SmsAutoFill().getAppSignature;
    debugPrint("App Signature for SMS: $signature");
  }

  @override
  void dispose() {
    unregisterListener();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _clearAndResetControllers(AuthProvider auth) {
    _pinController.clear();
    _pinFocusNode.requestFocus();
    auth.clearOtp();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Update controller if OTP is auto-filled in provider
    if (auth.otpCode.length == 6 && _pinController.text != auth.otpCode) {
      _pinController.text = auth.otpCode;
    }

    final defaultPinTheme = PinTheme(
      width: 44,
      height: 52,
      textStyle: text18(fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: AppColors.primary.withOpacity(0.08),
      border: Border.all(color: AppColors.primary),
    );

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

                    // OTP boxes using Pinput
                    Center(
                      child: Pinput(
                        length: 6,
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          for (int i = 0; i < 6; i++) {
                            auth.setOtpDigit(
                              i,
                              i < value.length ? value[i] : '',
                            );
                          }
                        },
                        onCompleted: (pin) {
                          auth.verifyOtp(context);
                        },
                      ),
                    ),

                    if (auth.otpError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        auth.otpError!,
                        style: text12(color: AppColors.error),
                      ),
                    ],
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
