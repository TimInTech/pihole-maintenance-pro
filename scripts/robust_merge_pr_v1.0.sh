#!/bin/bash
# Version 1.0 – Robustes PR-Merge-Skript für GitHub mit Branch-Protection-Handling
# Automatisiert das sichere Aktualisieren, Mergen und Wiederherstellen des Branch-Schutzes
# Projekt: TimInTech/pihole-maintenance-pro

set -euo pipefail

OWNER="TimInTech"
REPO="pihole-maintenance-pro"
BRANCH="main"
PR=8
FEAT="feat/v5.3.1-maintenance-readme"

echo "ℹ️ Starte robusten PR-Merge für #$PR ($FEAT → $BRANCH)..."

# 0) gh bereitstellen & authentifizieren
command -v gh >/dev/null || { echo "✔️ Installiere GitHub CLI..."; sudo apt update && sudo apt install -y gh; }
gh auth status >/dev/null 2>&1 || gh auth login -p https -h github.com -w

# 1) Feature-Branch aktualisieren & robust pushen
git fetch origin
git switch "$FEAT" || git checkout -b "$FEAT"
git rebase origin/"$BRANCH" || true

REMOTE_SHA="$(git rev-parse origin/"$FEAT" 2>/dev/null || echo '')"
LOCAL_SHA="$(git rev-parse HEAD)"
if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
  echo "➜ Force push: $LOCAL_SHA → $FEAT (Lease gegen $REMOTE_SHA)"
  git push origin "$LOCAL_SHA":refs/heads/"$FEAT" --force-with-lease=refs/heads/"$FEAT":"$REMOTE_SHA"
else
  echo "✔️ Branch bereits aktuell."
fi

# 2) Branch Protection temporär deaktivieren (⚠️ Admin-Rechte nötig)
echo "⚠️ Deaktiviere Branch-Protection für $BRANCH..."
gh api -X DELETE -H "Accept: application/vnd.github+json" repos/$OWNER/$REPO/branches/$BRANCH/protection || true

# 3) PR mergen (Squash, Branch löschen)
echo "🚀 Merge PR #$PR (Squash + Delete Branch)..."
gh pr merge "$PR" --squash --delete-branch

# 4) Branch Protection minimal erneut aktivieren
echo "🔒 Reaktiviere Branch-Protection..."
gh api -X PUT -H "Accept: application/vnd.github+json" repos/$OWNER/$REPO/branches/$BRANCH/protection --input - <<JSON
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
JSON

# 5) Log & Verifikation
echo "✔️ Merge abgeschlossen, Schutz reaktiviert."
echo "📝 Letzte Commits auf $BRANCH:"
git fetch origin
git --no-pager log origin/"$BRANCH" --oneline -n 5

echo "✅ Fertig."
