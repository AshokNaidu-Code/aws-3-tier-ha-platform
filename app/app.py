from flask import Flask, jsonify
import os
import pymysql

app = Flask(__name__)

# RDS Configuration from environment variables
RDS_HOST = os.environ.get('RDS_HOST', 'localhost')
RDS_USER = os.environ.get('RDS_USER', 'admin')
RDS_PASSWORD = os.environ.get('RDS_PASSWORD', 'password')
RDS_DB = os.environ.get('RDS_DB', 'appdb')

@app.route('/')
def home():
    return jsonify({
        "message": "Welcome to 3-Tier HA Architecture",
        "status": "healthy",
        "tier": "application"
    })

@app.route('/health')
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/db-test')
def db_test():
    try:
        connection = pymysql.connect(
            host=RDS_HOST,
            user=RDS_USER,
            password=RDS_PASSWORD,
            database=RDS_DB
        )
        connection.close()
        return jsonify({"database": "connected"}), 200
    except Exception as e:
        return jsonify({"database": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
