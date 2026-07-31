import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_plans_screen.dart';
import 'verification_status_screen.dart';

class VerificationMainScreen extends StatefulWidget {
  const VerificationMainScreen({super.key});

  @override
  State<VerificationMainScreen> createState() => _VerificationMainScreenState();
}

class _VerificationMainScreenState extends State<VerificationMainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VerificationProvider>();
      provider.fetchVerificationStatus().then((_) {
        if (provider.currentApplication == null) {
          provider.fetchBluetickPlans();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();

    if (!provider.isInitialStatusLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.currentApplication != null) {
      return const VerificationStatusScreen();
    }

    return const VerificationPlansScreen();
  }
}
