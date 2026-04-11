# Meow Lang Admin Panel

A Flask and React application to monitor and manage the Meow Lang server and models.

## Backend Setup (Flask)

1.  Navigate to the `backend` directory:
    ```sh
    cd backend
    ```

2.  Create a virtual environment and activate it:
    ```sh
    python -m venv venv
    .\venv\Scripts\activate
    ```

3.  Install the required dependencies:
    ```sh
    pip install -r requirements.txt
    ```

4.  Run the Flask server:
    ```sh
    flask run --port 8000
    ```
    The backend will be running at `http://127.0.0.1:8000`.

## Frontend Setup (React)

1.  Navigate to the `frontend` directory:
    ```sh
    cd frontend
    ```

2.  Install the required dependencies:
    ```sh
    npm install
    ```

3.  Run the React development server:
    ```sh
    npm start
    ```
    The frontend will open and run at `http://localhost:3000`. It will automatically connect to the Flask backend.