// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Gemini AI';

  @override
  String get geminiTitle => 'Gemini 2.5 Flash';

  @override
  String get hintText => 'Mesaj yaz veya konuş...';

  @override
  String get thinking => 'Gemini düşünüyor...';

  @override
  String get welcomeMessage =>
      'Merhaba! Ben Gemini 2.5 Flash. Resim gönderebilir, konuşarak mesaj atabilirsin!';

  @override
  String get imagePromptGallery => 'Bu resimde ne var? Açıklayabilir misin?';

  @override
  String get imagePromptCamera => 'Bu fotoğrafı çektim, ne görüyorsun?';

  @override
  String get gallery => 'Galeri';

  @override
  String get camera => 'Kamera';

  @override
  String get startListening => 'Sesli giriş başlat';

  @override
  String get stopListening => 'Sesli girişi durdur';

  @override
  String get micPermissionDenied => 'Mikrofon izni verilmedi. Ayarlardan açın.';

  @override
  String get cameraPermissionDenied =>
      'Kamera izni verilmedi. Ayarlardan açın.';

  @override
  String get speechNotAvailable => 'Ses tanıma mevcut değil';

  @override
  String get speechError => 'Ses tanıma hatası';

  @override
  String get imageError => 'Resim yükleme hatası';

  @override
  String get cameraError => 'Kamera hatası';
}
