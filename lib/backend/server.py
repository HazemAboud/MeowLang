import os
import base64
import sys
from datetime import datetime
import time
import threading
import io
import numpy as np
import shutil
import torch
import torchvision.transforms as transforms 
from PIL import Image
from flask import Flask, request, jsonify, g
import traceback
import mysql.connector
from mysql.connector import Error, pooling 

try:
    import librosa
    import librosa.display
    import matplotlib
    matplotlib.use('Agg') 
    import matplotlib.pyplot as plt
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_agg import FigureCanvasAgg
except ImportError as e:
    print(f"Error: Missing dependency. {e}")
    sys.exit(1)

# NOTE: server.py is being retired. Most app behavior is now using FirebaseService
# in Flutter. This file is kept only for legacy compatibility and may be removed.
app = Flask(__name__)

@app.before_request
def start_timer():
    g.start = time.time()

@app.after_request
def add_header(response):
    if hasattr(g, 'start'):
        execution_time_ms = (time.time() - g.start) * 1000
        log_query_performance(request.path, 'endpoint_total', execution_time_ms)
    response.headers["Connection"] = "Keep-Alive"
    return response

SPECTROGRAM_DIR = r"E:\meow_lang\pc_saved_spectrograms"
FEEDBACK_IMAGE_DIR = r"E:\meow_lang\feedback_images"
MODEL_PATH = r"E:\meow_lang\models\deployed\model_lite.ptl"

IMG_DIR = r"E:\meow_lang\ai\final_models\img"

os.makedirs(SPECTROGRAM_DIR, exist_ok=True)
os.makedirs(FEEDBACK_IMAGE_DIR, exist_ok=True)

DB_CONFIG = {
    'host': '103.82.231.117',      
    'user': 'izhadnwk_hazem',           
    'password': 'vUBUW0#@cp~p',   
    'database': 'izhadnwk_meowlang_hazem',  
    'raise_on_warnings': True
}

device = torch.device('cpu') 
print(f"Loading model from {MODEL_PATH}...")

class_names = None
if os.path.exists(IMG_DIR):
    class_names = sorted([d for d in os.listdir(IMG_DIR) if os.path.isdir(os.path.join(IMG_DIR, d))])
    print(f"Class mapping loaded: {class_names}")
else:
    print(f"Warning: '{IMG_DIR}' not found. Predictions will return class indices.")

transform = transforms.Compose([
    transforms.Resize((512, 512)),
    transforms.ToTensor(),
    transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
])

def create_spectrogram(audio_file, output_path=None, n_mels=128, fmax=None):
    try:
        y, sr = librosa.load(audio_file, sr=None)

        S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels, fmax=fmax)
        
        S_dB = librosa.power_to_db(S, ref=np.max)

        fig = Figure(figsize=(10, 4))
        FigureCanvasAgg(fig)
        ax = fig.add_subplot(111)
        librosa.display.specshow(S_dB, sr=sr, fmax=fmax, ax=ax)
        ax.axis('off')
        fig.tight_layout(pad=0)

        buf = io.BytesIO()
        fig.savefig(buf, format='png', bbox_inches='tight', pad_inches=0)

        if output_path:
            with open(output_path, 'wb') as f:
                f.write(buf.getbuffer())

        buf.seek(0)
        return buf.read()
    except Exception as e:
        print(f"Spectrogram generation error: {e}")
        traceback.print_exc()
        return None

_db_pool = None

def get_db_pool():
    """Initializes and returns the database connection pool."""
    global _db_pool
    if _db_pool is None:
        try:
            _db_pool = mysql.connector.pooling.MySQLConnectionPool(
                pool_name="meowlang_pool",
                pool_size=5,  
                **DB_CONFIG
            )
            print("Database connection pool created successfully.")
        except Error as e:
            print(f"FATAL: Error creating database connection pool: {e}")
            sys.exit(1)
    return _db_pool

def log_query_performance(endpoint, query_name, execution_time_ms):
    """Logs query performance to the database."""
    conn = None
    cursor = None
    try:
        conn = get_db_pool().get_connection()
        cursor = conn.cursor()
        sql = """
            INSERT INTO query_performance (endpoint, query_name, execution_time_ms) 
            VALUES (%s, %s, %s)
        """
        cursor.execute(sql, (endpoint, query_name, execution_time_ms))
        conn.commit()
    except Error as e:
        print(f"Could not log query performance: {e}")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close() # Returns connection to the pool

def get_db():
    if 'db' not in g:
        try:
            g.db = get_db_pool().get_connection()
        except Error as err:
            print(f"Database connection error from pool: {err}")
            return None
    return g.db
@app.teardown_appcontext
def teardown_db(exception=None):
    db = g.pop('db', None)
    if db is not None:
        db.close()

@app.route('/health', methods=['GET', 'HEAD'])
def health_check():
    return jsonify({'status': 'ok'}), 200

@app.route('/cats', methods=['GET'])
def get_cats():
    conn = get_db()
    user_id = request.args.get('userId')
    if not user_id:
        return jsonify([]), 200

    cursor = None
    try:  
        cursor = conn.cursor(dictionary=True)
        sql = "SELECT * FROM cats WHERE userId = %s ORDER BY name"

        start_time = time.time()
        cursor.execute(sql, (user_id,))
        cats = cursor.fetchall() or []
        end_time = time.time()

        execution_time_ms = (end_time - start_time) * 1000
        log_query_performance(request.path, 'get_user_cats', execution_time_ms)

        return jsonify(cats), 200
    except Error as e:
        print(f"Get Cats Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/cats', methods=['POST'])
def create_cat():
    conn = get_db()
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"status": "error", "message": "Invalid JSON"}), 400
        user_id = data.get('userId')
        if not user_id:
            return jsonify({"status": "error", "message": "userId is required"}), 400
        cursor = conn.cursor(dictionary=True)
        sql = """INSERT INTO cats (name, breed, gender, age, img_path, userId) 
                 VALUES (%s, %s, %s, %s, %s, %s)"""
        img = data.get('img_path')
        val = (data['name'], data['breed'], data['gender'], data['age'], img, user_id)
        start_time = time.time()
        cursor.execute(sql, val)
        end_time = time.time()
        log_query_performance(request.path, 'insert_cat', (end_time - start_time) * 1000)
        new_cat_id = cursor.lastrowid

        start_time = time.time()
        cursor.execute("SELECT * FROM cats WHERE catId = %s", (new_cat_id,))
        new_cat = cursor.fetchone()
        end_time = time.time()
        log_query_performance(request.path, 'get_new_cat', (end_time - start_time) * 1000)

        conn.commit()
        return jsonify(new_cat), 201
    except (Error, Exception) as e:
        print(f"Create Cat Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/cats/<int:cat_id>', methods=['PUT'])
def update_cat(cat_id):
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"status": "error", "message": "Invalid JSON"}), 400
        cursor = conn.cursor()
        sql = """UPDATE cats SET name=%s, breed=%s, gender=%s, age=%s, img_path=%s
                 WHERE catId = %s"""
        img = data.get('img_path')
        val = (data['name'], data['breed'], data['gender'], data['age'], img, cat_id)
        start_time = time.time()
        cursor.execute(sql, val)
        end_time = time.time()
        log_query_performance(request.path, 'update_cat', (end_time - start_time) * 1000)
        conn.commit()
        return jsonify({"status": "success", "message": f"Cat {cat_id} updated"}), 200
    except (Error, Exception) as e:
        print(f"Update Cat Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/cats/<int:cat_id>', methods=['DELETE'])
def delete_cat(cat_id):
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        cursor = conn.cursor()
        sql = "DELETE FROM cats WHERE catId = %s"
        start_time = time.time()
        cursor.execute(sql, (cat_id,))
        end_time = time.time()
        log_query_performance(request.path, 'delete_cat', (end_time - start_time) * 1000)
        conn.commit()
        return jsonify({"status": "success", "message": f"Cat {cat_id} deleted"}), 200
    except Error as e:
        print(f"Delete Cat Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/history/<int:cat_id>', methods=['GET'])
def get_history_for_cat(cat_id):
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        cursor = conn.cursor(dictionary=True)
        sql = """
            SELECT h.*, h.hist_time as translation_datetime, t.imgPath
            FROM history h LEFT JOIN translations t ON h.translationId = t.translationId
            WHERE h.catId = %s ORDER BY h.id DESC
        """
        start_time = time.time()
        cursor.execute(sql, (cat_id,))
        history = cursor.fetchall()
        end_time = time.time()
        log_query_performance(request.path, 'get_cat_history', (end_time - start_time) * 1000)
        for record in history:
            dt_value = record.get('translation_datetime')
            if isinstance(dt_value, datetime):
                record['translation_datetime'] = dt_value.isoformat()
            ht_value = record.get('hist_time')
            if isinstance(ht_value, datetime):
                record['hist_time'] = ht_value.isoformat()

        return jsonify(history), 200
    except Error as e:
        print(f"Get History Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/history/user/<int:user_id>', methods=['GET'])
def get_history_for_user(user_id):
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        cursor = conn.cursor(dictionary=True)

        # First, get all cat IDs for the given user
        start_time = time.time()
        cursor.execute("SELECT catId FROM cats WHERE userId = %s", (user_id,))
        cats = cursor.fetchall()
        end_time = time.time()
        log_query_performance(request.path, 'get_user_cat_ids', (end_time - start_time) * 1000)
        if not cats:
            return jsonify([]), 200  # No cats for this user, so no history

        cat_ids = [cat['catId'] for cat in cats]
        
        # Create placeholders for the IN clause
        placeholders = ','.join(['%s'] * len(cat_ids))

        # Now, get history for those cat IDs
        sql = f"""
            SELECT h.*, h.hist_time as translation_datetime, t.imgPath, c.name as catName
            FROM history h 
            JOIN cats c ON h.catId = c.catId
            LEFT JOIN translations t ON h.translationId = t.translationId
            WHERE h.catId IN ({placeholders})
            ORDER BY h.id DESC
        """
        start_time = time.time()
        cursor.execute(sql, cat_ids)
        history = cursor.fetchall()
        end_time = time.time()
        log_query_performance(request.path, 'get_user_history_by_cat_ids', (end_time - start_time) * 1000)
        for record in history:
            dt_value = record.get('translation_datetime')
            if isinstance(dt_value, datetime):
                record['translation_datetime'] = dt_value.isoformat()
            ht_value = record.get('hist_time')
            if isinstance(ht_value, datetime):
                record['hist_time'] = ht_value.isoformat()

        return jsonify(history), 200
    except Error as e:
        print(f"Get User History Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/history', methods=['POST'])
def upsert_history():
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"status": "error", "message": "Invalid JSON"}), 400

        cursor = conn.cursor()
        translation_id = data.get('translationId')
        sql = """INSERT INTO history (textTranslation, translationId, catId) 
                 VALUES ( %s, %s, %s)"""
        val = (data['textTranslation'], int(translation_id) if translation_id else None, int(data['catId']))
        start_time = time.time()
        cursor.execute(sql, val)
        end_time = time.time()
        log_query_performance(request.path, 'insert_history', (end_time - start_time) * 1000)
        conn.commit()
        return jsonify({"status": "success"}), 200
    except (Error, Exception) as e:
        print(f"Upsert History Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/convert', methods=['POST'])
def convert():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    cursor = None
    try:
        file.seek(0, os.SEEK_END)
        file_length = file.tell()
        file.seek(0)
        if file_length == 0:
            print("Error: Received empty audio file.")
            return jsonify({'error': 'Empty audio file received'}), 400

        unique_id = datetime.now().strftime('%Y%m%d%H%M%S%f')
        spectrogram_path = os.path.join(SPECTROGRAM_DIR, f"{unique_id}.png")

        spectrogram_bytes = create_spectrogram(file, output_path=spectrogram_path)
        if not spectrogram_bytes:
            return jsonify({'error': 'Audio conversion failed. Check server console.'}), 500

        img = Image.open(io.BytesIO(spectrogram_bytes)).convert('RGB')
        img_t = transform(img).unsqueeze(0).to(device)

        with torch.no_grad():
            out = model(img_t)
            probs = torch.nn.functional.softmax(out, dim=1)
            conf, pred = torch.max(probs, 1)
            

        idx = pred.item()
        confidence = conf.item() * 100
        label = class_names[idx] if class_names and idx < len(class_names) else str(idx)

        b64_spectrogram = base64.b64encode(spectrogram_bytes).decode('utf-8')

        print(f"Label: {label}, Confidence: {confidence}")
        print("Sending JSON response to client...")
        conn = get_db()
        cursor = conn.cursor()
        sql = """INSERT INTO translations (imgPath, className, confidence) 
                    VALUES (%s, %s, %s)"""
        val = (spectrogram_path, label, confidence)
        start_time = time.time()
        cursor.execute(sql, val)
        end_time = time.time()
        log_query_performance(request.path, 'insert_translation', (end_time - start_time) * 1000)
        conn.commit()
        lastrowid = cursor.lastrowid
        
        response = jsonify({
            'label': label,
            'confidence': confidence,
            'spectrogram': b64_spectrogram,
            'imgPath': spectrogram_path,
            'id' : lastrowid
        })
        return response
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/register', methods=['POST'])
def register():
    conn = get_db()

    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data or not all(k in data for k in ['name', 'email', 'password']):
            return jsonify({"status": "error", "message": "Missing required fields"}), 400

        name, email, password = data['name'], data['email'], data['password']

        cursor = conn.cursor()
        start_time = time.time()
        cursor.execute("SELECT email FROM users WHERE email = %s", (email,))
        end_time = time.time()
        log_query_performance(request.path, 'check_user_exists', (end_time - start_time) * 1000)
        if cursor.fetchone():
            return jsonify({"status": "error", "message": "Email already registered"}), 409

        sql = "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)"
        start_time = time.time()
        cursor.execute(sql, (name, email, password))
        end_time = time.time()
        log_query_performance(request.path, 'insert_user', (end_time - start_time) * 1000)
        user_id = cursor.lastrowid
        conn.commit()
        
        user_data = {"userId": user_id, "name": name, "email": email}
        return jsonify({"status": "success", "user": user_data}), 201
    except (Error, Exception) as e:
        print(f"Register Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/login', methods=['POST'])
def login():
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({"status": "error", "message": "Missing email or password"}), 400

        email = data['email']
        password = data['password']

        cursor = conn.cursor(dictionary=True)
        sql = "SELECT userId, name, email, regDate FROM users WHERE (email = %s OR name = %s) AND password = %s"
        start_time = time.time()
        cursor.execute(sql, (email, email, password))
        user = cursor.fetchone()
        end_time = time.time()
        log_query_performance(request.path, 'get_user_on_login', (end_time - start_time) * 1000)
        if user:
            return jsonify({"status": "success", "user": user}), 200
        else:
            return jsonify({"status": "error", "message": "Invalid credentials"}), 401
    except (Error, Exception) as e:
        print(f"Login Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/users/<int:user_id>/stats', methods=['GET'])
def get_user_stats(user_id):
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        cursor = conn.cursor()

        # Get total translations by the user
        start_time = time.time()
        # This is done by counting history entries for all cats owned by the user
        cursor.execute("""
            SELECT COUNT(*) FROM history h
            JOIN cats c ON h.catId = c.catId
            WHERE c.userId = %s
        """, (user_id,))
        translations_count = cursor.fetchone()[0]
        end_time = time.time()
        log_query_performance(request.path, 'get_user_translations_count', (end_time - start_time) * 1000)

        # Get total corrections by the user
        start_time = time.time()
        cursor.execute("SELECT COUNT(*) FROM corrections WHERE user_id = %s", (user_id,))
        corrections_count = cursor.fetchone()[0]
        end_time = time.time()
        log_query_performance(request.path, 'get_user_corrections_count', (end_time - start_time) * 1000)

        return jsonify({"translations": translations_count, "corrections": corrections_count}), 200
    except Error as e:
        print(f"Get User Stats Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()

@app.route('/feedback', methods=['POST'])
def save_feedback():
    conn = get_db()
    if not conn:
        return jsonify({"status": "error", "message": "DB Connection failed"}), 500
    cursor = None
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"status": "error", "message": "Invalid JSON"}), 400

        translation_id = data.get('translationId')
        new_label = data.get('new_label')
        user_id = data.get('userId')

        if not all([translation_id, new_label, user_id]):
            return jsonify({"status": "error", "message": "Missing required fields: translationId, new_label, userId"}), 400

        cursor = conn.cursor(dictionary=True)
        start_time = time.time()
        cursor.execute("SELECT imgPath, className, confidence FROM translations WHERE translationId = %s", (translation_id,))
        translation = cursor.fetchone()
        end_time = time.time()
        log_query_performance(request.path, 'get_translation_for_feedback', (end_time - start_time) * 1000)
        if not translation:
            return jsonify({"status": "error", "message": "Original translation not found"}), 404

        source_path = translation.get('imgPath')
        if not source_path or not os.path.exists(source_path):
            return jsonify({"status": "error", "message": f"Original spectrogram image not found on server at path: {source_path}"}), 404

        source_filename = os.path.basename(source_path)
        destination_path = os.path.join(FEEDBACK_IMAGE_DIR, source_filename)
        
        if os.path.exists(destination_path):
            base, ext = os.path.splitext(source_filename)
            unique_id = datetime.now().strftime('%Y%m%d%H%M%S%f')
            destination_path = os.path.join(FEEDBACK_IMAGE_DIR, f"{base}_{unique_id}{ext}")

        shutil.copy(source_path, destination_path)

        sql = """INSERT INTO corrections (translationId, image_path, old_label, old_conf, new_label, user_id) 
                 VALUES (%s, %s, %s, %s, %s, %s)"""
        
        old_label = translation.get('className')
        old_conf = translation.get('confidence')
        
        start_time = time.time()
        cursor.execute(sql, (translation_id, destination_path, old_label, old_conf, new_label, user_id))
        end_time = time.time()
        log_query_performance(request.path, 'insert_correction', (end_time - start_time) * 1000)
        new_id = cursor.lastrowid
        conn.commit()

        return jsonify({"status": "success", "id": new_id}), 201
    except (Error, Exception) as e:
        print(f"Feedback Error: {e}")
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()


if __name__ == '__main__':
    try:
        # Load the model here, before the app starts
        model = torch.jit.load(MODEL_PATH, map_location=device)
        model.eval()
        print("Model loaded successfully.")

        # Initialize the database connection pool on startup
        get_db_pool()

        # Now that the model is loaded, start the Flask app
        app.run(host='0.0.0.0', port=5000, threaded=True)
    except Exception as e:
        print(f"CRITICAL ERROR: Failed to load model or start the app. {e}")
        sys.exit(1)