import os
import random

import flask
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()
app = flask.Flask(__name__)

keys_string = os.environ.get("GEMINI_API_KEYS", "")
API_KEYS = [key.strip() for key in keys_string.split(",") if key.strip()]

clients = [genai.Client(api_key=key) for key in API_KEYS]

SAFETY_SETTINGS =[
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_HARASSMENT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
]

@app.route('/api/ask', methods=['POST'])
def ask():
    data = flask.request.get_json()
    if not data:
        return flask.jsonify({"error": "Invalid JSON payload"}), 400

    client = random.choice(clients)

    try:
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=data.get("contents",[]),
            config=types.GenerateContentConfig(
                system_instruction=data.get("system_instruction"),
                safety_settings=SAFETY_SETTINGS,
            )
        )

        return flask.jsonify(response.model_dump(mode="json", exclude_none=True))

    except Exception as e:
        print("Error communicating with Gemini:", e)
        return flask.jsonify({"error": "Sorry, I had trouble analyzing the level."}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3000))
    app.run(host='0.0.0.0', port=port)