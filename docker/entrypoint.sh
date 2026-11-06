#!/bin/sh
set -e

SERVICE="${1:-api}"
VLLM_BASE_URL="${VLLM_BASE_URL:-http://10.0.2.100:8000/v1}"

derive_vllm_api_key() {
	if [ -n "${VLLM_API_KEY:-}" ]; then
		return 0
	fi

	if [ -n "${LOCAL_EXEC_API_KEYS:-}" ]; then
		OLD_IFS="$IFS"
		IFS=,
		set -- $LOCAL_EXEC_API_KEYS
		IFS="$OLD_IFS"

		for pair in "$@"; do
			case "$pair" in
				"$VLLM_BASE_URL="*)
					export VLLM_API_KEY="${pair#*=}"
					return 0
					;;
			esac
		done
	fi

	return 1
}

configure_openai_runtime() {
	derive_vllm_api_key || true

	case "${LLM_OPENAI_API_KEY:-}" in
		""|ollama)
			if [ -n "${VLLM_API_KEY:-}" ]; then
				export LLM_OPENAI_API_KEY="$VLLM_API_KEY"
			fi
			;;
	esac
}

configure_openai_runtime

if [ "$SERVICE" = "api" ]; then
	echo "Running database migrations..."
	/app/.venv/bin/python scripts/provision_db.py

	echo "Starting API server..."
	exec /app/.venv/bin/fastapi run --host 0.0.0.0 --workers "${API_WORKERS:-1}" src/main.py
fi

if [ "$SERVICE" = "deriver" ]; then
	echo "Starting deriver worker..."
	exec /app/.venv/bin/python -m src.deriver
fi

echo "Unknown service: $SERVICE" >&2
exit 1
