import os
import shutil
import random

def main():
    # Define paths relative to the script location
    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    IMG_DIR = os.path.join(CURRENT_DIR, 'img')
    TEST_DIR = os.path.join(CURRENT_DIR, 'test_img')
    SPLIT_PERCENT = 0.1

    # Check if source exists
    if not os.path.exists(IMG_DIR):
        print(f"Error: Source directory '{IMG_DIR}' does not exist.")
        return

    # Create test directory if it doesn't exist
    if not os.path.exists(TEST_DIR):
        os.makedirs(TEST_DIR)
        print(f"Created '{TEST_DIR}'")

    # Get list of classes (subdirectories)
    classes = [d for d in os.listdir(IMG_DIR) if os.path.isdir(os.path.join(IMG_DIR, d))]
    
    total_moved = 0

    for class_name in classes:
        src_class_path = os.path.join(IMG_DIR, class_name)
        dst_class_path = os.path.join(TEST_DIR, class_name)

        # Create class directory in test set
        os.makedirs(dst_class_path, exist_ok=True)

        # List all files in the class directory
        files = [f for f in os.listdir(src_class_path) if os.path.isfile(os.path.join(src_class_path, f))]
        
        # Shuffle files to pick random ones
        random.seed(42) # For reproducibility
        random.shuffle(files)

        # Calculate how many to move
        num_to_move = int(len(files) * SPLIT_PERCENT)
        
        print(f"Class {class_name}: Moving {num_to_move} out of {len(files)} files.")

        # Move the files
        for i in range(num_to_move):
            file_name = files[i]
            src_file = os.path.join(src_class_path, file_name)
            dst_file = os.path.join(dst_class_path, file_name)
            shutil.move(src_file, dst_file)
            total_moved += 1

    print(f"\nSuccess! Moved {total_moved} files to the test set.")

if __name__ == "__main__":
    main()