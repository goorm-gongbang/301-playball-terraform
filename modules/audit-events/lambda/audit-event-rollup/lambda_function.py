import json
import os
from collections import Counter
from datetime import datetime, timedelta, timezone
from urllib import request

import boto3
from botocore.exceptions import ClientError


s3 = boto3.client("s3")
secretsmanager = boto3.client("secretsmanager")


def _parse_iso8601(value):
    if not value:
        return None
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value)


def _target_window(now):
    end = now.replace(minute=0, second=0, microsecond=0)
    start = end - timedelta(hours=1)
    return start, end


def _list_keys(bucket, prefix):
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            yield obj["Key"]


def _load_record(bucket, key):
    response = s3.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


def _marker_exists(bucket, key):
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") in {"404", "NoSuchKey", "NotFound"}:
            return False
        raise


def _get_secret(secret_name):
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def _normalize_webhook_url(url):
    return url[:-6] if url.endswith("/slack") else url


def _post_to_discord(webhook_url, username, start, end, counts):
    total = sum(counts.values())
    period = f"{start.strftime('%Y-%m-%d %H:%M')}~{end.strftime('%H:%M')} UTC"
    fields = [
        {"name": bucket, "value": f"{count}건", "inline": True}
        for bucket, count in sorted(counts.items())
    ]
    payload = {
        "username": username,
        "embeds": [
            {
                "title": "🔵 AWS 감사 요약 - Observability DeleteObject",
                "color": 3447003,
                "fields": [
                    {"name": "기간", "value": period, "inline": False},
                    {"name": "총 삭제 건수", "value": f"{total}건", "inline": False},
                    *fields,
                ],
                "footer": {"text": "goormgb AWS Audit Event"},
            }
        ],
    }
    req = request.Request(
        _normalize_webhook_url(webhook_url.strip()),
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
    bucket = os.environ["AUDIT_BUCKET_NAME"]
    summary_prefix = os.environ["SUMMARY_PREFIX"].strip("/")
    report_prefix = os.environ["REPORT_PREFIX"].strip("/")
    obs_buckets = {
        item.strip() for item in os.environ.get("OBSERVABILITY_BUCKETS", "").split(",") if item.strip()
    }
    secret_name = os.environ["DISCORD_SECRET_NAME"].strip()
    username = os.environ.get("DISCORD_WEBHOOK_USERNAME", "playball-audit-bot").strip()
    info_key = os.environ.get("INFO_WEBHOOK_KEY", "securityInfoWebhookUrl").strip()

    now = datetime.now(timezone.utc)
    start, end = _target_window(now)
    marker_key = (
        f"{report_prefix}/year={start:%Y}/month={start:%m}/day={start:%d}/hour={start:%H}.json"
    )

    if _marker_exists(bucket, marker_key):
        return {"statusCode": 200, "delivery": "skipped:already-sent", "marker": marker_key}

    date_prefixes = {
        f"{summary_prefix}/year={start:%Y}/month={start:%m}/day={start:%d}/",
        f"{summary_prefix}/year={end:%Y}/month={end:%m}/day={end:%d}/",
    }

    counts = Counter()
    for prefix in date_prefixes:
        for key in _list_keys(bucket, prefix):
            record = _load_record(bucket, key)
            bucket_name = record.get("bucket_name")
            event_name = record.get("event_name")
            event_time = _parse_iso8601(record.get("event_time"))
            if bucket_name not in obs_buckets:
                continue
            if event_name not in {"DeleteObject", "DeleteObjects"}:
                continue
            if not event_time or event_time < start or event_time >= end:
                continue
            counts[bucket_name] += 1

    result = {"statusCode": 200, "marker": marker_key, "total": sum(counts.values())}
    if counts:
        secret = _get_secret(secret_name)
        webhook_url = (secret.get(info_key) or "").strip()
        if webhook_url:
            status = _post_to_discord(webhook_url, username, start, end, counts)
            result["delivery"] = f"sent:{status}"
        else:
            result["delivery"] = "skipped:missing-webhook"
    else:
        result["delivery"] = "skipped:no-events"

    s3.put_object(
        Bucket=bucket,
        Key=marker_key,
        Body=json.dumps(result, ensure_ascii=False, indent=2).encode("utf-8"),
        ContentType="application/json",
    )

    return result
