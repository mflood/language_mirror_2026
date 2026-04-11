/**
 * AudioPreview — loads audio from presigned S3 URL and supports
 * full playback + range-based clip preview.
 */
class AudioPreview {
    constructor(trackId) {
        this.trackId = trackId;
        this.audio = document.getElementById("audio-player");
        this.statusEl = document.getElementById("audio-status");
        this.loaded = false;
        this._rangeEnd = null;
        this._onTimeUpdate = this._onTimeUpdate.bind(this);
        this.audio.addEventListener("timeupdate", this._onTimeUpdate);
    }

    async loadAudio() {
        if (this.loaded) return;
        this.statusEl.textContent = "Loading...";
        try {
            const resp = await fetch(`/api/tracks/${this.trackId}/audio-url`);
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const data = await resp.json();
            this.audio.src = data.url;
            this.audio.load();
            this.loaded = true;
            this.statusEl.textContent = `Ready — ${data.filename}`;
        } catch (err) {
            this.statusEl.textContent = `Error: ${err.message}`;
        }
    }

    /**
     * Play a specific time range [startMs, endMs).
     * Auto-pauses when endMs is reached.
     */
    async playRange(startMs, endMs) {
        if (!this.loaded) await this.loadAudio();
        this._rangeEnd = endMs / 1000;
        this.audio.currentTime = startMs / 1000;
        this.audio.play();
    }

    /**
     * Play from a specific time in ms.
     */
    async playFrom(startMs) {
        if (!this.loaded) await this.loadAudio();
        this._rangeEnd = null;
        this.audio.currentTime = startMs / 1000;
        this.audio.play();
    }

    stop() {
        this.audio.pause();
        this._rangeEnd = null;
    }

    _onTimeUpdate() {
        if (this._rangeEnd !== null && this.audio.currentTime >= this._rangeEnd) {
            this.audio.pause();
            this._rangeEnd = null;
            // Dispatch event so UI can unhighlight
            document.dispatchEvent(new CustomEvent("clipPlaybackEnded"));
        }
    }
}
