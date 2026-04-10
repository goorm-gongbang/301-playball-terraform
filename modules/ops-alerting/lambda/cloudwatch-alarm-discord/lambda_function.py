import json
import os
from datetime import datetime, timedelta, timezone
from urllib import request

import boto3


KST = timezone(timedelta(hours=9))
LOGS_DASHBOARD_URLS = {
    "prod": "https://grafana.playball.one/d/cfevec81ezw8wc?var-namespace=prod-webs",
    "staging": "https://grafana.staging.playball.one/d/cfevec81ezw8wc?var-namespace=staging-webs",
    "dev": "https://grafana.goormgb.space/d/cfevec81ezw8wc?var-namespace=dev-webs",
}


def _region():
    return os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "ap-northeast-2"


def _get_secret(secret_name, region):
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def _pick_webhook_key(topic_arn):
    topic_name = topic_arn.rsplit(":", 1)[-1]
    if "critical" in topic_name:
        return os.environ.get("CRITICAL_WEBHOOK_KEY", "criticalWebhookUrl"), 15158332, "🔴", "긴급"
    if "warning" in topic_name:
        return os.environ.get("WARNING_WEBHOOK_KEY", "warningWebhookUrl"), 16753920, "🟡", "경고"
    return os.environ.get("INFO_WEBHOOK_KEY", "infoWebhookUrl"), 3447003, "🔵", "정보"


def _logs_dashboard_url():
    environment = os.environ.get("ENVIRONMENT", "unknown")
    return LOGS_DASHBOARD_URLS.get(environment, LOGS_DASHBOARD_URLS.get("prod", ""))


def _format_kst(raw_time):
    if not raw_time:
        return datetime.now(timezone.utc).astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")
    dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
    return dt.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")


def _build_payload(alarm, level_emoji, level_name, color):
    environment = os.environ.get("ENVIRONMENT", "unknown")
    critical_mention_text = os.environ.get("CRITICAL_MENTION_TEXT", "").strip()
    state = alarm.get("NewStateValue", "UNKNOWN")
    title_state = "복구" if state == "OK" else level_name
    state_emoji = "✅" if state == "OK" else level_emoji

    trigger = alarm.get("Trigger", {}) or {}
    dimensions = trigger.get("Dimensions", []) or []
    dimension_value = ", ".join(d.get("value", "N/A") for d in dimensions) if dimensions else "N/A"

    description = alarm.get("AlarmDescription") or "AWS CloudWatch 알람"
    metric_name = trigger.get("MetricName", "N/A")
    namespace = trigger.get("Namespace", "N/A")

    fields = [
        {"name": "알림", "value": alarm.get("AlarmName", "unknown"), "inline": False},
        {"name": "설명", "value": description[:1024], "inline": False},
        {"name": "메트릭", "value": f"{namespace} / {metric_name}", "inline": False},
        {"name": "대상", "value": dimension_value, "inline": False},
        {"name": "상태", "value": state, "inline": True},
        {"name": "발생(KST)", "value": _format_kst(alarm.get("StateChangeTime")), "inline": True},
    ]

    if level_name == "긴급" and state != "OK":
        fields.append(
            {
                "name": "확인 링크",
                "value": _logs_dashboard_url(),
                "inline": False,
            }
        )

    payload = {
        "username": os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-aws-alert-bot"),
        "embeds": [
            {
                "title": f"[{environment}] {state_emoji} AWS {title_state} 알림 [{datetime.now(KST).strftime('%Y%m%d-%H%M%S')}]",
                "color": 3066993 if state == "OK" else color,
                "fields": fields,
                "footer": {"text": "goormgb AWS CloudWatch Alert"},
            }
        ],
    }
    if level_name == "긴급" and state != "OK" and critical_mention_text:
        payload["content"] = critical_mention_text
    return payload


def _post_to_discord(webhook_url, payload):
    normalized_url = webhook_url.strip()
    if normalized_url.endswith("/slack"):
        normalized_url = normalized_url[: -len("/slack")]

    req = request.Request(
        normalized_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "goormgb-monitoring-bot/1.0",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=5) as response:
        return response.status


def lambda_handler(event, context):
    record = (event.get("Records") or [{}])[0]
    sns = record.get("Sns", {}) or {}
    topic_arn = sns.get("TopicArn", "")
    message = sns.get("Message", "{}")

    try:
        alarm = json.loads(message)
    except json.JSONDecodeError:
        alarm = {"AlarmName": "unknown", "AlarmDescription": message, "NewStateValue": "UNKNOWN"}

    secret_name = os.environ.get("DISCORD_SECRET_NAME", "").strip()
    if not secret_name:
        raise ValueError("DISCORD_SECRET_NAME is empty")

    secret = _get_secret(secret_name, _region())
    webhook_key, color, level_emoji, level_name = _pick_webhook_key(topic_arn)
    webhook_url = (secret.get(webhook_key) or "").strip()
    if not webhook_url:
        raise ValueError(f"Webhook URL is empty for key: {webhook_key}")

    payload = _build_payload(alarm, level_emoji, level_name, color)
    status = _post_to_discord(webhook_url, payload)
    return {"statusCode": 200, "delivery": f"sent:{status}", "alarm": alarm.get("AlarmName", "unknown")}
