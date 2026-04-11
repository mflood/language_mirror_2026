/**
 * TranscriptEditor — inline editing for transcript spans.
 * Each span row has editable text/speaker/timing that saves on blur.
 */
class TranscriptEditor {
    constructor(trackId) {
        this.trackId = trackId;
    }

    async saveField(spanId, field, value) {
        const body = {};
        if (field === 'start_ms' || field === 'end_ms') {
            const ms = Math.round(parseFloat(value) * 1000);
            if (isNaN(ms)) return false;
            body[field] = ms;
        } else {
            body[field] = value;
        }
        const resp = await fetch(`/api/transcript-spans/${spanId}`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(body),
        });
        return resp.ok;
    }

    async addSpan() {
        const resp = await fetch(`/api/tracks/${this.trackId}/transcript-spans`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({start_ms: 0, end_ms: 1000, text: '', speaker: ''}),
        });
        if (resp.ok) window.location.reload();
    }

    async deleteSpan(spanId) {
        if (!confirm('Delete this transcript span?')) return;
        const resp = await fetch(`/api/transcript-spans/${spanId}`, {method: 'DELETE'});
        if (resp.ok) {
            const row = document.getElementById('span-' + spanId);
            if (row) row.remove();
        }
    }

    bindRow(spanId) {
        const row = document.getElementById('span-' + spanId);
        if (!row) return;

        row.querySelectorAll('[data-field]').forEach(el => {
            const field = el.dataset.field;
            el.addEventListener('blur', async () => {
                const ok = await this.saveField(spanId, field, el.value || el.textContent.trim());
                el.classList.toggle('save-ok', ok);
                el.classList.toggle('save-err', !ok);
                setTimeout(() => el.classList.remove('save-ok', 'save-err'), 1000);
            });
            if (el.tagName === 'INPUT') {
                el.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') { e.preventDefault(); el.blur(); }
                });
            }
        });
    }

    bindAll() {
        document.querySelectorAll('.transcript-row[id]').forEach(row => {
            const spanId = row.id.replace('span-', '');
            this.bindRow(spanId);
        });
    }
}
