import torch
import torch.nn as nn
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import os

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
    # Configuration
    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    DATA_DIR = os.path.join(CURRENT_DIR, 'img')
    BATCH_SIZE = 32
    IMG_SIZE = 512  # Standard input size, adjust if your models use a different size
    DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    print(f"Running tests on device: {DEVICE}")

    # Data Preprocessing
    # We resize images to ensure they match the model's expected input dimensions
    transform = transforms.Compose([
        transforms.Resize((IMG_SIZE, IMG_SIZE)),
        transforms.ToTensor(),
        # Normalize to match training script
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])

    # Load Dataset
    if not os.path.exists(DATA_DIR):
        print(f"Error: Dataset directory '{DATA_DIR}' not found.")
        return

    try:
        test_dataset = datasets.ImageFolder(root=DATA_DIR, transform=transform)
        test_loader = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False)
        print(f"Loaded dataset with {len(test_dataset)} images across classes: {test_dataset.classes}")
    except Exception as e:
        print(f"Error initializing dataset: {e}")
        return

    # Test Loop for Models 1 through 5
    results = {}
    
    for i in range(1, 6):
        model_name = f'model_fold_{i}'
        
        # Check for file existence (handling potential extensions like .pth or .pt)
        base_path = os.path.join(CURRENT_DIR, model_name)
        model_path = base_path
        os.path.exists(base_path + '.pt')
        model_path = base_path + '.pt'

        print(f"Testing {model_name}...")
        
        try:
            # Load the model
            model = create_model(len(test_dataset.classes)).to(DEVICE)
            model.load_state_dict(torch.load(model_path, map_location=DEVICE))
            model.eval()

            correct = 0
            total = 0

            class_correct = list(0. for i in range(len(test_dataset.classes)))
            class_total = list(0. for i in range(len(test_dataset.classes)))

            with torch.no_grad():
                for images, labels in test_loader:
                    images, labels = images.to(DEVICE), labels.to(DEVICE)
                    outputs = model(images)
                    _, predicted = torch.max(outputs.data, 1)
                    total += labels.size(0)
                    correct += (predicted == labels).sum().item()

                    c = (predicted == labels)
                    for i in range(len(labels)):
                        label = labels[i].item()
                        class_correct[label] += c[i].item()
                        class_total[label] += 1

            accuracy = 100 * correct / total
            results[model_name] = accuracy
            print(f" -> Accuracy: {accuracy:.2f}%")
            for i in range(len(test_dataset.classes)):
                if class_total[i] > 0:
                    print(f"    - {test_dataset.classes[i]}: {100 * class_correct[i] / class_total[i]:.2f}%")

        except Exception as e:
            print(f" -> Error testing {model_name}: {e}")

    # Final Summary
    print("\n" + "="*30)
    print("FINAL ACCURACY REPORT")
    print("="*30)
    for name, acc in results.items():
        print(f"{name}: {acc:.2f}%")
    print("="*30)

if __name__ == '__main__':
    main()