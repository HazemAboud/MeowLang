# Meow Lang

Meow Lang is a mobile application that translates cat sounds. By leveraging AI-powered audio processing and machine learning, the app classifies cat meows into emotions.

## 🐾 Features

*   **AI Translation Engine**: Converts `.wav` audio recordings of cat meows into mel-spectrograms and uses a TFLite model to predict the cat's intent (e.g., "I am feeling hungry").
*   **Cat Profile Management**: Add, edit, and manage multiple cats with details including breed, age, gender, and profile photos.
*   **Translation History**: Keeps a detailed record of every translation, including the date, predicted emotion, and the generated spectrogram image.
*   **Analytics & Insights**: Visualize your cat's communication patterns through interactive pie charts showing the frequency of different translated "labels."
*   **Cloud Synchronization**: Powered by Firebase Firestore for real-time data sync across devices, including manual user authentication and performance logging.

## 🚀 Tech Stack

*   **Frontend**: Flutter (Dart)
*   **State Management**: Provider
*   **Backend**: Firebase (Firestore & Core)
*   **Machine Learning**: TFLite for on-device inference.
*   **Audio Processing**: `audio_2_spectrogram` for generating visual representations of meows.
*   **Data Visualization**: fl_chart for analytics.

## 📈 Performance Monitoring
The app includes a built-in performance logging helper within `FirebaseService` that records query execution times to the `query_performance` which is then displayed in the admin dashboard for monitoring and optimization.
