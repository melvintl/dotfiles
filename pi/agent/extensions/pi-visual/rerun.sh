#!/usr/bin/env bash
# Re-run the original test prompts through headless pi and build a side-by-side
# page: the oldest existing page for each prompt (left) against a fresh render
# with the current skill (right).
#
# Usage: rerun.sh [-j jobs] [filter]
#   -j jobs  prompts to run at once (default 3)
#   filter   only run prompts whose key contains this text (e.g. "thrones")
set -euo pipefail

DIR="${PI_VISUAL_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/visuals}"
JOBS=3
while getopts "j:" opt; do
	case $opt in
	j) JOBS=$OPTARG ;;
	*) exit 2 ;;
	esac
done
shift $((OPTIND - 1))
FILTER="${1:-}"

# key | glob matching the old page | prompt. An empty glob means no page is expected.
CASES=(
	"binary-search|*-binary-search-step-by-step.html|Visualise how binary search narrows the range, step by step"
	"multiplexers|*-terminal-multiplexing-compared.html|Compare tmux, zellij and wezterm multiplexing on 4 criteria"
	"compound-interest|*-compound-interest-playground.html|Let me play with compound interest: principal, rate and years as sliders"
	"dna-helix|*-dna-double-helix.html|Show a rotating 3D model of a DNA helix I can orbit"
	"smartphones|*-smartphone-market-share-2015-2024.html|Chart global smartphone market share by vendor from 2015 to 2024"
	"dns|*-from-url-to-ip.html|Show how DNS resolution works from typing a URL to getting an IP"
	"oauth|*-oauth-2-0-code-flow.html|Draw the OAuth 2.0 authorization code flow between browser, app and auth server"
	"kubernetes|*-kubernetes-object-map.html|Map how the main Kubernetes objects relate to each other: pods, deployments, services, ingress, configmaps, secrets, nodes"
	"greek-gods|*-greek-gods-family-map.html|Map the relationships between the main Greek gods: parents, siblings, spouses"
	"aws|*-aws-web-app-architecture.html|Visualise how the main AWS services connect in a typical web app architecture"
	"thrones|*-game-of-thrones-alliances.html|Map the key characters in Game of Thrones and their alliances"
	"no-page|  |What year was Git released?"
)

STAMP=$(date +%Y%m%d-%H%M%S)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pi-visual-rerun.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

oldest() { # oldest page matching a glob, or nothing
	[[ -z "${1// /}" ]] && return 0
	(cd "$DIR" && ls -1 $1 2>/dev/null | sort | head -1) || true
}

run_case() { # key prompt -> writes the new page name (or nothing) to $WORK/<key>
	local key=$1 prompt=$2 out
	echo "running  $key"
	out=$(pi -p --no-session --tools render_ui,read "$prompt" 2>&1 || true)
	printf '%s\n' "$out" >"$WORK/$key.log"
	# Matches both the URL and the file path render_ui prints when its server is down.
	grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-[a-z0-9-]+\.html' <<<"$out" | tail -1 >"$WORK/$key" || true
	echo "done     $key -> $(cat "$WORK/$key")"
}

selected=()
for c in "${CASES[@]}"; do
	[[ -z "$FILTER" || "${c%%|*}" == *"$FILTER"* ]] && selected+=("$c")
done
((${#selected[@]})) || { echo "no case matches '$FILTER'" >&2; exit 1; }

# Run in batches of $JOBS (macOS bash 3.2 has no `wait -n`).
n=0
for c in "${selected[@]}"; do
	IFS='|' read -r key _ prompt <<<"$c"
	run_case "$key" "$prompt" &
	((++n % JOBS == 0)) && wait
done
wait

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<<"$1"; }

frame() { # label file
	if [[ -n "$2" && -f "$DIR/$2" ]]; then
		printf '<div><div class="cap">%s · <a href="%s" target="_blank">open</a> <small>%s</small></div><iframe src="%s" loading="lazy"></iframe></div>' "$1" "$2" "$2" "$2"
	else
		printf '<div><div class="cap">%s</div><div class="none">no page</div></div>' "$1"
	fi
}

PAGE="compare-$STAMP.html"
{
	cat <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rerun comparison</title>
<style>
:root { color-scheme: dark; --bg: #282c34; --panel: #30343c; --line: #3e4451; --fg: #abb2bf; --strong: #dcdfe4; --muted: #5c6370; --blue: #61afef; }
body { margin: 0; padding: 24px 32px; background: var(--bg); color: var(--fg); font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
h1 { color: var(--strong); font-size: 1.3rem; margin: 0 0 4px; }
section { border-top: 1px solid var(--line); padding: 16px 0 24px; }
h2 { color: var(--strong); font-size: 1rem; margin: 0 0 10px; }
.pair { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
body.stacked .pair { grid-template-columns: 1fr; }
.cap { color: var(--muted); font-size: .85rem; margin-bottom: 6px; }
.cap small { opacity: .7; }
a { color: var(--blue); }
iframe { width: 100%; height: 720px; border: 1px solid var(--line); border-radius: 8px; background: var(--bg); }
.none { height: 120px; display: grid; place-items: center; border: 1px dashed var(--line); border-radius: 8px; color: var(--muted); }
button { font: inherit; color: var(--strong); background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 6px 12px; cursor: pointer; }
</style>
</head>
<body>
<h1>Rerun comparison</h1>
<p>Left: the oldest existing page for each prompt. Right: a fresh render with the current skill.
<button onclick="document.body.classList.toggle('stacked')">Toggle side by side / stacked</button>
Stacked shows each page at full laptop width.</p>
EOF
	for c in "${selected[@]}"; do
		IFS='|' read -r key glob prompt <<<"$c"
		printf '<section><h2>%s</h2><div class="pair">%s%s</div></section>\n' \
			"$(esc "$prompt")" "$(frame before "$(oldest "$glob")")" "$(frame after "$(cat "$WORK/$key")")"
	done
	echo '</body></html>'
} >"$DIR/$PAGE"

echo
echo "comparison: $DIR/$PAGE"
if curl -fsI "http://127.0.0.1:${PI_VISUAL_PORT:-4178}/" >/dev/null 2>&1; then
	open "http://localhost:${PI_VISUAL_PORT:-4178}/$PAGE"
else
	open "$DIR/$PAGE"
fi
