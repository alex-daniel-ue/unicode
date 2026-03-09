## Prerequisites
- **Python:** Version 3.12 or higher.
- **Package Manager:** [uv](https://docs.astral.sh/uv/) (recommended, as a `uv.lock` file is included).

## Setup & Installation

1. **Clone the repository** (or download the files).

2. **Install dependencies**:
   If you have `uv` installed, simply run:
   ```bash
   uv sync
   ```
   *(Alternatively, you can create a virtual environment manually and run `pip install .`)*

3. **Configure Environment Variables**:
   Create a `.env` file in the root directory (replacing the empty one) and add your Google Gemini API key(s). Separate multiple keys with a comma.
   ```env
   GEMINI_API_KEYS=your_first_api_key_here,your_second_api_key_here
   PORT=3000
   ```

## Running the Application

**On Windows:**
- Simply double-click **`start.bat`**. This script automatically activates the virtual environment and starts the server.
- Need a terminal with the environment loaded? Double-click **`venv_cmd.bat`**.

The server will start on `http://0.0.0.0:3000` (or the port specified in your `.env` file).
