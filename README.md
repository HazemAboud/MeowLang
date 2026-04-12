# Meow Lang

Meow Lang is a mobile application that translates cat sounds. Using AI-powered audio processing and machine learning, the app classifies cat meows into emotions.

## 🐾 Features

*   **AI Translation Engine**: Converts `.wav` audio recordings of cat meows into mel-spectrograms using a custom library and uses a TFLite model to predict the cat's intent (e.g., "I am feeling hungry"). achieved 93.65% accuracy across 5 classes
*   **Cat Profile Management**: Add, edit, and manage multiple cats with details including breed, age, gender, and profile photos.
*   **Translation History**: Keeps a detailed record of every translation, including the date, predicted emotion, and the generated spectrogram image.
*   **Translation Correction**: Allows the user to correct wrong translations and saves the related audio represenation in the database to be used later to improve         the model
*   **Analytics & Insights**: Visualize your cat's communication patterns through interactive pie charts showing the frequency of different translated "labels."
*   **Cloud Synchronization**: Powered by Firebase Firestore for real-time data sync across devices, including manual user authentication and performance logging.

## 🚀 Tech Stack

*   **Frontend**: Flutter (Dart)
*   **State Management**: Provider
*   **Backend**: Firebase (Firestore & Core)
*   **Machine Learning**: TFLite for on-device inference.
*   **Audio Processing**: `audio_2_spectrogram` cutsom library for generating visual representations of sounds.

## 📈 Performance Monitoring
The app includes a built-in performance logging helper within `FirebaseService` that records query execution times to the `query_performance` which is then displayed in the admin dashboard for monitoring and optimization.
