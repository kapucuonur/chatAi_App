import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('tr');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const ChatScreen(),
    );
  }
}

class Message {
  final String text;
  final File? image;
  final bool isUser;
  Message({required this.text, this.image, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  late final GenerativeModel _model;
  late final ChatSession _chat;

  // Ses özellikleri
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  String _speechStatus = 'unknown';
  String _lastError = '';

  @override
  void initState() {
    super.initState();

    // Gemini API
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Gemini API key not found in .env");
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    _chat = _model.startChat();

    // Initialize speech immediately
    _initSpeech();

    // Hoş geldin mesajı
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = AppLocalizations.of(context)!;
      _messages.add(Message(text: loc.welcomeMessage, isUser: false));
      setState(() {});
      _scrollToBottom();

      // Hoş geldin mesajını konuş
      _speak(loc.welcomeMessage);
    });
  }

  Future<void> _initSpeech() async {
    try {
      print("=== INIT SPEECH START ===");
      print(
        "Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}",
      );

      bool available = await _speechToText.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          setState(() {
            _speechStatus = status;
          });

          // If speech stops listening, update UI
          if (status == 'notListening' && _isListening) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (errorNotification) {
          print('Speech error: ${errorNotification.errorMsg}');
          setState(() {
            _lastError =
                '${errorNotification.errorMsg} - ${errorNotification.permanent}';
          });

          // Handle specific iOS errors
          if (errorNotification.errorMsg == 'error_retry') {
            print('iOS speech error - will retry in 1 second');
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && !_isListening) {
                _startListening();
              }
            });
          }

          if (errorNotification.permanent) {
            print('Permanent error: ${errorNotification.errorMsg}');
            setState(() {
              _speechEnabled = false;
            });
          }
        },
        debugLogging: true,
      );

      setState(() {
        _speechEnabled = available;
        _speechInitialized = true;
      });

      print("Speech initialized: $available");
      print("=== INIT SPEECH END ===");
    } catch (e, stackTrace) {
      print("Speech initialization failed with exception: $e");
      print("Stack trace: $stackTrace");
      setState(() {
        _speechEnabled = false;
        _speechInitialized = true;
      });
    }
  }

  Future<void> _startListening() async {
    print("=== START LISTENING BUTTON CLICKED ===");

    if (!_speechInitialized) {
      await _initSpeech();
    }

    if (!_speechEnabled) {
      print("Speech not enabled!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'tr'
                ? "Ses tanıma mevcut değil"
                : "Speech recognition not available",
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_isListening) {
      try {
        print("Starting speech recognition...");

        // Stop any existing listening first (iOS fix)
        if (_speechStatus == 'listening' || _speechStatus == 'notListening') {
          await _speechToText.stop();
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // For iOS, we need to handle permission prompts
        if (Platform.isIOS) {
          // Request permission by attempting to listen
          bool hasPermission = await _speechToText.initialize(
            onStatus: (status) => print('Status: $status'),
            onError: (error) => print('Error: $error'),
          );

          if (!hasPermission) {
            print("No speech permission on iOS");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Localizations.localeOf(context).languageCode == 'tr'
                      ? "Ses izinleri gerekli. Ayarlardan kontrol edin."
                      : "Speech permissions required. Please check settings.",
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }

        await _speechToText.listen(
          onResult: (result) {
            print("Speech result: ${result.recognizedWords}");
            if (result.finalResult) {
              setState(() {
                _controller.text = result.recognizedWords;
              });
              // Auto-submit when final result is received
              if (result.recognizedWords.isNotEmpty) {
                _sendMessage(text: result.recognizedWords);
              }
            }
          },
          localeId: Localizations.localeOf(context).languageCode == 'tr'
              ? 'tr_TR'
              : 'en_US',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          onSoundLevelChange: (level) {
            print("Sound level: $level");
          },
          cancelOnError: true, // Let iOS handle errors gracefully
          listenMode: stt.ListenMode.dictation,
        );

        print("Speech recognition started successfully");
        setState(() => _isListening = true);
      } catch (e) {
        print("Error starting speech recognition: $e");
        setState(() => _isListening = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'tr'
                  ? "Ses tanıma hatası: ${e.toString()}"
                  : "Speech recognition error: ${e.toString()}",
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    print("Stopping speech recognition...");
    try {
      if (_isListening || _speechStatus == 'listening') {
        await _speechToText.stop();
        setState(() => _isListening = false);
        print("Speech recognition stopped");
      }
    } catch (e) {
      print("Error stopping speech recognition: $e");
      setState(() => _isListening = false);
    }
  }

  Future<void> _speak(String text) async {
    try {
      final String displayText = text.length > 50
          ? '${text.substring(0, 50)}...'
          : text;
      print("Speaking: $displayText");
      await _flutterTts.setLanguage(
        Localizations.localeOf(context).languageCode == 'tr'
            ? 'tr-TR'
            : 'en-US',
      );
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(text);
      print("Speech started");
    } catch (e) {
      print("Error with TTS: $e");
    }
  }

  Future<void> _sendMessage({String? text, File? image}) async {
    final loc = AppLocalizations.of(context)!;
    final messageText = text?.trim() ?? _controller.text.trim();
    if (messageText.isEmpty && image == null) return;

    // Stop listening before sending
    if (_isListening) {
      await _stopListening();
    }

    _controller.clear();

    setState(() {
      _messages.add(Message(text: messageText, image: image, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final content = image != null
          ? Content.multi([
              TextPart(
                messageText.isEmpty ? loc.imagePromptGallery : messageText,
              ),
              DataPart('image/jpeg', await image.readAsBytes()),
            ])
          : Content.text(messageText);

      final response = await _chat.sendMessage(content);
      final responseText =
          response.text ??
          (Localizations.localeOf(context).languageCode == 'tr'
              ? "Cevap alınamadı."
              : "No response received.");

      setState(() {
        _messages.add(Message(text: responseText, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();

      _speak(responseText); // Sesli cevap
    } catch (e) {
      final errorMessage = Localizations.localeOf(context).languageCode == 'tr'
          ? 'Hata: $e'
          : 'Error: $e';

      setState(() {
        _messages.add(Message(text: errorMessage, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    print("Pick image button clicked");
    try {
      // Stop listening before picking image
      if (_isListening) {
        await _stopListening();
      }

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        print("Image picked: ${picked.path}");
        final imageFile = File(picked.path);
        setState(
          () =>
              _messages.add(Message(text: '', image: imageFile, isUser: true)),
        );
        _scrollToBottom();
        await _sendMessage(
          text: AppLocalizations.of(context)!.imagePromptGallery,
          image: imageFile,
        );
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'tr'
                ? "Resim yükleme hatası: $e"
                : "Image loading error: $e",
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    print("Take photo button clicked");

    try {
      // Stop listening before taking photo
      if (_isListening) {
        await _stopListening();
      }

      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null) {
        print("Photo taken: ${picked.path}");
        final imageFile = File(picked.path);
        setState(
          () =>
              _messages.add(Message(text: '', image: imageFile, isUser: true)),
        );
        _scrollToBottom();
        await _sendMessage(
          text: AppLocalizations.of(context)!.imagePromptCamera,
          image: imageFile,
        );
      }
    } catch (e) {
      print("Error taking photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'tr'
                ? "Kamera hatası: $e"
                : "Camera error: $e",
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Message msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[700] : Colors.grey[850],
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    msg.image!,
                    width: 240,
                    height: 240,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (msg.text.isNotEmpty)
              MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: const TextStyle(color: Colors.white, fontSize: 16),
                      code: const TextStyle(backgroundColor: Color(0xFF2A2A2A)),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.geminiTitle),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: (locale) => MyApp.setLocale(context, locale),
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('tr'), child: Text('Türkçe')),
              PopupMenuItem(value: Locale('en'), child: Text('English')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isLoading) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            loc.thinking,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildMessage(_messages[i]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                // Galeri butonu
                IconButton(
                  onPressed: _isLoading ? null : _pickImage,
                  tooltip: Localizations.localeOf(context).languageCode == 'tr'
                      ? 'Galeri'
                      : 'Gallery',
                  icon: Icon(
                    Icons.photo_library,
                    color: _isLoading ? Colors.grey : Colors.white,
                  ),
                ),

                // Kamera butonu
                IconButton(
                  onPressed: _isLoading ? null : _takePhoto,
                  tooltip: Localizations.localeOf(context).languageCode == 'tr'
                      ? 'Kamera'
                      : 'Camera',
                  icon: Icon(
                    Icons.camera_alt,
                    color: _isLoading ? Colors.grey : Colors.white,
                  ),
                ),

                // Mikrofon butonu
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : (_isListening ? _stopListening : _startListening),
                  tooltip: _isListening
                      ? (Localizations.localeOf(context).languageCode == 'tr'
                            ? 'Sesli girişi durdur'
                            : 'Stop voice input')
                      : (Localizations.localeOf(context).languageCode == 'tr'
                            ? 'Sesli giriş başlat'
                            : 'Start voice input'),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      key: ValueKey(_isListening),
                      color: _isListening
                          ? Colors.redAccent
                          : (_isLoading ? Colors.grey : Colors.white),
                      size: 28,
                    ),
                  ),
                ),

                // Mesaj yazma alanı
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: loc.hintText,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Gönder butonu
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : () => _sendMessage(),
                  icon: Icon(
                    Icons.send,
                    color: _isLoading ? Colors.grey : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }
}
