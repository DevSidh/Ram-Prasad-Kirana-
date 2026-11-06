import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class BillingLanguageSwitch extends StatelessWidget {
  const BillingLanguageSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppLanguageProvider?>();
    if (language == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(
                        value: 'ne',
                        label: Text('नेपाली',
                            style: TextStyle(
                                fontFamily: 'FastStoreDevanagari',
                                fontSize: 22)))
                  ],
                  selected: {language.languageCode},
                  style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                          fontFamily: 'FastStoreDevanagari',
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  onSelectionChanged: (value) async {
                    try {
                      await language.setLanguage(value.single);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(language.languageCode == 'ne'
                                ? 'भाषा सुरक्षित हुन सकेन। फेरि प्रयास गर्नुहोस्।'
                                : 'Could not save the language. Please try again.')));
                      }
                    }
                  }),
            ]));
  }
}
