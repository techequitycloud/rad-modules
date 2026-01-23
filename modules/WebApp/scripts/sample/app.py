import os
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from Sample App! This is a custom built application."

@app.route('/healthz')
def healthz():
    return jsonify({"status": "healthy"}), 200

@app.route('/db')
def db_check():
    db_host = os.environ.get('DB_HOST')
    db_name = os.environ.get('DB_NAME')
    db_user = os.environ.get('DB_USER')
    db_pass = os.environ.get('DB_PASSWORD')
    db_port = os.environ.get('DB_PORT', '5432')

    if not all([db_host, db_name, db_user, db_pass]):
        return jsonify({"error": "Missing database environment variables"}), 500

    try:
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_pass,
            port=db_port
        )
        cur = conn.cursor()
        cur.execute('SELECT version()')
        db_version = cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({"status": "connected", "version": db_version[0]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
