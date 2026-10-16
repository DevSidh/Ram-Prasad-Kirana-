import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageProvider extends ChangeNotifier {
  static const _preferenceKey = 'app_language';

  static const _nepali = <String, String>{
    'System': 'प्रणालीअनुसार',
    'Use device appearance': 'यन्त्रको रूप प्रयोग गर्नुहोस्',
    'Light': 'उज्यालो',
    'Dark': 'गाढा',
    'Home': 'गृहपृष्ठ',
    'Categories': 'श्रेणीहरू',
    'Search': 'खोज्नुहोस्',
    'Cart': 'कार्ट',
    'Profile': 'प्रोफाइल',
    'Preferences & payments': 'प्राथमिकता र भुक्तानी',
    'Help & account': 'सहयोग र खाता',
    'Orders': 'अर्डरहरू',
    'Addresses': 'ठेगानाहरू',
    'Saved items': 'मनपर्ने सामान',
    'Saved': 'सुरक्षित',
    'Offers': 'अफरहरू',
    'Reorder': 'फेरि अर्डर गर्नुहोस्',
    'Dark appearance': 'गाढा रूप',
    'Dark mode is on': 'डार्क मोड सक्रिय छ',
    'Light mode is on': 'लाइट मोड सक्रिय छ',
    'Language': 'भाषा',
    'Choose language': 'भाषा छान्नुहोस्',
    'English': 'अङ्ग्रेजी',
    'Nepali': 'नेपाली',
    'Payment Methods': 'भुक्तानी विधिहरू',
    'Payment methods': 'भुक्तानी विधिहरू',
    'Cash on delivery': 'वस्तु पाएपछि नगद भुक्तानी',
    'Cash on delivery is currently the only payment method.':
        'हाल नगद भुक्तानी मात्र उपलब्ध छ।',
    'eSewa and Khalti are not available yet. Payment is confirmed by the store when your order is delivered.':
        'eSewa र Khalti अहिले उपलब्ध छैनन्। अर्डर पाएपछि स्टोरले भुक्तानी पुष्टि गर्छ।',
    'Pay the delivery person when your order arrives.':
        'अर्डर आइपुगेपछि डेलिभरी कर्मचारीलाई भुक्तानी गर्नुहोस्।',
    'Notifications': 'सूचनाहरू',
    'Notification Preferences': 'सूचना प्राथमिकताहरू',
    'Choose the updates shown in your inbox':
        'सूचना सूचीमा देखिने अपडेटहरू छान्नुहोस्',
    'These filters are saved on this device and only affect the in-app notification list. To turn off push alerts, use your device notification settings.':
        'यी फिल्टरहरू यस यन्त्रमा सुरक्षित हुन्छन् र एपभित्रको सूचना सूचीमा मात्र लागू हुन्छन्। पुश सूचना बन्द गर्न यन्त्रको सूचना सेटिङ प्रयोग गर्नुहोस्।',
    'Order updates': 'अर्डर अपडेटहरू',
    'Delivery updates': 'डेलिभरी अपडेटहरू',
    'Store offers': 'स्टोरका अफरहरू',
    'No updates match these filters': 'यी फिल्टरसँग मिल्ने अपडेट छैनन्',
    'Change notification preferences to see more activity.':
        'थप गतिविधि हेर्न सूचना प्राथमिकता परिवर्तन गर्नुहोस्।',
    'Manage notification preferences': 'सूचना प्राथमिकता व्यवस्थापन गर्नुहोस्',
    'Notification filters could not be loaded:': 'सूचना फिल्टर लोड गर्न सकिएन:',
    'Showing all updates.': 'सबै अपडेट देखाइँदै छन्।',
    'Could not save this notification preference:':
        'यो सूचना प्राथमिकता सुरक्षित गर्न सकिएन:',
    'Could not open this app.': 'यो एप खोल्न सकिएन।',
    'Update an address': 'ठेगाना अद्यावधिक गर्नुहोस्',
    'Order and payment questions': 'अर्डर र भुक्तानीसम्बन्धी प्रश्न',
    'Open Account → Delivery Addresses to add, edit, remove, or choose your default address.':
        'ठेगाना थप्न, सम्पादन गर्न, हटाउन वा पूर्वनिर्धारित छान्न खाता → डेलिभरी ठेगानामा जानुहोस्।',
    'Keep your order details handy and contact the store using the contact information shared directly by the store owner.':
        'अर्डरको विवरण तयार राख्नुहोस् र स्टोर सञ्चालकले दिएको सम्पर्क विवरणबाट स्टोरमा सम्पर्क गर्नुहोस्।',
    'Privacy': 'गोपनीयता',
    'Your information': 'तपाईंको जानकारी',
    'Your account details and delivery addresses are used to provide store services and prepare deliveries. Passwords are stored as secure hashes by the store API. This app does not save payment card numbers.':
        'स्टोर सेवा र डेलिभरी तयार गर्न तपाईंको खाता विवरण र ठेगाना प्रयोग हुन्छ। पासवर्डहरू स्टोर API मा सुरक्षित ह्यासका रूपमा राखिन्छन्। यो एपले भुक्तानी कार्ड नम्बर सुरक्षित गर्दैन।',
    'Saved sign-in': 'सुरक्षित लगइन',
    'If you opt in, sign-in details are kept in your device’s secure storage. You can use biometrics to sign in when they are available on your device, or continue with saved sign-in otherwise. You can remove saved sign-in from the sign-in screen.':
        'तपाईंले अनुमति दिनुभयो भने लगइन विवरण यन्त्रको सुरक्षित भण्डारणमा राखिन्छ। यन्त्रमा बायोमेट्रिक सुविधा उपलब्ध भए त्यसबाट, नभए सुरक्षित लगइन विकल्पबाट प्रवेश गर्न सक्नुहुन्छ। लगइन स्क्रिनबाट सुरक्षित लगइन हटाउन सक्नुहुन्छ।',
    'Data requests': 'डेटा अनुरोध',
    'Read full privacy policy': 'पूर्ण गोपनीयता नीति पढ्नुहोस्',
    'Open account deletion page': 'खाता मेटाउने पृष्ठ खोल्नुहोस्',
    'You can request account deletion in the app or by contacting the store from your registered email address. Active orders must be completed or cancelled first.':
        'एपबाट वा दर्ता गरिएको इमेलबाट स्टोरमा सम्पर्क गरेर खाता मेटाउन अनुरोध गर्न सक्नुहुन्छ। सक्रिय अर्डर पहिले पूरा वा रद्द हुनुपर्छ।',
    'Delete account': 'खाता मेटाउनुहोस्',
    'Delete account?': 'खाता मेटाउने?',
    'Your profile and saved data will be removed. Completed order records will be anonymized and retained. Active orders must be completed or cancelled first.':
        'तपाईंको प्रोफाइल र सुरक्षित डाटा हटाइनेछ। पूरा भएका अर्डरका अभिलेख पहिचान नखुल्ने गरी राखिनेछन्। सक्रिय अर्डर पहिले पूरा वा रद्द हुनुपर्छ।',
    'Current password': 'हालको पासवर्ड',
    'Complete or cancel your active orders before deleting your account.':
        'खाता मेटाउनुअघि सक्रिय अर्डर पूरा वा रद्द गर्नुहोस्।',
    'Your account has been deleted.': 'तपाईंको खाता मेटाइएको छ।',
    'Your account was deleted, but saved sign-in could not be cleared:':
        'तपाईंको खाता मेटाइयो, तर सुरक्षित लगइन हटाउन सकिएन:',
    'Enter your password to delete your account.':
        'खाता मेटाउन आफ्नो पासवर्ड प्रविष्ट गर्नुहोस्।',
    'Your account was deleted and historical orders were anonymized.':
        'तपाईंको खाता मेटाइयो र पुराना अर्डरका व्यक्तिगत विवरण हटाइयो।',
    'For help with account information, contact the store owner through the contact information they provide.':
        'खाता जानकारीमा सहयोगका लागि स्टोर सञ्चालकले दिएको सम्पर्क विवरण प्रयोग गर्नुहोस्।',
    'Store administration': 'स्टोर प्रशासन',
    'Help & store information': 'सहयोग र स्टोर जानकारी',
    'Store help': 'स्टोर सहयोग',
    'How can we help?': 'हामी कसरी सहयोग गर्न सक्छौँ?',
    'Delivery area': 'डेलिभरी क्षेत्र',
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
    'Delivery fee is a flat Rs. 40.': 'डेलिभरी शुल्क रु. ४० निश्चित छ।',
    'Add to cart': 'कार्टमा थप्नुहोस्',
    'View all': 'सबै हेर्नुहोस्',
    'See all': 'सबै हेर्नुहोस्',
    'Popular near you': 'तपाईं नजिक लोकप्रिय',
    'Shop by category': 'श्रेणीअनुसार किनमेल',
    'Featured products': 'विशेष सामानहरू',
    'Best sellers': 'धेरै बिक्री हुने सामान',
    'Best seller picks': 'बेस्ट सेलरका सामान',
    'Cheap': 'सस्तो',
    'Cheap picks': 'सस्तो सामान',
    'Wholesale': 'थोक',
    'Store items': 'स्टोरका सामान',
    'Available in the store': 'स्टोरमा उपलब्ध सामान',
    'Discount code': 'छुट कोड',
    'Discount code (regular-priced items only)':
        'छुट कोड (नियमित मूल्यका सामानमा मात्र)',
    'Coupons do not apply to wholesale-priced items.':
        'कुपन छुट थोक मूल्यका सामानमा लागू हुँदैन।',
    'Enter coupon code': 'कुपन कोड लेख्नुहोस्',
    'Apply': 'लागू गर्नुहोस्',
    'Coupon discount': 'कुपन छुट',
    'Coupon applied successfully.': 'कुपन सफलतापूर्वक लागू भयो।',
    'Congratulations!': 'बधाई छ!',
    'Map preview unavailable': 'नक्सा पूर्वावलोकन उपलब्ध छैन',
    'Delivery map unavailable': 'डेलिभरी नक्सा उपलब्ध छैन',
    'The saved address is still attached to your order. Delivery remains Rs. 40.':
        'सुरक्षित ठेगाना अर्डरमा जोडिएको छ। डेलिभरी शुल्क Rs. 40 नै रहनेछ।',
    'This address has no saved map location.':
        'यो ठेगानामा सुरक्षित नक्सा स्थान छैन।',
    'Your basket changed. Apply the code again.':
        'तपाईंको टोकरी परिवर्तन भयो। कोड फेरि लागू गर्नुहोस्।',
    'The store is open and accepting orders.':
        'स्टोर खुला छ र अर्डरहरू स्वीकार गर्दैछ।',
    'The store is currently closed. Please check the opening hours before ordering.':
        'अहिले स्टोर बन्द छ। अर्डर गर्नुअघि खुल्ने समय जाँच गर्नुहोस्।',
    'Online ordering is temporarily paused by the store.':
        'स्टोरले अनलाइन अर्डर अस्थायी रूपमा रोकेको छ।',
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
    'Featured for Janakpur': 'जनकपुरका लागि विशेष',
    'Featured pick': 'विशेष छनोट',
    'Swipe': 'स्वाइप',
    'Next featured product': 'अर्को विशेष सामान',
    'Add': 'थप्नुहोस्',
    'Unavailable': 'उपलब्ध छैन',
    'items': 'सामानहरू',
    'View cart': 'कार्ट हेर्नुहोस्',
    'No products match this filter.': 'यो फिल्टरमा कुनै सामान भेटिएन।',
    'Clear filter': 'फिल्टर हटाउनुहोस्',
    'Save item': 'सामान सुरक्षित गर्नुहोस्',
    'Remove from saved items': 'सुरक्षित सूचीबाट हटाउनुहोस्',
    'Shop by categories': 'श्रेणीअनुसार किनमेल',
    'All items': 'सबै सामान',
    'Try again': 'फेरि प्रयास गर्नुहोस्',
    'Retry': 'फेरि प्रयास गर्नुहोस्',
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
    'Remove from search history': 'खोज इतिहासबाट हटाउनुहोस्',
    'No recent searches': 'हालका खोजहरू छैनन्',
    'Your searches will appear here.': 'तपाईंका खोजहरू यहाँ देखिनेछन्।',
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
    'Shop by department': 'विभागअनुसार किनमेल',
    'aisles': 'विभागहरू',
    'Coming soon': 'छिट्टै आउँदैछ',
    'item': 'सामान',
    'Picked from the store catalog': 'स्टोरको सूचीबाट छनोट गरिएको',
    'Explore products': 'सामानहरू हेर्नुहोस्',
    'No products available': 'सामान उपलब्ध छैन',
    'Store products will appear here when they are available.':
        'स्टोरमा सामान उपलब्ध भएपछि यहाँ देखिनेछन्।',
    'Could not update search history': 'खोज इतिहास अद्यावधिक गर्न सकिएन',
    'Close product preview': 'सामानको झलक बन्द गर्नुहोस्',
    'Increase quantity': 'परिमाण बढाउनुहोस्',
    'Decrease quantity': 'परिमाण घटाउनुहोस्',
    'Quantity': 'परिमाण',
    'added to your basket': 'तपाईंको टोकरीमा थपियो',
    'Add to basket': 'टोकरीमा थप्नुहोस्',
    'Out of stock': 'स्टकमा छैन',
    'Place order': 'अर्डर गर्नुहोस्',
    'Nepal time': 'नेपालको समय',
    'Your device': 'तपाईंको यन्त्र',
    'Instant Delivery': 'तुरुन्त डेलिभरी',
    'Deliver as soon as possible.': 'सम्भव भएसम्म चाँडो डेलिभरी गर्नुहोस्।',
    'In about 2 hours': 'करिब २ घण्टामा',
    'In about 4 hours': 'करिब ४ घण्टामा',
    'Choose date and time': 'मिति र समय छान्नुहोस्',
    'Schedule at least two hours ahead.':
        'कम्तीमा दुई घण्टापछिको समय छान्नुहोस्।',
    'Choose delivery date · Nepal time':
        'डेलिभरी मिति छान्नुहोस् · नेपालको समय',
    'Choose delivery time · Nepal time': 'डेलिभरी समय छान्नुहोस् · नेपालको समय',
    'Choose a time at least two hours from now.':
        'अहिलेबाट कम्तीमा दुई घण्टापछिको समय छान्नुहोस्।',
    'Total': 'जम्मा',
    'Clear basket?': 'टोकरी खाली गर्ने?',
    'Remove all items from your basket?': 'टोकरीका सबै सामान हटाउने?',
    'Sign in to manage your account': 'खाता व्यवस्थापन गर्न साइन इन गर्नुहोस्',
    'Guest Customer': 'अतिथि ग्राहक',
    'Show password': 'पासवर्ड देखाउनुहोस्',
    'Hide password': 'पासवर्ड लुकाउनुहोस्',
    'Refresh': 'फेरि लोड गर्नुहोस्',
    'Payment preference': 'भुक्तानी प्राथमिकता',
    'Profile photo updated.': 'प्रोफाइल फोटो अद्यावधिक भयो।',
    'Could not save appearance preference:':
        'रूपको प्राथमिकता सुरक्षित गर्न सकिएन:',
    'Could not save language preference:':
        'भाषाको प्राथमिकता सुरक्षित गर्न सकिएन:',
    'Edit profile': 'प्रोफाइल सम्पादन गर्नुहोस्',
    'Profile photo': 'प्रोफाइल फोटो',
    'Change profile photo': 'प्रोफाइल फोटो परिवर्तन गर्नुहोस्',
    'Choose a profile photo that is 5 MB or smaller.':
        '५ एमबी वा सोभन्दा सानो प्रोफाइल फोटो छान्नुहोस्।',
    'Delivery is available within 10 km of Ram Prasad General Store. Add your full ward and street details, and place a map pin within the service area.':
        'राम प्रसाद जनरल स्टोरबाट १० किमिभित्र डेलिभरी उपलब्ध छ। वडा र सडकको पूरा विवरण लेखी सेवा क्षेत्रभित्र नक्सा पिन राख्नुहोस्।',
    'You are signed out for now, but this device could not clear your saved session:':
        'तपाईं अहिलेका लागि साइन आउट हुनुभयो, तर यन्त्रबाट सुरक्षित सत्र हटाउन सकिएन:',
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
