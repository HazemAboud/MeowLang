import os
import argparse
import sys
import numpy as np

# Check for dependencies
try:
    import librosa
    import librosa.display
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"Error: Missing dependency. {e}")
    print("Please install required packages: pip install librosa matplotlib")
    sys.exit(1)

def create_spectrogram(audio_file, output_file, n_mels=128, fmax=8000):
    """
    Generates a Mel-spectrogram from an audio file and saves it as an image.
    """
    try:
        # Load audio file
        y, sr = librosa.load(audio_file)

        # Compute Mel-spectrogram
        S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels, fmax=fmax)
        
        # Convert to decibels (Log-Mel Spectrogram)
        S_dB = librosa.power_to_db(S, ref=np.max)

        # Plotting
        # We disable axes and padding to ensure the image contains only data
        plt.figure(figsize=(10, 4))
        librosa.display.specshow(S_dB, sr=sr, x_axis='time', y_axis='mel', fmax=fmax)
        plt.axis('off')
        plt.tight_layout(pad=0)

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

        # Save
        plt.savefig(output_file, bbox_inches='tight', pad_inches=0)
        plt.close()
        
    except Exception as e:
        print(f"Failed to process {audio_file}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Convert raw audio files to Mel-spectrogram images.")
    parser.add_argument('--input_dir', type=str, required=True, help="Root directory containing audio files (e.g., raw_audio/)")
    parser.add_argument('--output_dir', type=str, required=True, help="Output directory for images (e.g., img/)")
    
    args = parser.parse_args()

    if not os.path.exists(args.input_dir):
        print(f"Error: Input directory '{args.input_dir}' does not exist.")
        return

    valid_extensions = ('.wav', '.mp3', '.ogg', '.flac', '.m4a')
    count = 0

    print(f"Scanning '{args.input_dir}' for audio files...")

    for root, dirs, files in os.walk(args.input_dir):
        for file in files:
            if file.lower().endswith(valid_extensions):
                input_path = os.path.join(root, file)
                
                # Calculate relative path to maintain subdirectory structure (classes)
                rel_path = os.path.relpath(root, args.input_dir)
                output_subdir = os.path.join(args.output_dir, rel_path)
                
                # Change extension to .png
                output_filename = os.path.splitext(file)[0] + '.png'
                output_path = os.path.join(output_subdir, output_filename)

                create_spectrogram(input_path, output_path)
                count += 1
                if count % 10 == 0:
                    print(f"Processed {count} files...", end='\r')

    print(f"\nDone! Processed {count} files. Saved to '{args.output_dir}'.")

if __name__ == "__main__":
    main()