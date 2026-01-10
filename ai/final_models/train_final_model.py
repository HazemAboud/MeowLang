import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import matplotlib.pyplot as plt
import os
import time
import numpy as np

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
    TRAIN_DIR = os.path.join(CURRENT_DIR, 'img')
    TEST_DIR = os.path.join(CURRENT_DIR, 'test_img')
    LOAD_MODEL_PATH = os.path.join(CURRENT_DIR, 'model_fold_2.pt')
    SAVE_MODEL_PATH = os.path.join(CURRENT_DIR, 'final_model_fold_2_finetuned.pt')
    
    BATCH_SIZE = 16
    EPOCHS = 50
    DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {DEVICE}")

    # Data Transforms
    transform = transforms.Compose([
        transforms.Resize((512, 512)),
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])

    # Load Datasets
    if not os.path.exists(TRAIN_DIR) or not os.path.exists(TEST_DIR):
        print("Error: 'img' or 'test_img' directories not found.")
        return

    train_dataset = datasets.ImageFolder(TRAIN_DIR, transform=transform)
    test_dataset = datasets.ImageFolder(TEST_DIR, transform=transform)

    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=4, pin_memory=True)
    test_loader = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=4, pin_memory=True)

    print(f"Training on {len(train_dataset)} images, Testing on {len(test_dataset)} images.")

    # Initialize Model
    model = create_model(len(train_dataset.classes)).to(DEVICE)

    # Load Pre-trained Weights
    if os.path.exists(LOAD_MODEL_PATH):
        print(f"Loading weights from {LOAD_MODEL_PATH}...")
        model.load_state_dict(torch.load(LOAD_MODEL_PATH, map_location=DEVICE))
    else:
        print(f"Warning: {LOAD_MODEL_PATH} not found. Starting training from scratch.")

    # Initial Test
    print("Running initial evaluation on test set...")
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in test_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            outputs = model(images)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    print(f"Initial Test Accuracy: {100 * correct / total:.2f}%")

    # Training Setup
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=10, gamma=0.5)

    # History
    history = {'train_loss': [], 'test_acc': []}

    start_time = time.time()
    best_acc = 0.0

    for epoch in range(EPOCHS):
        model.train()
        running_loss = 0.0
        
        for i, (images, labels) in enumerate(train_loader):
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
        
        scheduler.step()
        avg_loss = running_loss / len(train_loader)
        history['train_loss'].append(avg_loss)

        # Validation
        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for images, labels in test_loader:
                images, labels = images.to(DEVICE), labels.to(DEVICE)
                outputs = model(images)
                _, predicted = torch.max(outputs.data, 1)
                total += labels.size(0)
                correct += (predicted == labels).sum().item()
        
        acc = 100 * correct / total
        history['test_acc'].append(acc)
        
        if acc > best_acc:
            best_acc = acc
            torch.save(model.state_dict(), SAVE_MODEL_PATH)
            print(f"Epoch [{epoch+1}/{EPOCHS}] - Loss: {avg_loss:.4f} - Test Acc: {acc:.2f}% [Saved Best]")
        else:
            print(f"Epoch [{epoch+1}/{EPOCHS}] - Loss: {avg_loss:.4f} - Test Acc: {acc:.2f}%")

    total_time = time.time() - start_time
    print(f"\nTraining Complete in {total_time/60:.2f} minutes.")

    # --- Final Detailed Evaluation for Per-Class Accuracy ---
    print(f"\nLoading best model from {SAVE_MODEL_PATH} for per-class evaluation...")
    model.load_state_dict(torch.load(SAVE_MODEL_PATH, map_location=DEVICE))
    
    class_correct = list(0. for i in range(len(test_dataset.classes)))
    class_total = list(0. for i in range(len(test_dataset.classes)))
    
    model.eval()
    with torch.no_grad():
        for images, labels in test_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            outputs = model(images)
            _, predicted = torch.max(outputs, 1)
            c = (predicted == labels).squeeze()
            
            for i in range(len(labels)):
                label = labels[i].item()
                class_correct[label] += c[i].item()
                class_total[label] += 1

    class_accuracies = []
    class_names = test_dataset.classes
    for i in range(len(class_names)):
        if class_total[i] > 0:
            acc = 100 * class_correct[i] / class_total[i]
        else:
            acc = 0.0
        class_accuracies.append(acc)
        print(f"Class {class_names[i]}: {acc:.2f}%")

    # --- Graphing ---
    plt.figure(figsize=(14, 6))

    # Plot 1: Accuracy per Epoch
    plt.subplot(1, 2, 1)
    plt.plot(range(1, EPOCHS + 1), history['test_acc'], label='Test Accuracy', color='blue')
    plt.title('Test Accuracy per Epoch')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy (%)')
    plt.grid(True)
    # Annotate best point
    best_epoch_acc = max(history['test_acc'])
    best_epoch_idx = history['test_acc'].index(best_epoch_acc) + 1
    plt.annotate(f'Best: {best_epoch_acc:.2f}%', 
                 (best_epoch_idx, best_epoch_acc), 
                 textcoords="offset points", 
                 xytext=(-10,10), 
                 ha='center')
    plt.legend()

    # Plot 2: Accuracy per Class
    plt.subplot(1, 2, 2)
    bars = plt.bar(class_names, class_accuracies, color='green')
    plt.title('Final Accuracy per Class')
    plt.xlabel('Class')
    plt.ylabel('Accuracy (%)')
    plt.ylim(0, 100)
    
    # Annotate bars
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height + 1,
                 f'{height:.1f}%',
                 ha='center', va='bottom')

    plt.tight_layout()
    plot_path = os.path.join(CURRENT_DIR, 'final_training_results.png')
    plt.savefig(plot_path)
    print(f"Graphs saved to {plot_path}")

if __name__ == "__main__":
    main()