import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LocalizationService.instance.currentLanguage;
  }

  Future<void> _finishOnboarding() async {
    await LocalizationService.instance.changeLanguage(_selectedLanguage);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_country', 'QA');
    await prefs.setBool('onboarding_done', true);
    // tutorial_done stays false so feed shows coach marks after language pick

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appSurface,
      body: SafeArea(child: _buildLanguagePage()),
    );
  }

  Widget _buildFlagImage(String simCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w40/${simCode.toLowerCase()}.png',
        width: 36,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.flag, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _selectedLanguage == 'ar' ? 'اختر لغتك' : 'Choose your language',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedLanguage == 'ar'
                ? 'يمكنك تغيير اللغة لاحقاً من الإعدادات'
                : 'You can change the language later from settings',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: _buildLanguageCard(
                  languageCode: 'en',
                  simCode: 'gb',
                  title: 'English',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageCard(
                  languageCode: 'ar',
                  simCode: 'sa',
                  title: _selectedLanguage == 'ar' ? 'العربية' : 'Arabic',
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Text(
                _selectedLanguage == 'ar' ? 'التالي' : 'Next',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String languageCode,
    required String simCode,
    required String title,
  }) {
    final isSelected = _selectedLanguage == languageCode;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedLanguage = languageCode);
        await LocalizationService.instance.changeLanguage(languageCode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFlagImage(simCode),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
