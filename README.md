# 🐱 MeowLang

MeowLang is a mobile application that translates cat vocalizations by classifying the sounds into 5 categories, angry, food, resting, mother call and isolation.
## Detailed Data Cleaning and Model Development Process
https://github.com/HazemAboud/MeowLang-AI
## 🐾 Features
*   **Cat vocals classification**: Performed using a spectrogram of the audio generated using a custom dart script as input to a CNN model which classifies the image into one of five categories (angry, food, resting, mother call and isolation).
*   **Database**: Firestore for saving user and cat profiles, translation records, history and translation corrections.
*   **Mobile Application**: A lightweight android application with a clean interface.
*   **User Profile Management**: Users can create an account using email and password, auto login is performed by default using flutter_secure_storage after the first login.
*   **Cat Profile Management**: Users can create and manage their cat profiles saving the cat's name, image, breed and age.
*   **Translation**: Capture the sound of the cat and display humanized text based on the model's output. E.g. "Mama, are you there?" (motherCall)
*   **History and Analytics**: Displays translation history and a break down of translation categories for each cat
*   **Misclassification**: Users can assign a new label to misclassified audios, the new label along with the spectrogram and the data of the original translation are saved in the database to be used in fine tuning the model.
*   **Performance logging**: Logs time taken for the translation process and database operations to the `query_performance` collection in Firestore for performance monitoring.

## 🛠️ Tech Stack

*   **Frontend**: Flutter
*   **Backend**: Firebase and on device inference usign `tflite_service`
*   **Machine Learning**: Pytorch for initial versions and Tensorflow for the final setup.
*   **Audio Processing**: Using a custom dart script to generate spectrograms from audio files.

## Video Presentation

