import torch
import torch.nn as nn
from torch.utils.mobile_optimizer import optimize_for_mobile
import os

# Redefine model structure to match training script exactly
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
    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # Target the most recent finetuned model, or fallback to others
    MODEL_NAME = 'final_model_fold_2_finetuned.pt'
    INPUT_MODEL_PATH = os.path.join(CURRENT_DIR, MODEL_NAME)
    OUTPUT_MODEL_PATH = os.path.join(CURRENT_DIR, 'model_lite.ptl')
    
    # Check if specific model exists, otherwise look for others
    if not os.path.exists(INPUT_MODEL_PATH):
        print(f"Model {MODEL_NAME} not found. Checking for other .pt files...")
        pt_files = [f for f in os.listdir(CURRENT_DIR) if f.endswith('.pt') and 'lite' not in f]
        if not pt_files:
            print("No .pt files found in directory.")
            return
        INPUT_MODEL_PATH = os.path.join(CURRENT_DIR, pt_files[0])
        print(f"Using found model: {pt_files[0]}")
    else:
        print(f"Using model: {MODEL_NAME}")

    device = torch.device('cpu') # Mobile inference runs on CPU
    
    try:
        # Load state dict
        state_dict = torch.load(INPUT_MODEL_PATH, map_location=device)
        
        # Infer num_classes from the last layer (Linear) weights
        # In the Sequential definition, the last layer is index 18
        if '18.weight' in state_dict:
            num_classes = state_dict['18.weight'].shape[0]
        else:
            # Fallback: grab the shape of the very last key in the dict
            last_key = list(state_dict.keys())[-2] # -1 is usually bias, -2 is weight
            num_classes = state_dict[last_key].shape[0]
            
        print(f"Detected {num_classes} classes.")
        
        model = create_model(num_classes)
        model.load_state_dict(state_dict)
        model.eval()
        
        print("Tracing model with example input (1, 3, 512, 512)...")
        example_input = torch.rand(1, 3, 512, 512)
        traced_script_module = torch.jit.trace(model, example_input)
        
        print("Optimizing for mobile...")
        traced_script_module_optimized = optimize_for_mobile(traced_script_module)
        
        traced_script_module_optimized._save_for_lite_interpreter(OUTPUT_MODEL_PATH)
        print(f"Success! Mobile model saved to: {OUTPUT_MODEL_PATH}")
        
    except Exception as e:
        print(f"Error converting model: {e}")

if __name__ == "__main__":
    main()