import json
import os
from datetime import datetime, timedelta, timezone
from urllib import request

import boto3


KST = timezone(timedelta(hours=9))
secretsmanager = boto3.client("secretsmanager")


def _post_to_discord(webhook_url, username, payload):
    req = request.Request(
        webhook_url.strip(),
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "goormgb-secret-change-bot/1.0",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=5) as response:
        return response.status


def _format_kst(raw_time):
    if not raw_time:
        return datetime.now(timezone.utc).astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")
    dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
    return dt.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")


def _mask_value(value, tail=3):
    """Show only last N characters, mask the rest with *."""
    s = str(value)
    if len(s) <= tail:
        return s
    return "*" * min(8, len(s) - tail) + s[-tail:]


def _format_secret_diff(secret_id):
    """Read current secret value and return masked key-value lines."""
    try:
        resp = secretsmanager.get_secret_value(SecretId=secret_id)
        raw = resp.get("SecretString", "")
    except Exception as e:
        return f"(읽기 실패: {e})"

    # JSON secret
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            lines = []
            for k, v in data.items():
                lines.append(f"`{k}`: `{_mask_value(v)}`")
            return "\n".join(lines)
    except (json.JSONDecodeError, TypeError):
        pass

    # Plain string secret
    return f"`(plain)`: `{_mask_value(raw)}`"


def _user_identity(detail):
    user = detail.get("userIdentity", {}) or {}
    arn = user.get("arn", "")
    # Extract readable name from ARN
    if arn:
        # arn:aws:iam::123:user/name -> name
        # arn:aws:sts::123:assumed-role/role/session -> role/session
        parts = arn.split("/")
        if len(parts) >= 2:
            return "/".join(parts[-2:]) if "assumed-role" in arn else parts[-1]
    return user.get("principalId") or user.get("type") or "unknown"


def _resolve_webhook(secret_name):
    """Route to the correct Discord webhook based on secret name prefix."""
    staging_webhook = os.environ.get("STAGING_DISCORD_WEBHOOK_URL", "").strip()
    dev_webhook = os.environ.get("DEV_DISCORD_WEBHOOK_URL", "").strip()

    if secret_name.startswith("prod/"):
        # prod uses staging channel for now (same infra team)
        return staging_webhook
    if secret_name.startswith("staging/"):
        return staging_webhook
    if secret_name.startswith("dev/"):
        return dev_webhook

    # Fallback: staging
    return staging_webhook


def _event_action_label(event_name):
    return {
        "PutSecretValue": "값 변경",
        "UpdateSecret": "설정 변경",
        "CreateSecret": "신규 생성",
        "DeleteSecret": "삭제",
        "RestoreSecret": "복원",
    }.get(event_name, event_name)


def lambda_handler(event, context):
    username = os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-secret-bot").strip()

    detail = event.get("detail", {}) or {}
    event_name = detail.get("eventName", "unknown")
    event_time = event.get("time")
    actor = _user_identity(detail)

    request_parameters = detail.get("requestParameters", {}) or {}
    secret_id = request_parameters.get("secretId", "unknown")

    # Ignore rotation or internal events
    invoking_service = (detail.get("userIdentity", {}) or {}).get("invokedBy", "")
    if invoking_service == "secretsmanager.amazonaws.com":
        return {"statusCode": 200, "delivery": "ignored", "reason": "rotation"}

    webhook_url = _resolve_webhook(secret_id)
    if not webhook_url:
        print(f"No webhook URL for secret: {secret_id}")
        return {"statusCode": 200, "delivery": "skipped"}

    action_label = _event_action_label(event_name)
    action_emoji = {
        "PutSecretValue": "\U0001f510",
        "UpdateSecret": "\u2699\ufe0f",
        "CreateSecret": "\u2728",
        "DeleteSecret": "\U0001f5d1\ufe0f",
        "RestoreSecret": "\u267b\ufe0f",
    }.get(event_name, "\U0001f510")

    # Build value preview (only for create/update)
    value_section = ""
    if event_name in {"PutSecretValue", "CreateSecret"}:
        value_section = _format_secret_diff(secret_id)

    description_parts = [
        f"**{action_emoji} Secret {action_label}**: `{secret_id}`",
        f"\U0001f464 **변경자**: `{actor}`",
        f"\u23f0 **시각**: `{_format_kst(event_time)}`",
    ]

    if value_section:
        description_parts.append(f"\n**변경된 값 (끝 3자리)**\n{value_section}")

    payload = {
        "username": username,
        "embeds": [
            {
                "title": f"{action_emoji} Secret {action_label}",
                "description": "\n".join(description_parts),
                "color": {
                    "PutSecretValue": 16750848,  # orange
                    "UpdateSecret": 3447003,     # blue
                    "CreateSecret": 3066993,     # green
                    "DeleteSecret": 15158332,    # red
                    "RestoreSecret": 10181046,   # purple
                }.get(event_name, 16750848),
                "footer": {"text": "goormgb Secret Change Monitor"},
            }
        ],
    }

    status = _post_to_discord(webhook_url, username, payload)
    return {"statusCode": 200, "delivery": f"sent:{status}", "secret": secret_id, "action": event_name}
