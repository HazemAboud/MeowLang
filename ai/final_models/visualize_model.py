import torch
import torch.nn as nn
import os
import subprocess
import sys

try:
    import nnviz
except ImportError:
    print("Error: 'nnviz' library is not installed. Please install it via 'pip install nnviz'.")
    exit(1)

class SimplifiedModel(nn.Module):
    def __init__(self, num_classes):
        super().__init__()
        self.layer_1 = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1), nn.BatchNorm2d(32), nn.ReLU(), nn.MaxPool2d(2)
        )
        self.layer_2 = nn.Sequential(
            nn.Conv2d(32, 64, 3, padding=1), nn.BatchNorm2d(64), nn.ReLU(), nn.MaxPool2d(2)
        )
        self.layer_3 = nn.Sequential(
            nn.Conv2d(64, 128, 3, padding=1), nn.BatchNorm2d(128), nn.ReLU(), nn.MaxPool2d(2)
        )
        self.layer_4 = nn.Sequential(
            nn.Conv2d(128, 256, 3, padding=1), nn.BatchNorm2d(256), nn.ReLU(), nn.AdaptiveAvgPool2d(1)
        )
        self.output_layer = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.5),
            nn.Linear(256, num_classes)
        )

    def forward(self, x):
        x = self.layer_1(x)
        x = self.layer_2(x)
        x = self.layer_3(x)
        x = self.layer_4(x)
        x = self.output_layer(x)
        return x

def create_model(num_classes):
    return SimplifiedModel(num_classes)

def get_model_viz():
    """Wrapper for nnviz to instantiate the model without arguments."""
    return create_model(num_classes=10)

def main():
    # Configuration
    OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model_viz.png')

    print(f"Visualizing model to {OUTPUT_FILE} using nnviz...")
    
    # nnviz is primarily a CLI tool. We invoke it via subprocess.
    # Syntax: nnviz <script_path>:<model_factory_function> -o <output_file>
    script_path = os.path.abspath(__file__)
    model_source = f"{script_path}:get_model_viz"
    
    cmd = ["nnviz", model_source, "-o", OUTPUT_FILE]
    
    try:
        subprocess.run(cmd, check=True)
        print("Visualization generated successfully.")
    except FileNotFoundError:
        print("Error: 'nnviz' command not found. Ensure it is installed and in your PATH.")
    except subprocess.CalledProcessError as e:
        print(f"nnviz failed with error: {e}")

if __name__ == "__main__":
    main()