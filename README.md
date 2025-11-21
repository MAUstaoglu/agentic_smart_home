# Agentic Smart Home

# Agentic Smart Home

An intelligent smart home controller built with Flutter, powered by an on-device Gemma 2B LLM. This application demonstrates the power of agentic AI in mobile apps, allowing users to control their smart home environment through natural language voice commands **fully offline**, ensuring privacy and speed without needing an internet connection.

## 📱 Demo

https://github.com/user-attachments/assets/7ad6beff-8285-4dfa-99de-471b7f6d40d1

## ✨ Features

-   **On-Device Intelligence**: Uses Google's Gemma 2B model running locally on the device via `flutter_gemma` for privacy and offline capability.
-   **Agentic UI**: Built with `flutter_ui_agent` to demonstrate how to easily integrate agentic capabilities into Flutter apps.
-   **Natural Language Control**: Speak naturally to control your home (e.g., "Turn on the living room lights and set the color to blue").
-   **Multi-Step Actions**: The agent understands and executes complex, multi-part commands in a single request.
-   **Smart Navigation**: Automatically navigates to the relevant room page when a command is issued for a device in another location.
-   **Voice Feedback**: Visual feedback for speech recognition and agent processing states.
-   **Room Management**: Controls for lights, ambient color, thermostats, TVs, and garage gates across multiple rooms (Living Room, Bedroom, Kitchen, Garage).

## 🛠️ Tech Stack

-   **Framework**: [Flutter](https://flutter.dev/)
-   **LLM**: [flutter_gemma](https://pub.dev/packages/flutter_gemma)
    -   Enables **offline**, on-device inference using Google's Gemma 2B model. No internet connection required for intelligence.
-   **UI Components**: [flutter_ui_agent](https://pub.dev/packages/flutter_ui_agent)
    -   Provides the core agentic UI elements, including the chat interface and action widgets.
-   **Speech Recognition**: [speech_to_text](https://pub.dev/packages/speech_to_text)
    -   Handles **offline** voice-to-text conversion, allowing for fast and private command input.
-   **Navigation**: [synced_page_views](https://pub.dev/packages/synced_page_views)
    -   Manages the synchronized room navigation, ensuring the UI updates smoothly when the agent switches rooms.
-   **State Management**: `ListenableBuilder` & `ChangeNotifier` (Provider-free architecture)

## 🚀 Getting Started

### Prerequisites

-   Flutter SDK installed
-   iOS device or Android device with GPU support.
-   **Gemma Model**: You need the `gemma-2b-it-gpu-int4.bin` model file.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/MAUstaoglu/agentic_smart_home.git
    cd agentic_smart_home
    ```

2.  **Download the Model:**
    -   Download the `gemma-2b-it-gpu-int4.bin` model
    -   Place the file in `assets/models/gemma-2b-it-gpu-int4.bin`.

3.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Run the App:**
    ```bash
    flutter run --profile # Recommended for better performance with LLMs
    ```

## 💡 Usage

1.  **Grant Permissions**: Allow microphone access when prompted.
2.  **Speak**: Tap the microphone icon and say a command.
    -   *Example*: "Turn on the kitchen light."
    -   *Example*: "Set the living room temperature to 24 degrees."
    -   *Example*: "Go to the garage and open the gate."
    -   *Example*: "Turn off all lights in the bedroom."
3.  **Watch the Magic**: The agent will process your request, navigate if necessary, and execute the actions.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
