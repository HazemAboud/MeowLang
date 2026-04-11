import sys
import os
from flask import Flask, jsonify, g, request
from datetime import datetime
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error, pooling

# --- Configuration ---
app = Flask(__name__)
# Allow requests from the React frontend (running on localhost:3000)
CORS(app, resources={r"/api/*": {"origins": "http://localhost:3000"}})

# Database configuration from your existing project
DB_CONFIG = {
    'host': '103.82.231.117',
    'user': 'izhadnwk_hazem',
    'password': 'vUBUW0#@cp~p',
    'database': 'izhadnwk_meowlang_hazem',
    'raise_on_warnings': True
}

# The directory where the production model is stored
DEPLOYED_MODEL_DIR = r"E:\meow_lang\models\deployed"
# The base directory for browsing datasets for training
DATASET_BASE_DIR = r"E:\meow_lang\data"

# --- Database Connection Pooling ---
_db_pool = None

def get_db_pool():
    """Initializes and returns the database connection pool."""
    global _db_pool
    if _db_pool is None:
        try:
            _db_pool = mysql.connector.pooling.MySQLConnectionPool(
                pool_name="admin_pool",
                pool_size=3,
                **DB_CONFIG
            )
            print("Database connection pool created successfully for admin panel.")
        except Error as e:
            print(f"Error creating database connection pool: {e}")
            return None
    return _db_pool

@app.before_request
def get_db_connection():
    """Get a connection from the pool before each request."""
    pool = get_db_pool()
    if pool:
        try:
            g.db = pool.get_connection()
        except Error as e:
            print(f"Failed to get DB connection: {e}")
            g.db = None
    else:
        g.db = None

@app.teardown_request
def teardown_db(exception=None):
    """Return the connection to the pool after each request."""
    db = g.pop('db', None)
    if db is not None:
        db.close()

# --- API Endpoints ---

@app.route('/api/query-performance', methods=['GET'])
def get_query_performance():
    """
    Endpoint to get the average execution time for each query.
    """
    if not g.db:
        return jsonify({"error": "Database unavailable"}), 503
    cursor = None
    try:
        cursor = g.db.cursor(dictionary=True)
        query = """
            SELECT endpoint, query_name, AVG(execution_time_ms) as avg_time, COUNT(*) as call_count
            FROM query_performance
            GROUP BY endpoint, query_name
            ORDER BY avg_time DESC;
        """
        cursor.execute(query)
        performance_data = cursor.fetchall()
        return jsonify(performance_data)
    except Error as e:
        print(f"Query Performance Error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/api/model-performance', methods=['GET'])
def get_model_performance():
    """
    Endpoint to get model performance metrics, including correction rate
    and data distribution.
    """
    if not g.db:
        return jsonify({"error": "Database unavailable"}), 503
    cursor = None
    try:
        cursor = g.db.cursor(dictionary=True)
        
        # Get total translations
        cursor.execute("SELECT COUNT(*) as count FROM translations")
        total_translations = cursor.fetchone()['count']

        # Get total corrections
        cursor.execute("SELECT COUNT(*) as count FROM corrections")
        total_corrections = cursor.fetchone()['count']

        # Calculate correction rate
        correction_rate = (total_corrections / total_translations) * 100 if total_translations > 0 else 0

        # Get breakdown of original predictions
        cursor.execute("""
            SELECT className as label, COUNT(*) as count 
            FROM translations 
            GROUP BY className 
            ORDER BY count DESC
        """)
        translations_breakdown = cursor.fetchall()

        # Get breakdown of corrected labels (what users said it should be)
        cursor.execute("""
            SELECT new_label as label, COUNT(*) as count 
            FROM corrections 
            GROUP BY new_label 
            ORDER BY count DESC
        """)
        corrections_breakdown = cursor.fetchall()

        response = {
            "totalTranslations": total_translations,
            "totalCorrections": total_corrections,
            "correctionRate": round(correction_rate, 2),
            "translationsBreakdown": translations_breakdown,
            "correctionsBreakdown": corrections_breakdown
        }
        return jsonify(response)
    except Error as e:
        print(f"Model Performance Error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/api/mlflow/models', methods=['GET'])
def get_mlflow_models():
    """
    Endpoint to get the currently deployed model from the deployment directory. 
    """
    try:
        if not os.path.exists(DEPLOYED_MODEL_DIR):
            os.makedirs(DEPLOYED_MODEL_DIR, exist_ok=True)

        # Find model files in the deployment directory
        model_files = [f for f in os.listdir(DEPLOYED_MODEL_DIR) if f.endswith(('.ptl', '.pt'))]

        if not model_files:
            # Return an empty list if no model is found
            return jsonify([])

        # Assume the first model found is the one in production
        model_name = model_files[0]
        model_path = os.path.join(DEPLOYED_MODEL_DIR, model_name)

        # Get file stats to use as version info
        last_modified_time = datetime.fromtimestamp(os.path.getmtime(model_path))

        # Format the response to match what the frontend expects
        deployed_model = [{
            "name": model_name,
            "version": last_modified_time.strftime('%Y-%m-%d %H:%M:%S'),
            "stage": "Production"
        }]
        return jsonify(deployed_model)
    except Exception as e:
        print(f"Error reading deployed models: {e}")
        return jsonify({"error": "Could not read deployed models."}), 500

def check_dataset_folder(folder_path):
    """
    Checks if a folder is a valid dataset folder.
    A valid dataset folder must contain 'train', 'validate', and 'test' subdirectories.
    If it is valid, it returns the class names from the 'train' subdirectory.
    """
    train_path = os.path.join(folder_path, 'train')
    validate_path = os.path.join(folder_path, 'validate')
    test_path = os.path.join(folder_path, 'test')

    if os.path.isdir(train_path) and os.path.isdir(validate_path) and os.path.isdir(test_path):
        try:
            # Get subdirectories inside 'train' path
            class_names = [d for d in os.listdir(train_path) if os.path.isdir(os.path.join(train_path, d))]
            if class_names: # must have at least one class
                return True, class_names
        except OSError:
            return False, None
    return False, None

@app.route('/api/file-explorer', methods=['GET'])
def file_explorer():
    """
    Endpoint to browse directories for training datasets.
    Restricted to DATASET_BASE_DIR. It only shows directories.
    """
    try:
        base_dir = os.path.abspath(DATASET_BASE_DIR)
        relative_path_str = request.args.get('path', '.')

        if os.path.isabs(relative_path_str):
            return jsonify({"error": "Absolute paths are not allowed."}), 400

        target_path = os.path.abspath(os.path.normpath(os.path.join(base_dir, relative_path_str)))

        if not target_path.startswith(base_dir):
            return jsonify({"error": "Access denied. Path is outside of the allowed directory."}), 403

        if not os.path.isdir(target_path):
            return jsonify({"error": "Path does not exist or is not a directory."}), 404

        items = []
        for item_name in sorted(os.listdir(target_path)):
            item_path = os.path.join(target_path, item_name)
            
            # Only include directories in the response
            if os.path.isdir(item_path):
                relative_item_path = os.path.relpath(item_path, base_dir).replace('\\', '/')

                is_valid, class_names = check_dataset_folder(item_path)
                
                item_info = {
                    "name": item_name,
                    "path": relative_item_path,
                    "type": "directory",
                    "isValidDataset": is_valid,
                    "classNames": class_names if is_valid else []
                }
                items.append(item_info)

        parent_dir_path = os.path.dirname(target_path)
        parent = None
        if parent_dir_path.startswith(base_dir) and parent_dir_path != target_path:
            parent_rel_path = os.path.relpath(parent_dir_path, base_dir).replace('\\', '/')
            parent = '' if parent_rel_path == '.' else parent_rel_path

        current_rel_path = os.path.relpath(target_path, base_dir).replace('\\', '/')
        current = '' if current_rel_path == '.' else current_rel_path

        response = {
            "path": current,
            "parent": parent,
            "items": items
        }
        return jsonify(response)

    except Exception as e:
        print(f"File Explorer Error: {e}")
        return jsonify({"error": "An error occurred while browsing files."}), 500

if __name__ == '__main__':
    get_db_pool()
    app.run(host='0.0.0.0', port=8000, debug=True, use_reloader=False)