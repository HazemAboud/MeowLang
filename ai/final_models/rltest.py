import argparse
import os
import torch
import torch.nn as nn
from torchvision import transforms
from PIL import Image

def create_model(num_classes):
    return nn.Sequential(
        nn.Conv2d(3, 32, 3, padding=1), nn.BatchNorm2d(32), nn.ReLU(), nn.MaxPool2d(2),
        nn.Conv2d(32, 64, 3, padding=1), nn.BatchNorm2d(64), nn.ReLU(), nn.MaxPool2d(2),
        nn.Conv2d(64, 128, 3, padding=1), nn.BatchNorm2d(128), nn.ReLU(), nn.MaxPool2d(2),
        nn.Conv2d(128, 256, 3, padding=1), nn.BatchNorm2d(256), nn.ReLU(), nn.AdaptiveAvgPool2d(1),
        nn.Flatten(),
        nn.Dropout(0.5),
        nn.Linear(256, num_classes)
    )

def main():
    parser = argparse.ArgumentParser(description="Predict classes for images in a folder.")
    parser.add_argument('--input_dir', type=str, default='rltest/spectrograms', help='Directory containing images to process')
    parser.add_argument('--model', type=str, default='final_model_fold_2_finetuned.pt', help='Path to model file')
    args = parser.parse_args()

    # Device config
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Validate model path
    model_path = args.model
    if not os.path.exists(model_path):
        # Check in script directory
        if os.path.exists(os.path.join(script_dir, args.model)):
            model_path = os.path.join(script_dir, args.model)
        elif os.path.exists(model_path + '.pt'):
            model_path += '.pt'
        elif os.path.exists(os.path.join(script_dir, args.model + '.pt')):
            model_path = os.path.join(script_dir, args.model + '.pt')
        else:
            print(f"Error: Model {args.model} not found.")
            return

    # Validate input directory and get files
    input_dir_path = args.input_dir
    if not os.path.exists(input_dir_path):
        # Check relative to script directory
        script_relative_path = os.path.join(script_dir, args.input_dir)
        if os.path.exists(script_relative_path):
            input_dir_path = script_relative_path
        else:
            print(f"Error: Input directory '{args.input_dir}' not found.")
            return

    valid_extensions = ('.png', '.jpg', '.jpeg', '.bmp', '.tiff')
    image_files = [os.path.join(input_dir_path, f) for f in os.listdir(input_dir_path) if f.lower().endswith(valid_extensions)]

    # Load Model State
    try:
        state_dict = torch.load(model_path, map_location=device)
        
        # Infer classes from weights (Last layer is index 18 in Sequential)
        if '18.weight' in state_dict:
            num_classes = state_dict['18.weight'].shape[0]
        else:
            # Fallback for different sequential naming
            keys = list(state_dict.keys())
            num_classes = state_dict[keys[-2]].shape[0]
            
        model = create_model(num_classes).to(device)
        model.load_state_dict(state_dict)
        model.eval()
        print(f"Loaded model: {model_path} ({num_classes} classes)")
    except Exception as e:
        print(f"Error loading model: {e}")
        return

    # Transform (Must match training)
    transform = transforms.Compose([
        transforms.Resize((512, 512)),
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])

    # Attempt to load class names from 'img' folder if it exists nearby
    class_names = None
    img_dir = os.path.join(script_dir, 'img')
    if os.path.exists(img_dir):
        class_names = sorted([d for d in os.listdir(img_dir) if os.path.isdir(os.path.join(img_dir, d))])
        if len(class_names) != num_classes:
            print(f"Warning: Found {len(class_names)} classes in '{img_dir}' but model expects {num_classes}.")
            class_names = None # Mismatch, safer to show indices
        else:
            print(f"Class mapping loaded from '{img_dir}':")
            for i, name in enumerate(class_names):
                print(f"  {i}: {name}")

    # Process Images
    print("\nPredictions:")
    print("-" * 40)
    
    for img_file in image_files:
        try:
            img = Image.open(img_file).convert('RGB')
            img_t = transform(img).unsqueeze(0).to(device)
            
            with torch.no_grad():
                out = model(img_t)
                probs = torch.nn.functional.softmax(out, dim=1)
                conf, pred = torch.max(probs, 1)
                
            idx = pred.item()
            percentage = conf.item() * 100
            
            label = class_names[idx] if class_names else f"Class {idx}"
            
            print(f"Image: {os.path.basename(img_file)}")
            print(f"Result: {label} (Index: {idx}, {percentage:.2f}%)")
            print("-" * 40)
            
        except Exception as e:
            print(f"Error processing {img_file}: {e}")

if __name__ == "__main__":
    main()