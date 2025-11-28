````bash


# Gemini AI Assistant

**Speak • Send Photo • Get Voice Reply**
Beautiful, fast, multilingual chat app powered by Google Gemini 2.5 Flash

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini%202.5%20Flash-8B4DFF)
![Platforms](https://img.shields.io/badge/platform-Android%20·%20iOS%20·%20Web-blue)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

## Features

- Real-time voice input (Speech-to-Text)
- Gemini answers with voice (Text-to-Speech)
- Send photos – instant image analysis
- Automatic Turkish ↔ English language detection
- Clean Material 3 design with dark mode
- Fully works on Android, iOS and Web

## Live Web Demo

https://gemini-ai-assistant.onrender.com

## Quick Start

```bash
git clone https://github.com/onurkapucu/gemini-ai-assistant.git
cd gemini-ai-assistant
cp .env.example .env
flutter pub get
flutter run
````

## Get Free Gemini API Key

https://aistudio.google.com/app/apikey

## Build Commands

```bash
# Android APK
flutter build apk --release --split-per-abi

# Web (Render / Vercel / Netlify)
flutter build web --release --web-renderer canvaskit
```

## Tech Stack

- Flutter 3.29+
- google_generative_ai ^0.4.0
- speech_to_text ^6.1.1
- flutter_tts ^4.0.2
- image_picker ^1.1.2

## Security

Never commit your `.env` file.  
Use `.env.example` as template and add your API key locally.

---

<div align="center">

Made with ❤️ by **Onur Kapucu** – 2025

<a href="https://github.com/onurkapucu/gemini-ai-assistant/stargazers">
  <img src="https://img.shields.io/github/stars/onurkapucu/gemini-ai-assistant?style=social" alt="GitHub Stars">
</a>

</div>
