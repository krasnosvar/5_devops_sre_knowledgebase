#!/usr/bin/env bash
# Экспорт/импорт Grafana дашбордов через API (dashboards as code)
set -euo pipefail

GRAFANA="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_AUTH="${GRAFANA_USER:-admin}:${GRAFANA_PASSWORD:-admin}"
# $1 — команда (export/import/annotate), $2 — каталог для export/import
DASHBOARDS_DIR="${2:-./dashboards}"

# ── Экспорт всех дашбордов ────────────────────────────────────────────────────
export_all() {
    mkdir -p "$DASHBOARDS_DIR"
    echo "Exporting dashboards from $GRAFANA..."

    # Получить список всех дашбордов
    curl -sf "$GRAFANA/api/search?type=dash-db&limit=1000" \
        -u "$GRAFANA_AUTH" \
        | jq -r '.[].uid' \
        | while read -r uid; do
            local title
            title=$(curl -sf "$GRAFANA/api/dashboards/uid/$uid" -u "$GRAFANA_AUTH" \
                | jq -r '.dashboard.title' | tr ' /' '-_' | tr -dc 'a-zA-Z0-9_-')
            echo "  Exporting: $title ($uid)"
            curl -sf "$GRAFANA/api/dashboards/uid/$uid" -u "$GRAFANA_AUTH" \
                | jq '.dashboard | del(.id, .version)' \
                > "$DASHBOARDS_DIR/${title}.json"
        done
    echo "Exported to $DASHBOARDS_DIR/"
}

# ── Импорт дашбордов ──────────────────────────────────────────────────────────
import_all() {
    echo "Importing dashboards to $GRAFANA..."
    for f in "$DASHBOARDS_DIR"/*.json; do
        local title
        title=$(jq -r '.title' "$f")
        echo "  Importing: $title"
        curl -sf -X POST "$GRAFANA/api/dashboards/db" \
            -u "$GRAFANA_AUTH" \
            -H "Content-Type: application/json" \
            -d "{\"dashboard\": $(cat "$f"), \"overwrite\": true, \"folderId\": 0}" \
            | jq -r '.status'
    done
}

# ── Добавить deployment аннотацию ─────────────────────────────────────────────
annotate_deploy() {
    local service="${1:?}" version="${2:?}"
    curl -sf -X POST "$GRAFANA/api/annotations" \
        -u "$GRAFANA_AUTH" \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"Deployed $service $version\",
            \"tags\": [\"deploy\", \"$service\"],
            \"time\": $(date +%s)000
        }" | jq '.id'
}

case "${1:-help}" in
    export)  export_all ;;
    import)  import_all ;;
    annotate) annotate_deploy "${2:-}" "${3:-}" ;;
    *) echo "Usage: $0 {export|import|annotate <service> <version>} [dashboards_dir]" ;;
esac
