import os
import base64
import sys
import traceback
import uuid
import numpy as np
import torch
import torchvision.transforms as transforms
from PIL import Image
from flask import Flask, request, jsonify

# Audio processing dependencies
try:
    import librosa
    import librosa.display
    import matplotlib
    matplotlib.use('Agg') # Use non-interactive backend for server environment
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"Error: Missing dependency. {e}")
    sys.exit(1)

app = Flask(__name__)

# --- Configuration ---
SPECTROGRAM_DIR = r"E:\meow_lang\pc_saved_spectrograms"
MODEL_PATH = r"E:\meow_lang\lib\model_lite.ptl"

# Determine image directory for class names (relative to this script)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
IMG_DIR = os.path.join(CURRENT_DIR, 'img')

# Ensure output directory exists
os.makedirs(SPECTROGRAM_DIR, exist_ok=True)

# --- Model Loading ---
device = torch.device('cpu') # Lite models are typically optimized for CPU
print(f"Loading model from {MODEL_PATH}...")

try:
    # Load the TorchScript Lite model
    model = torch.jit.load(MODEL_PATH, map_location=device)
    model.eval()
    print("Model loaded successfully.")
except Exception as e:
    print(f"CRITICAL ERROR: Failed to load model. {e}")
    sys.exit(1)

# --- Class Names Loading ---
class_names = None
if os.path.exists(IMG_DIR):
    class_names = sorted([d for d in os.listdir(IMG_DIR) if os.path.isdir(os.path.join(IMG_DIR, d))])
    print(f"Class mapping loaded: {class_names}")
else:
    print(f"Warning: '{IMG_DIR}' not found. Predictions will return class indices.")

# --- Preprocessing ---
# Transform must match rltest.py exactly
transform = transforms.Compose([
    transforms.Resize((512, 512)),
    transforms.ToTensor(),
    transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
])

def create_spectrogram(audio_file, output_file, n_mels=128, fmax=None):
    """
    Generates a Mel-spectrogram from an audio file.
    Logic strictly copied from convert_spectrograms.py.
    """
    try:
        # Load audio file (sr=None to preserve native sampling rate)
        y, sr = librosa.load(audio_file, sr=None)

        # Compute Mel-spectrogram
        S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels, fmax=fmax)
        
        # Convert to decibels (Log-Mel Spectrogram)
        S_dB = librosa.power_to_db(S, ref=np.max)

        # Plotting
        plt.figure(figsize=(10, 4))
        # fmax=None matches the updated convert_spectrograms.py
        librosa.display.specshow(S_dB, sr=sr, fmax=fmax)
        plt.axis('off')
        plt.tight_layout(pad=0)

        # Save
        plt.savefig(output_file, bbox_inches='tight', pad_inches=0)
        plt.close('all')
        return True
    except Exception as e:
        print(f"Spectrogram generation error: {e}")
        traceback.print_exc()
        return False

@app.route('/convert', methods=['POST'])
def convert():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    # Create unique filenames
    unique_id = str(uuid.uuid4())
    temp_audio_path = os.path.join(SPECTROGRAM_DIR, f"{unique_id}_{file.filename}")
    spectrogram_path = os.path.join(SPECTROGRAM_DIR, f"{unique_id}.png")

    try:
        # Save Audio
        file.save(temp_audio_path)
        
        # Convert to Spectrogram
        if not create_spectrogram(temp_audio_path, spectrogram_path):
            return jsonify({'error': 'Audio conversion failed'}), 500

        # Load and Transform Image
        img = Image.open(spectrogram_path).convert('RGB')
        img_t = transform(img).unsqueeze(0).to(device)

        # Inference
        with torch.no_grad():
            out = model(img_t)
            probs = torch.nn.functional.softmax(out, dim=1)
            conf, pred = torch.max(probs, 1)
            
        idx = pred.item()
        confidence = conf.item() * 100
        
        label = class_names[idx] if class_names and idx < len(class_names) else str(idx)
        
        # Encode spectrogram to base64 for client display
        with open(spectrogram_path, "rb") as img_file:
            b64_spectrogram = base64.b64encode(img_file.read()).decode('utf-8')

        # Return result
        return jsonify({
            'label': label,
            'confidence': confidence,
            'spectrogram': b64_spectrogram
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)