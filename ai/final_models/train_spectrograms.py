import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms
from sklearn.model_selection import StratifiedKFold
import numpy as np
import matplotlib.pyplot as plt
import os
import time

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

if __name__ == "__main__":
    # Config
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"Using device: {device}")
    
    # Settings
    BATCH_SIZE = 16
    EPOCHS = 35
    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    IMG_DIR = os.path.join(CURRENT_DIR, 'img')

    # Data
    transform = transforms.Compose([
        transforms.Resize((512, 512)),
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])
    dataset = datasets.ImageFolder(IMG_DIR, transform=transform)

    k_folds = 5
    skf = StratifiedKFold(n_splits=k_folds, shuffle=True, random_state=42)
    fold_accuracies = []
    
    # Metrics storage for plotting
    history = {'loss': [], 'acc': []}
    
    start_time = time.time()

    for fold, (train_ids, val_ids) in enumerate(skf.split(np.arange(len(dataset)), dataset.targets)):
        print(f'FOLD {fold+1}')
        print('--------------------------------')
        train_sub = Subset(dataset, train_ids)
        val_sub = Subset(dataset, val_ids)
        
        # Optimized DataLoader with more workers and pinned memory
        train_loader = DataLoader(train_sub, batch_size=BATCH_SIZE, shuffle=True, num_workers=4, pin_memory=True)
        val_loader = DataLoader(val_sub, batch_size=BATCH_SIZE, num_workers=4, pin_memory=True)

        # Model
        model = create_model(len(dataset.classes)).to(device)

        # Train
        opt = optim.Adam(model.parameters(), lr=0.001)
        scheduler = optim.lr_scheduler.StepLR(opt, step_size=5, gamma=0.5)
        criterion = nn.CrossEntropyLoss()
        
        fold_loss_history = []
        fold_acc_history = []
        best_fold_acc = 0.0
        
        for epoch in range(EPOCHS):
            model.train()
            running_loss = 0.0
            for i, (x, y) in enumerate(train_loader):
                opt.zero_grad()
                loss = criterion(model(x.to(device)), y.to(device))
                loss.backward()
                opt.step()
                running_loss += loss.item()
                if (i + 1) % 10 == 0:
                    print(f"Fold {fold+1}, Epoch [{epoch+1}/{EPOCHS}], Step [{i+1}/{len(train_loader)}], Loss: {loss.item():.4f}")
            
            scheduler.step()
            
            avg_loss = running_loss / len(train_loader)
            fold_loss_history.append(avg_loss)
            
            model.eval()
            with torch.no_grad():
                acc = sum((model(x.to(device)).argmax(1) == y.to(device)).sum().item() for x, y in val_loader) / len(val_sub)
                fold_acc_history.append(acc)
                print(f"Fold {fold+1}, Epoch {epoch+1}/{EPOCHS}: Loss {avg_loss:.4f}, Acc {acc:.2f}")
                
                if acc > best_fold_acc:
                    best_fold_acc = acc
                    save_path = os.path.join(CURRENT_DIR, f'model_fold_{fold+1}.pt')
                    torch.save(model.state_dict(), save_path)
                    print(f"Fold {fold+1}, Epoch {epoch+1}/{EPOCHS}: Loss {avg_loss:.4f}, Acc {acc:.2f} [Saved Best]")
                else:
                    print(f"Fold {fold+1}, Epoch {epoch+1}/{EPOCHS}: Loss {avg_loss:.4f}, Acc {acc:.2f}")
        
        fold_accuracies.append(best_fold_acc)
        history['loss'].append(fold_loss_history)
        history['acc'].append(fold_acc_history)

    total_time = time.time() - start_time
    print(f"\nTotal Training Time: {total_time/60:.2f} minutes")
    print(f"Average Accuracy: {sum(fold_accuracies)/len(fold_accuracies):.2f}")
    
    # Plotting Results
    plt.figure(figsize=(12, 5))
    
    plt.subplot(1, 2, 1)
    for i, losses in enumerate(history['loss']):
        plt.plot(losses, label=f'Fold {i+1} (Final: {losses[-1]:.4f})')
    plt.title('Training Loss per Epoch')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.legend()
    
    plt.subplot(1, 2, 2)
    for i, accs in enumerate(history['acc']):
        plt.plot(accs, label=f'Fold {i+1} (Best: {fold_accuracies[i]:.2f})')
    plt.title('Validation Accuracy per Epoch')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy')
    plt.legend()
    
    plt.tight_layout()
    plot_path = os.path.join(CURRENT_DIR, 'training_results.png')
    plt.savefig(plot_path)
    print(f"Graphs saved to {plot_path}")