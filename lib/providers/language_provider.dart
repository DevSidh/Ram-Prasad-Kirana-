import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageProvider extends ChangeNotifier {
  static const _preferenceKey = 'app_language';

  static const _nepali = <String, String>{
    'Home': 'गृहपृष्ठ',
    'Categories': 'श्रेणीहरू',
    'Search': 'खोज्नुहोस्',
    'Cart': 'कार्ट',
    'Profile': 'प्रोफाइल',
    'Orders': 'अर्डरहरू',
    'Addresses': 'ठेगानाहरू',
    'Saved items': 'मनपर्ने सामान',
    'Dark appearance': 'गाढा रूप',
    'Dark mode is on': 'डार्क मोड सक्रिय छ',
    'Light mode is on': 'लाइट मोड सक्रिय छ',
    'Language': 'भाषा',
    'Choose language': 'भाषा छान्नुहोस्',
    'English': 'अङ्ग्रेजी',
    'Nepali': 'नेपाली',
    'Payment Methods': 'भुक्तानी विधिहरू',
    'Notifications': 'सूचनाहरू',
    'Notification Preferences': 'सूचना प्राथमिकताहरू',
    'Store administration': 'स्टोर प्रशासन',
    'Help & store information': 'सहयोग र स्टोर जानकारी',
    'Store help': 'स्टोर सहयोग',
    'How can we help?': 'हामी कसरी सहयोग गर्न सक्छौँ?',
    'Delivery area': 'डेलिभरी क्षेत्र',
    'Update an address': 'ठेगाना अद्यावधिक गर्नुहोस्',
    'Order and payment questions': 'अर्डर र भुक्तानीसम्बन्धी प्रश्न',
    'Call store': 'स्टोरमा फोन गर्नुहोस्',
    'Open store in Maps': 'नक्सामा स्टोर खोल्नुहोस्',
    'Choose location': 'स्थान छान्नुहोस्',
    'Use current location': 'हालको स्थान प्रयोग गर्नुहोस्',
    'Search products': 'सामान खोज्नुहोस्',
    'Popular searches': 'लोकप्रिय खोजहरू',
    'Recent searches': 'हालैका खोजहरू',
    'Clear all': 'सबै हटाउनुहोस्',
    'Your cart is empty': 'तपाईंको कार्ट खाली छ',
    'Continue shopping': 'किनमेल जारी राख्नुहोस्',
    'Checkout': 'अर्डर गर्नुहोस्',
    'Add to cart': 'कार्टमा थप्नुहोस्',
    'View all': 'सबै हेर्नुहोस्',
    'Shop by category': 'श्रेणीअनुसार किनमेल',
    'Featured products': 'विशेष सामानहरू',
    'Best sellers': 'धेरै बिक्री हुने सामान',
    'Best seller picks': 'बेस्ट सेलरका सामान',
    'Cheap': 'सस्तो',
    'Cheap picks': 'सस्तो सामान',
    'Wholesale': 'थोक',
    'Store items': 'स्टोरका सामान',
    'Available in the store': 'स्टोरमा उपलब्ध सामान',
    'Top picks for you': 'तपाईंका लागि उत्कृष्ट छनोट',
    'Delivery to Home': 'घरमा डेलिभरी',
    'Janakpur, Madhesh Province': 'जनकपुर, मधेश प्रदेश',
    'Enter a place, street, or area to search.':
        'खोज्न ठाउँ, सडक वा क्षेत्र लेख्नुहोस्।',
    'No matching places found. Try a nearby landmark.':
        'मिल्दो ठाउँ भेटिएन। नजिकको चिनारी खोज्नुहोस्।',
    'Could not search this place. Check your connection and try again.':
        'यो ठाउँ खोज्न सकिएन। इन्टरनेट जाँचेर फेरि प्रयास गर्नुहोस्।',
    'This location appears to be outside our Janakpur delivery area.':
        'यो स्थान हाम्रो जनकपुर डेलिभरी क्षेत्रभन्दा बाहिर देखिन्छ।',
    'Check delivery area': 'डेलिभरी क्षेत्र जाँच गर्नुहोस्',
    'Review location': 'स्थान जाँच गर्नुहोस्',
    'Use anyway': 'तैपनि प्रयोग गर्नुहोस्',
    'Good morning': 'शुभ प्रभात',
    'Good afternoon': 'शुभ दिउँसो',
    'Good evening': 'शुभ साँझ',
    'Find something fresh...': 'ताजा सामान खोज्नुहोस्...',
    'Shop by categories': 'श्रेणीअनुसार किनमेल',
    'All items': 'सबै सामान',
    'Try again': 'फेरि प्रयास गर्नुहोस्',
    'No items yet. Products added by the administrator will appear here.':
        'अहिले सामान छैन। प्रशासकले थपेका सामान यहाँ देखिनेछन्।',
    'Choose a saved address': 'सुरक्षित ठेगाना छान्नुहोस्',
    'Add another address': 'अर्को ठेगाना थप्नुहोस्',
    'Sign in to choose a saved address.':
        'सुरक्षित ठेगाना छान्न साइन इन गर्नुहोस्।',
    'Sign in to add a delivery address.':
        'डेलिभरी ठेगाना थप्न साइन इन गर्नुहोस्।',
    'Search a place or address': 'ठाउँ वा ठेगाना खोज्नुहोस्',
    'Search location': 'स्थान खोज्नुहोस्',
    'Use my current location': 'मेरो हालको स्थान प्रयोग गर्नुहोस्',
    'Tap the map or drag the pin to adjust':
        'नक्सामा छुनुहोस् वा पिन सारेर मिलाउनुहोस्',
    'Finding address...': 'ठेगाना खोज्दै...',
    'Use this location': 'यो स्थान प्रयोग गर्नुहोस्',
    'Enter address manually': 'ठेगाना आफैँ लेख्नुहोस्',
    'Your Basket': 'तपाईंको टोकरी',
    'Your basket is empty': 'तपाईंको टोकरी खाली छ',
    'Browse fresh fruits, vegetables, artisan bakery, and mountain dairy to start shopping.':
        'किनमेल सुरु गर्न ताजा फलफूल, तरकारी, बेकरी र दुग्ध पदार्थ हेर्नुहोस्।',
    'Clear basket': 'टोकरी खाली गर्नुहोस्',
    'FREE Express Delivery': 'निःशुल्क एक्सप्रेस डेलिभरी',
    'Congratulations! You unlocked Free Delivery!':
        'बधाई छ! तपाईंले निःशुल्क डेलिभरी पाउनुभयो!',
    'Proceed to Checkout': 'चेकआउटमा जानुहोस्',
    'Undo': 'फिर्ता गर्नुहोस्',
    'Basket cleared.': 'टोकरी खाली भयो।',
    ' removed from your basket.': ' तपाईंको टोकरीबाट हटाइयो।',
    'Search store items...': 'स्टोरका सामान खोज्नुहोस्...',
    'Search the store': 'स्टोरमा खोज्नुहोस्',
    'Search products added by the store administrator.':
        'स्टोरले थपेका सामान खोज्नुहोस्।',
    'Suggestions': 'सुझावहरू',
    'No items found for': 'सामान भेटिएन:',
    'Check for typos or try searching for a product or category.':
        'हिज्जे जाँच्नुहोस् वा सामान अथवा श्रेणी खोज्नुहोस्।',
    'Clear Search': 'खोज हटाउनुहोस्',
    'Choose a suggestion to search the store.':
        'स्टोरमा खोज्न सुझाव छान्नुहोस्।',
    'All Grocery Aisles': 'सबै किराना श्रेणीहरू',
    'Refresh': 'फेरि लोड गर्नुहोस्',
    'Payment preference': 'भुक्तानी प्राथमिकता',
    'Privacy Policy': 'गोपनीयता नीति',
    'Log Out': 'लगआउट',
    'Sign in with an admin account': 'प्रशासक खाताबाट साइन इन गर्नुहोस्',
    'Delete notification?': 'सूचना मेटाउने?',
    'This notification will be permanently removed.':
        'यो सूचना स्थायी रूपमा मेटिनेछ।',
    'Cancel': 'रद्द गर्नुहोस्',
    'Delete': 'मेटाउनुहोस्',
    'Notification deleted.': 'सूचना मेटाइयो।',
    'Delete all notifications?': 'सबै सूचना मेटाउने?',
    'All notifications in your activity list will be permanently removed.':
        'गतिविधि सूचीका सबै सूचना स्थायी रूपमा मेटिनेछन्।',
    'Delete all': 'सबै मेटाउनुहोस्',
    'All notifications deleted.': 'सबै सूचना मेटाइयो।',
    'Delete all notifications': 'सबै सूचना मेटाउनुहोस्',
    'Refresh notifications': 'सूचना ताजा गर्नुहोस्',
    'Enable': 'सक्रिय गर्नुहोस्',
    'Close search': 'खोज बन्द गर्नुहोस्',
    'YOUR STORE ACCOUNT': 'तपाईंको स्टोर खाता',
    'Current account': 'हालको खाता',
    'Privacy': 'गोपनीयता',
    'Sign in': 'साइन इन',
  };

  String _languageCode = 'en';
  int _revision = 0;

  AppLanguageProvider() {
    unawaited(_loadSavedLanguage());
  }

  String get languageCode => _languageCode;

  String translate(String text) =>
      _languageCode == 'ne' ? (_nepali[text] ?? text) : text;

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'ne') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    if (_languageCode == languageCode) return;

    final revision = ++_revision;
    _languageCode = languageCode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    if (revision == _revision) {
      await preferences.setString(_preferenceKey, languageCode);
    }
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final revision = _revision;
      final preferences = await SharedPreferences.getInstance();
      if (revision != _revision) return;
      final saved = preferences.getString(_preferenceKey);
      if (saved == 'en') {
        _languageCode = 'en';
        notifyListeners();
      } else if (saved == 'ne') {
        _languageCode = 'ne';
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not load saved language preference: $error\n$stackTrace');
    }
  }
}

extension AppTranslation on BuildContext {
  String tr(String text) =>
      watch<AppLanguageProvider?>()?.translate(text) ?? text;
}
