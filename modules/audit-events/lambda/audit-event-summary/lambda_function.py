import json
import os
import uuid
from datetime import datetime, timezone
from urllib import parse
from urllib import error, request

import boto3


s3 = boto3.client("s3")
secretsmanager = boto3.client("secretsmanager")
TEST_MARKERS = ("test/", "test-", "-test", "/test-")
OBSERVABILITY_SUFFIXES = ("-loki", "-tempo", "-thanos")


def _is_test_record(record):
    values = [
        record.get("bucket_name"),
        record.get("object_key"),
        record.get("event_name"),
    ]
    lowered = " ".join(str(value or "").lower() for value in values)
    return any(marker in lowered for marker in TEST_MARKERS)


def _parse_event_time(event):
    raw_time = event.get("time")
    if not raw_time:
        return datetime.now(timezone.utc)

    return datetime.fromisoformat(raw_time.replace("Z", "+00:00"))


def _post_to_discord(webhook_url, username, record):
    severity = record.get("severity", "info")
    prefix = "[TEST] " if _is_test_record(record) else ""
    critical_mention_text = os.environ.get("CRITICAL_MENTION_TEXT", "").strip()
    color = {
        "critical": 15158332,
        "warning": 16753920,
        "info": 3447003,
    }.get(severity, 3447003)
    emoji = {
        "critical": "🔴",
        "warning": "🟡",
        "info": "🔵",
    }.get(severity, "🔵")

    payload = {
        "username": username,
        "embeds": [
            {
                "title": f"{emoji} {prefix}AWS 감사 이벤트 - {record['event_name']}",
                "color": color,
                "fields": [
                    {"name": "버킷", "value": record.get("bucket_name") or "-", "inline": True},
                    {"name": "리전", "value": record.get("aws_region") or "-", "inline": True},
                    {"name": "오브젝트", "value": record.get("object_key") or "-", "inline": False},
                ],
                "footer": {"text": "goormgb AWS Audit Event"},
            }
        ],
    }

    if severity == "critical":
        if critical_mention_text:
            payload["content"] = critical_mention_text
        payload["embeds"][0]["fields"].append(
            {"name": "확인 링크", "value": _build_console_link(record), "inline": False}
        )

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


def _get_secret(secret_name):
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def _classify_severity(record):
    event_name = record.get("event_name")
    bucket_name = record.get("bucket_name")

    if event_name in {"DeleteObject", "DeleteObjects"}:
        if bucket_name and bucket_name.endswith("-audit-logs"):
            return "critical"
        return "warning"

    return "info"


def _is_observability_delete(record):
    event_name = record.get("event_name")
    bucket_name = record.get("bucket_name") or ""
    return event_name in {"DeleteObject", "DeleteObjects"} and bucket_name.endswith(OBSERVABILITY_SUFFIXES)


def _should_notify(record):
    if _is_observability_delete(record):
        return False
    return _classify_severity(record) in {"warning", "critical"}


def _resolve_webhook_url(record):
    secret_name = os.environ.get("DISCORD_SECRET_NAME", "").strip()
    severity = _classify_severity(record)

    if secret_name:
        secret = _get_secret(secret_name)
        key_name = {
            "critical": os.environ.get("CRITICAL_WEBHOOK_KEY", "securityCriticalWebhookUrl"),
            "warning": os.environ.get("WARNING_WEBHOOK_KEY", "securityWarningWebhookUrl"),
            "info": os.environ.get("INFO_WEBHOOK_KEY", "securityInfoWebhookUrl"),
        }[severity]
        return severity, (secret.get(key_name) or "").strip()

    return severity, os.environ.get("DISCORD_WEBHOOK_URL", "").strip()


def _build_console_link(record):
    bucket_name = record.get("bucket_name") or ""
    object_key = record.get("object_key") or ""
    aws_region = record.get("aws_region") or "ap-northeast-2"

    if not bucket_name:
        return f"https://s3.console.aws.amazon.com/s3/home?region={aws_region}"

    return (
        f"https://s3.console.aws.amazon.com/s3/buckets/{parse.quote(str(bucket_name), safe='')}?"
        f"region={aws_region}&prefix={parse.quote(str(object_key), safe='')}"
    )


def lambda_handler(event, context):
    """
    Store normalized S3 audit events into the audit logs bucket.

    This is a skeleton stage:
    - EventBridge routes matching CloudTrail-backed S3 API events here
    - The Lambda stores one normalized JSON record per event under a daily prefix
    - A later phase can add daily rollup generation and Discord notifications
    """

    audit_bucket_name = os.environ["AUDIT_BUCKET_NAME"]
    summary_prefix = os.environ.get("SUMMARY_PREFIX", "lifecycle-expiration-summary").strip("/")

    discord_webhook_username = os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-audit-bot").strip()

    event_time = _parse_event_time(event)
    detail = event.get("detail", {})
    request_parameters = detail.get("requestParameters", {})

    record = {
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "eventbridge_id": event.get("id"),
        "event_time": event.get("time"),
        "source": event.get("source"),
        "detail_type": event.get("detail-type"),
        "bucket_name": request_parameters.get("bucketName"),
        "object_key": request_parameters.get("key"),
        "event_name": detail.get("eventName"),
        "aws_region": detail.get("awsRegion"),
        "user_identity_type": detail.get("userIdentity", {}).get("type"),
        "raw_event": event,
    }

    source_bucket_name = record.get("bucket_name") or ""
    source_object_key = record.get("object_key") or ""
    if source_bucket_name == audit_bucket_name and source_object_key.startswith(f"{summary_prefix}/"):
        return {
            "statusCode": 200,
            "delivery": "ignored:self-generated-summary",
            "bucket": source_bucket_name,
            "object_key": source_object_key,
        }

    record["severity"] = _classify_severity(record)

    object_key = (
        f"{summary_prefix}/year={event_time:%Y}/month={event_time:%m}/day={event_time:%d}/"
        f"{event.get('id') or uuid.uuid4()}.json"
    )

    s3.put_object(
        Bucket=audit_bucket_name,
        Key=object_key,
        Body=json.dumps(record, ensure_ascii=False, indent=2).encode("utf-8"),
        ContentType="application/json",
    )

    severity, discord_webhook_url = _resolve_webhook_url(record)

    discord_delivery = "skipped"
    if _should_notify(record) and discord_webhook_url:
        try:
            status_code = _post_to_discord(discord_webhook_url, discord_webhook_username, record)
            discord_delivery = f"sent:{status_code}"
        except error.URLError as exc:
            print(f"discord webhook delivery failed: {exc}")
            discord_delivery = "failed"

    return {
        "statusCode": 200,
        "bucket": audit_bucket_name,
        "key": object_key,
        "severity": severity,
        "discord_delivery": discord_delivery,
    }
