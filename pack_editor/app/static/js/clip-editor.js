/**
 * ClipEditor — inline editing for practice clips.
 * Each clip row has editable fields that save on blur via PUT /api/clips/{id}.
 */
class ClipEditor {
    constructor(trackId) {
        this.trackId = trackId;
    }

    async saveField(clipId, field, value) {
        const body = {};
        if (field === 'start_ms' || field === 'end_ms') {
            const ms = Math.round(parseFloat(value) * 1000);
            if (isNaN(ms)) return false;
            body[field] = ms;
        } else {
            body[field] = value;
        }
        const resp = await fetch(`/api/clips/${clipId}`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(body),
        });
        return resp.ok;
    }

    async addClip() {
        const resp = await fetch(`/api/tracks/${this.trackId}/clips`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({start_ms: 0, end_ms: 1000, kind: 'drill', title: 'New clip'}),
        });
        if (resp.ok) window.location.reload();
    }

    async deleteClip(clipId) {
        if (!confirm('Delete this clip?')) return;
        const resp = await fetch(`/api/clips/${clipId}`, {method: 'DELETE'});
        if (resp.ok) {
            const row = document.getElementById('clip-' + clipId);
            if (row) row.remove();
        }
    }

    bindRow(clipId) {
        const row = document.getElementById('clip-' + clipId);
        if (!row) return;

        row.querySelectorAll('[data-field]').forEach(el => {
            const field = el.dataset.field;

            if (el.tagName === 'SELECT') {
                el.addEventListener('change', async () => {
                    const ok = await this.saveField(clipId, field, el.value);
                    el.classList.toggle('save-ok', ok);
                    el.classList.toggle('save-err', !ok);
                    setTimeout(() => el.classList.remove('save-ok', 'save-err'), 1000);
                });
            } else {
                el.addEventListener('blur', async () => {
                    const ok = await this.saveField(clipId, field, el.value);
                    el.classList.toggle('save-ok', ok);
                    el.classList.toggle('save-err', !ok);
                    setTimeout(() => el.classList.remove('save-ok', 'save-err'), 1000);
                });
                el.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') { e.preventDefault(); el.blur(); }
                });
            }
        });
    }

    bindAll() {
        document.querySelectorAll('.clip-row[id]').forEach(row => {
            const clipId = row.id.replace('clip-', '');
            this.bindRow(clipId);
        });
    }
}
