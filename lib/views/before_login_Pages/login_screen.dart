import 'package:catch_watch/utils/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../res/app_colors.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(

        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
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

              // ── Phone card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue with your mobile\nnumber.',
                      style: text16(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter mobile number',
                      style: text12(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: auth.errorMessage != null
                              ? AppColors.error
                              : AppColors.grey300,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Country code
                          GestureDetector(
                            onTap: () => _showCountryPicker(context, auth),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.grey300),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    auth.countryCode,
                                    style: text14(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),

                          // Phone input
                          Expanded(
                            child: TextFormField(
                              initialValue: auth.phoneNumber,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: text14(),
                              decoration: InputDecoration(
                                hintText: 'Enter mobile number',
                                hintStyle: text14(color: AppColors.hintText),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onChanged: (val) =>
                                  context.read<AuthProvider>().setPhone(val),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        auth.errorMessage!,
                        style: text12(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Continue button ──────────────────────────────
              AppButton(
                title: 'Continue',
                isLoading: auth.isLoading,
                onTap: (){

                  context.read<AuthProvider>().sendOtp(context);
                },),


              const SizedBox(height: 16),

              // ── Terms ────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: auth.agreedToTerms,
                    onChanged: (val) =>
                        context.read<AuthProvider>().toggleTerms(val),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppColors.grey400),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: text12(color: AppColors.textSecondary),
                        children: [
                          const TextSpan(
                              text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: text12(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: text12(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '.'),
                        ],
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

  void _showCountryPicker(BuildContext context, AuthProvider auth) {
    final codes = {
      '🇮🇳 India': '+91',
      '🇺🇸 USA': '+1',
      '🇬🇧 UK': '+44',
      '🇦🇪 UAE': '+971',
      '🇦🇺 Australia': '+61',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Country Code',
              style: text16(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...codes.entries.map(
                (e) => ListTile(
              title: Text(e.key, style: text14()),
              trailing: Text(e.value,
                  style: text14(
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
              onTap: () {
                context.read<AuthProvider>().setCountryCode(e.value);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Shared Logo Widget ──────────────────────────────────────────

class _CatchAndWatchLogo extends StatelessWidget {
  const _CatchAndWatchLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black,
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
                    color: Colors.white,
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