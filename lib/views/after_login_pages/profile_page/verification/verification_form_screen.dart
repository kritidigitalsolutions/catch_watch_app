import 'dart:io';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class VerificationFormScreen extends StatefulWidget {
  final Plan plan;
  final VerificationApplication? existingApplication;
  const VerificationFormScreen({super.key, required this.plan, this.existingApplication});

  @override
  State<VerificationFormScreen> createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late Razorpay _razorpay;

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _twitterController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedIdType = 'Aadhar';
  File? _idFront;
  File? _idBack;
  File? _selfie;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    final user = context.read<ProfileProvider>().user;
    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      _fullNameController.text = app.fullName ?? '';
      _usernameController.text = app.username ?? '';
      _idNumberController.text = app.governmentIdNumber ?? '';
      _websiteController.text = app.website ?? '';
      _instagramController.text = app.instagram ?? '';
      _facebookController.text = app.facebook ?? '';
      _youtubeController.text = app.youtube ?? '';
      _twitterController.text = app.twitter ?? '';
      _linkedinController.text = app.linkedin ?? '';
      _reasonController.text = app.reason ?? '';
      _selectedIdType = app.governmentIdType ?? 'Aadhar';
      _confirmed = true;
    } else if (user != null) {
      _fullNameController.text = user.name ?? '';
      _usernameController.text = user.username ?? '';
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final subProvider = context.read<SubscriptionProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await subProvider.verifyPayment({
      "razorpay_order_id": response.orderId,
      "razorpay_payment_id": response.paymentId,
      "razorpay_signature": response.signature,
      "planId": widget.plan.id,
      "type": "verification"
    });

    if (mounted) Navigator.pop(context); // Close loading

    if (success && mounted) {
      _showSuccessPopup();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(subProvider.error ?? 'Verification payment failed')),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text('Application Submitted!', style: text18(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Your verification request is being processed. We will notify you once it\'s reviewed.',
              textAlign: TextAlign.center,
              style: text14(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done', style: text14(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Image Source', style: text16(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceItem(Icons.camera_alt_rounded, 'Camera', () => Navigator.pop(context, ImageSource.camera)),
                _sourceItem(Icons.photo_library_rounded, 'Gallery', () => Navigator.pop(context, ImageSource.gallery)),
              ],
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          if (type == 'front') _idFront = File(pickedFile.path);
          if (type == 'back') _idBack = File(pickedFile.path);
          if (type == 'selfie') _selfie = File(pickedFile.path);
        });
      }
    }
  }

  Widget _sourceItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: text12(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existingApplication == null) {
      if (_idFront == null || _selfie == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload required images')),
        );
        return;
      }
    }
    
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm the terms')),
      );
      return;
    }

    final provider = context.read<VerificationProvider>();
    final subProvider = context.read<SubscriptionProvider>();
    
    dio.FormData formData = dio.FormData.fromMap({
      'fullName': _fullNameController.text,
      'username': _usernameController.text,
      'governmentIdType': _selectedIdType,
      'governmentIdNumber': _idNumberController.text,
      'planId': widget.plan.id,
      'website': _websiteController.text,
      'instagram': _instagramController.text,
      'facebook': _facebookController.text,
      'youtube': _youtubeController.text,
      'twitter': _twitterController.text,
      'linkedin': _linkedinController.text,
      'reason': _reasonController.text,
      'confirmation': 'true',
    });

    if (_idFront != null) {
      formData.files.add(MapEntry(
        'idFront',
        await dio.MultipartFile.fromFile(_idFront!.path, filename: 'id_front.jpg'),
      ));
    }
    
    if (_idBack != null) {
      formData.files.add(MapEntry(
        'idBack',
        await dio.MultipartFile.fromFile(_idBack!.path, filename: 'id_back.jpg'),
      ));
    }

    if (_selfie != null) {
      formData.files.add(MapEntry(
        'selfie',
        await dio.MultipartFile.fromFile(_selfie!.path, filename: 'selfie.jpg'),
      ));
    }

    final bool isUpdate = widget.existingApplication != null;
    final success = isUpdate 
        ? await provider.updateVerification(formData)
        : await provider.applyVerification(formData);

    if (success && mounted) {
      if (isUpdate && provider.currentApplication?.isPaid == true) {
         _showSuccessPopup();
         return;
      }

      // Start payment
      final response = await subProvider.createOrder(widget.plan.id!);
      if (response != null && response['order'] != null) {
        final order = response['order'];
        final razorpayKey = response['key'];
        final user = context.read<ProfileProvider>().user;

        var options = {
          'key': razorpayKey ?? 'rzp_test_SztpB3DjlEhcKW',
          'amount': order['amount'],
          'name': 'Catch Watch Verification',
          'order_id': order['id'],
          'description': widget.plan.name,
          'prefill': {
            'contact': user?.phone ?? '',
            'email': '',
          },
        };
        _razorpay.open(options);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to submit application')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Verification Request', style: text18(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Personal Information'),
                  _buildTextField(_fullNameController, 'Full Name *', 'Enter your full name', true),
                  _buildTextField(_usernameController, 'Username (Optional)', '@username', false),
                  
                  const SizedBox(height: 20),
                  _buildSectionTitle('Identity Verification'),
                  _buildDropdown(),
                  _buildTextField(_idNumberController, 'ID Number (Optional)', 'Enter ID number', false),
                  
                  const SizedBox(height: 20),
                  _buildImageUpload('ID Front *', _idFront, widget.existingApplication?.idFront, () => _pickImage('front')),
                  _buildImageUpload('ID Back (Optional)', _idBack, widget.existingApplication?.idBack, () => _pickImage('back')),
                  _buildImageUpload('Selfie *', _selfie, widget.existingApplication?.selfie, () => _pickImage('selfie')),
                  
                  const SizedBox(height: 20),
                  _buildSectionTitle('Social Links (Optional)'),
                  _buildTextField(_websiteController, 'Website', 'https://example.com', false),
                  _buildTextField(_instagramController, 'Instagram', 'Instagram URL', false),
                  _buildTextField(_facebookController, 'Facebook', 'Facebook URL', false),
                  _buildTextField(_youtubeController, 'YouTube', 'YouTube URL', false),
                  _buildTextField(_twitterController, 'Twitter/X', 'Twitter URL', false),
                  _buildTextField(_linkedinController, 'LinkedIn', 'LinkedIn URL', false),
                  
                  const SizedBox(height: 20),
                  _buildSectionTitle('Additional Details'),
                  _buildTextField(_reasonController, 'Reason for Verification', 'Why should you be verified?', false, maxLines: 3),
                  
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _confirmed,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _confirmed = val ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'I confirm that all provided information is accurate.',
                          style: text12(color: AppColors.grey700),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: provider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Submit & Pay', style: text16(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (provider.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: text16(fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, bool required, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text12(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: text14(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (val) => required && (val == null || val.isEmpty) ? 'Field required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Government ID Type *', style: text12(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedIdType,
                isExpanded: true,
                items: ['Aadhar', 'Passport', 'Driving License', 'PAN']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: text14())))
                    .toList(),
                onChanged: (val) => setState(() => _selectedIdType = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload(String label, File? image, String? existingUrl, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text12(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey200, style: BorderStyle.solid),
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(image, fit: BoxFit.cover),
                    )
                  : (existingUrl != null && existingUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(existingUrl, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_outlined, color: AppColors.grey400, size: 30),
                            const SizedBox(height: 4),
                            Text('Tap to upload', style: text12(color: AppColors.grey400)),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
