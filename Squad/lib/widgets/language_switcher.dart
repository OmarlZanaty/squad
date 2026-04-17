import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad/utils/language_provider.dart';
import 'package:squad/utils/app_localizations.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: localizations?.tr('change_language') ?? 'Change Language',
      onSelected: (String languageCode) {
        languageProvider.changeLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              if (languageProvider.locale.languageCode == 'en')
                const Icon(Icons.check, color: Colors.green),
              if (languageProvider.locale.languageCode == 'en')
                const SizedBox(width: 8),
              const Text('English'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              if (languageProvider.locale.languageCode == 'ar')
                const Icon(Icons.check, color: Colors.green),
              if (languageProvider.locale.languageCode == 'ar')
                const SizedBox(width: 8),
              const Text('العربية'),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple toggle button version
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.locale.languageCode == 'ar';

    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: isArabic ? 'English' : 'العربية',
      onPressed: () {
        languageProvider.toggleLanguage();
      },
    );
  }
}
