import os
import argparse
import sys
import numpy as np
import concurrent.futures

# Check for dependencies
try:
    import librosa
    import librosa.display
    import matplotlib
    matplotlib.use('Agg') # Use non-interactive backend for speed and thread safety
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"Error: Missing dependency. {e}")
    print("Please install required packages: pip install librosa matplotlib")
    sys.exit(1)

try:
    from tqdm import tqdm
except ImportError:
    tqdm = None

def create_spectrogram(audio_file, output_file, n_mels=128, fmax=None):
    """
    Generates a Mel-spectrogram from an audio file and saves it as an image.
    """
    try:
        # Load audio file
        y, sr = librosa.load(audio_file, sr=None)

        # Compute Mel-spectrogram
        S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels, fmax=fmax)
        
        # Convert to decibels (Log-Mel Spectrogram)
        S_dB = librosa.power_to_db(S, ref=np.max)

        # Plotting
        plt.figure(figsize=(10, 4))
        librosa.display.specshow(S_dB, sr=sr, x_axis='time', y_axis='mel', fmax=fmax)
        plt.colorbar(format='%+2.0f dB')
        plt.title('Mel-frequency spectrogram')
        plt.tight_layout()

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

        # Save
        plt.savefig(output_file, bbox_inches='tight')
        plt.close('all')
        
    except Exception as e:
        print(f"Failed to process {audio_file}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Convert raw audio files to Mel-spectrogram images.")
    parser.add_argument('--input_dir', type=str, default=r'E:\meow_lang\ai\final_models\rltest', help="Root directory containing audio files (e.g., raw_audio/)")
    parser.add_argument('--output_dir', type=str, default=r'E:\meow_lang\ai\final_models\rltest\spectrograms', help="Output directory for images (e.g., img/)")
    parser.add_argument('--workers', type=int, default=os.cpu_count() or 4, help="Number of parallel workers")
    
    args = parser.parse_args()

    if not os.path.exists(args.input_dir):
        print(f"Error: Input directory '{args.input_dir}' does not exist.")
        return

    valid_extensions = ('.wav', '.mp3', '.ogg', '.flac', '.m4a')
    
    print(f"Scanning '{args.input_dir}'...")

    abs_output_dir = os.path.abspath(args.output_dir)
    tasks = []

    for root, dirs, files in os.walk(args.input_dir):
        # Avoid processing the output directory if it is inside the input directory
        if os.path.abspath(root).startswith(abs_output_dir):
            continue

        for file in files:
            if file.lower().endswith(valid_extensions):
                input_path = os.path.join(root, file)
                
                # Calculate relative path to maintain subdirectory structure (classes)
                rel_path = os.path.relpath(root, args.input_dir)
                output_subdir = os.path.join(args.output_dir, rel_path)
                
                # Change extension to .png
                output_filename = os.path.splitext(file)[0] + '.png'
                output_path = os.path.join(output_subdir, output_filename)

                if not os.path.exists(output_path):
                    tasks.append((input_path, output_path))

    total_files = len(tasks)
    print(f"Found {total_files} new files to process.")

    if total_files == 0:
        print("No new files to convert.")
        return

    print(f"Starting conversion with {args.workers} workers...")
    
    # Process in parallel
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(create_spectrogram, inp, out) for inp, out in tasks]
        
        if tqdm:
            for _ in tqdm(concurrent.futures.as_completed(futures), total=total_files, unit="file"):
                pass
        else:
            for i, _ in enumerate(concurrent.futures.as_completed(futures)):
                if (i + 1) % 10 == 0 or (i + 1) == total_files:
                    print(f"Processed {i + 1}/{total_files} files...", end='\r')

    print(f"\nDone! Saved to '{args.output_dir}'.")

if __name__ == "__main__":
    main()