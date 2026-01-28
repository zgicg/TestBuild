#!/usr/bin/env bash
set -euo pipefail

status="${1:-}"

if [[ -z "${DINGTALK_WEBHOOK_URL:-}" ]] || [[ -z "${DINGTALK_SECRET:-}" ]]; then
  echo "DingTalk secrets not set, skip."
  exit 0
fi

if [[ "${status}" != "success" && "${status}" != "failure" ]]; then
  echo "Usage: dingtalk-notify.sh <success|failure>"
  exit 1
fi

timestamp=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)

export DINGTALK_TIMESTAMP="${timestamp}"
sign=$(python3 - <<'PY'
import base64
import hmac
import hashlib
import os
import urllib.parse
timestamp = os.environ['DINGTALK_TIMESTAMP']
secret = os.environ['DINGTALK_SECRET']
sign_str = f"{timestamp}\n{secret}"
signature = hmac.new(secret.encode('utf-8'), sign_str.encode('utf-8'), hashlib.sha256).digest()
print(urllib.parse.quote(base64.b64encode(signature)))
PY
)

if [[ "${DINGTALK_WEBHOOK_URL}" == *"?"* ]]; then
  url="${DINGTALK_WEBHOOK_URL}&timestamp=${timestamp}&sign=${sign}"
else
  url="${DINGTALK_WEBHOOK_URL}?timestamp=${timestamp}&sign=${sign}"
fi

now="$(date '+%Y-%m-%d %H:%M:%S')"
if [[ "${status}" == "success" ]]; then
  payload=$(cat <<EOF
{"msgtype":"markdown","markdown":{"title":"打包成功","text":"### 打包成功\\n- 仓库：${GITHUB_REPOSITORY}\\n- Tag：${GITHUB_REF_NAME}\\n- 触发：${GITHUB_WORKFLOW}\\n- 时间：${now}"}}
EOF
)
else
  payload=$(cat <<EOF
{"msgtype":"markdown","markdown":{"title":"打包失败","text":"### 打包失败\\n- 仓库：${GITHUB_REPOSITORY}\\n- Tag：${GITHUB_REF_NAME}\\n- 触发：${GITHUB_WORKFLOW}\\n- 时间：${now}\\n- 日志：https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"}}
EOF
)
fi

curl -sS -X POST -H 'Content-Type: application/json' -d "${payload}" "${url}" || true
