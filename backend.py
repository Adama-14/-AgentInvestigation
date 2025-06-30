from flask import Flask, request, jsonify # type: ignore

app = Flask(__name__)

# Stockage temporaire en mémoire (liste)
data_storage = []

@app.route('/upload', methods=['POST'])
def upload():
    content = request.get_json()
    if not content:
        return jsonify({"error": "Pas de données JSON reçues"}), 400
    
    # On ajoute les données reçues dans la liste
    data_storage.append(content)
    
    return jsonify({"message": "Données reçues et stockées !", "total": len(data_storage)}), 200

@app.route('/data', methods=['GET'])
def get_data():
    return jsonify(data_storage)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)

