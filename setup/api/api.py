import sqlite3, os
from flask import Flask, request, jsonify

app = Flask(__name__)
# DB = os.environ.get("DB_PATH", "/srv/config/app.db")


@app.route("/api/health")
def health():
    return jsonify({"healthy": True})


# @app.route("/api/progress")
# def progress():
#     book_id = request.args.get("book_id")
#     if not book_id:
#         return jsonify({"error":"book_id required"}),400
#     conn = sqlite3.connect(DB)
#     cur = conn.cursor()
#     # Adapt this query to your actual Calibre-Web schema
#     cur.execute("SELECT id FROM books WHERE id=?", (book_id,))
#     row = cur.fetchone()
#     conn.close()
#     return jsonify({"found": bool(row)})
