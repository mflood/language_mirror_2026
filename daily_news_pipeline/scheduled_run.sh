#!/usr/bin/env bash
#
# launchd entry point for the daily news pipeline. Runs run_daily.sh and
# posts a macOS notification with the outcome. Without --commit this is a
# dry-run smoke (stops after step 1, no spend) — the LaunchAgent passes
# --commit.
#
# LaunchAgent: ~/Library/LaunchAgents/com.sixwands.dailynews.plist
#   load:    launchctl load ~/Library/LaunchAgents/com.sixwands.dailynews.plist
#   unload:  launchctl unload ~/Library/LaunchAgents/com.sixwands.dailynews.plist
#   run now: launchctl kickstart gui/$(id -u)/com.sixwands.dailynews

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
DATE=$(TZ=America/New_York date +%Y-%m-%d)

notify() {  # notify <title> <message>
    /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" || true
}

if "$HERE/run_daily.sh" "$@"; then
    COST=$("$HOME/.pyenv/versions/six_wands_language_mirror/bin/python" - <<PYEOF 2>/dev/null || echo "?"
import json, glob
files = sorted(glob.glob("$HERE/cache/cost_history/*/*/${DATE}_*.json"))
print(f"\${json.load(open(files[-1]))['totals']['estimated_cost_usd']:.2f}" if files else "?")
PYEOF
)
    notify "Daily News ✅" "$DATE published (cost $COST)"
else
    notify "Daily News ❌ FAILED" "$DATE — check work/$DATE/run.log"
    # Failure alert email (log tail attached). .env not needed: SES uses ~/.aws.
    "$HOME/.pyenv/versions/six_wands_language_mirror/bin/python" \
        "$HERE/notify_email.py" \
        --subject "❌ Daily News pipeline FAILED — $DATE" \
        --body "The scheduled run failed. Last 40 lines of the run log:" \
        --body-file "$HERE/work/$DATE/run.log" --tail 40 || true
    exit 1
fi
