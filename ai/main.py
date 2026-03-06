import base64
import io
import os
import random

import dotenv
import flask
import google.genai as genai
import PIL as pillow

dotenv.load_dotenv()

app = flask.Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024  # 10MB

keys_string = os.environ.get("GEMINI_API_KEYS", "")
API_KEYS = [key.strip() for key in keys_string.split(",") if key.strip()]

if not API_KEYS:
    print("WARNING: No GEMINI_API_KEYS found in environment variables!")


@app.route('/api/ask', methods=['POST'])
def ask():
    try:
        data = flask.request.get_json()
        if not data:
            return flask.jsonify({"reply": "Invalid JSON payload"}), 400
        
        client = genai.Client(api_key=random.choice(API_KEYS))

        user_message = data.get("user_message", "")
        game_context = data.get("game_context", "No blocks on the canvas.")
        level_instructions = data.get("level_instructions", "No instructions.")
        intended_solution = data.get("intended_solution", "Unknown.")
        block_docs = data.get("block_docs", "No block documentation provided.")
        level_image_b64 = data.get("level_image", "")

        raw_history = data.get("history", [])

        system_instruction = f"""
        You are a friendly, concise AI assistant in an educational visual block-based programming game.
        
        --- GAME RULES & BLOCK DOCUMENTATION ---
        {block_docs}
        
        --- CURRENT LEVEL INFO ---
        Instructions given to player: {level_instructions}
        Intended Solution (FOR YOUR EYES ONLY - DO NOT REVEAL DIRECTLY): {intended_solution}
        
        --- YOUR GOAL ---
        The player is trying to solve the puzzle. You will receive an image of the level layout and their current workspace YAML.
        Compare their YAML code to the intended solution and the visual layout.
        Guide them, give hints, and point out logical errors. Do NOT give them the exact code solution.
        """

        formatted_history = []
        for msg in raw_history:
            formatted_history.append(
                genai.types.Content(
                    role=msg.get("role", "user"),
                    parts=[genai.types.Part.from_text(text=msg.get("text", ""))],
                )
            )

        prompt_parts = [
            genai.types.Part.from_text(
                text=f"--- CURRENT PLAYER WORKSPACE (YAML) ---\n{game_context}\n\nPlayer says: {user_message}"
            )
        ]

        if level_image_b64:
            image_bytes = base64.b64decode(level_image_b64)
            img = pillow.Image.open(io.BytesIO(image_bytes))
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            prompt_parts.append(
                genai.types.Part.from_bytes(data=buf.read(), mime_type="image/png")
            )

        chat = client.chats.create(
            model="gemini-3.1-flash-lite-preview",
            config=genai.types.GenerateContentConfig(
                system_instruction=system_instruction,
            ),
            history=formatted_history,
        )

        response = chat.send_message(prompt_parts)

        return flask.jsonify({"reply": response.text})

    except Exception as e:
        print("Error communicating with Gemini:", e)
        return flask.jsonify({"reply": "Sorry, I had trouble analyzing the level."}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3000))
    app.run(host='0.0.0.0', port=port)