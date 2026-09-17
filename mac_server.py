import os
import subprocess
import threading
import uuid

from flask import Flask, jsonify, render_template_string, request, send_from_directory

app = Flask(__name__)

# Where finished mp3s live on the Mac. Change this if you'd rather use
# an iCloud Drive folder so it also syncs without any networking at all.
DOWNLOAD_DIR = os.path.expanduser("~/Music/ytmp3_downloads")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# In-memory job tracker: job_id -> {"status", "filename", "error"}
# Fine for a personal single-user tool; not meant to survive a restart.
jobs = {}


def download_audio(job_id: str, url: str) -> None:
    jobs[job_id]["status"] = "downloading"
    try:
        output_template = os.path.join(DOWNLOAD_DIR, "%(title).150s.%(ext)s")
        cmd = [
            "yt-dlp",
            "-x", "--audio-format", "mp3", "--audio-quality", "0",
            "-o", output_template,
            url,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)

        if result.returncode != 0:
            jobs[job_id]["status"] = "error"
            jobs[job_id]["error"] = result.stderr[-500:]
            return

        mp3_files = [f for f in os.listdir(DOWNLOAD_DIR) if f.endswith(".mp3")]
        mp3_files.sort(key=lambda f: os.path.getmtime(os.path.join(DOWNLOAD_DIR, f)))
        newest = mp3_files[-1]

        jobs[job_id]["status"] = "done"
        jobs[job_id]["filename"] = newest
    except Exception as e:
        jobs[job_id]["status"] = "error"
        jobs[job_id]["error"] = str(e)


@app.route("/", methods=["GET"])
def index():
    return render_template_string(HTML_PAGE)


@app.route("/download", methods=["POST"])
def start_download():
    data = request.get_json(silent=True) or request.form
    url = (data.get("url") or "").strip()
    if not url:
        return jsonify({"error": "no url provided"}), 400

    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "pending", "filename": None, "error": None}
    threading.Thread(target=download_audio, args=(job_id, url), daemon=True).start()
    return jsonify({"job_id": job_id})


@app.route("/status/<job_id>", methods=["GET"])
def check_status(job_id):
    job = jobs.get(job_id)
    if not job:
        return jsonify({"error": "unknown job id"}), 404
    return jsonify(job)


@app.route("/library", methods=["GET"])
def list_library():
    # This is what the iPhone app will eventually poll to see what's
    # available to download.
    files = sorted(f for f in os.listdir(DOWNLOAD_DIR) if f.endswith(".mp3"))
    return jsonify(files)


@app.route("/files/<path:filename>", methods=["GET"])
def get_file(filename):
    return send_from_directory(DOWNLOAD_DIR, filename, as_attachment=True)


HTML_PAGE = """
<!doctype html>
<title>YT to MP3</title>
<h2>Paste a YouTube link</h2>
<form id="f">
  <input type="text" id="url" placeholder="https://youtube.com/..." style="width:400px">
  <button type="submit">Download</button>
</form>
<pre id="log"></pre>
<script>
const f = document.getElementById('f');
const log = document.getElementById('log');
f.onsubmit = async (e) => {
  e.preventDefault();
  const url = document.getElementById('url').value;
  log.textContent = "starting...";
  const res = await fetch('/download', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({url})
  });
  const {job_id} = await res.json();
  const poll = setInterval(async () => {
    const s = await fetch('/status/' + job_id).then(r => r.json());
    log.textContent = JSON.stringify(s, null, 2);
    if (s.status === 'done' || s.status === 'error') clearInterval(poll);
  }, 1500);
};
</script>
"""

if __name__ == "__main__":
    # host="0.0.0.0" so it's reachable from your phone on the same Wi-Fi,
    # not just from the Mac itself.
    app.run(host="0.0.0.0", port=5005)
