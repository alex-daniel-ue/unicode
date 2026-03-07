import os
import random

import flask
from google import genai
from dotenv import load_dotenv

load_dotenv()
app = flask.Flask(__name__)

keys_string = os.environ.get("GEMINI_API_KEYS", "")
API_KEYS = [key.strip() for key in keys_string.split(",") if key.strip()]

@app.route('/api/ask', methods=['POST'])
def ask():
    data = flask.request.get_json()
    if not data:
        return flask.jsonify({"reply": "Invalid JSON payload"}), 400
    
    client = genai.Client(api_key=random.choice(API_KEYS))
    
    try:
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=data.get("contents", []),
            config=genai.types.GenerateContentConfig(
                system_instruction=data.get("system_instruction")
            ) if data.get("system_instruction") else None
        )

        return flask.jsonify({"reply": response.text})
    except Exception as e:
        print("Error communicating with Gemini:", e)
        return flask.jsonify({"reply": "Sorry, I had trouble analyzing the level."}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3000))
    app.run(host='0.0.0.0', port=port)