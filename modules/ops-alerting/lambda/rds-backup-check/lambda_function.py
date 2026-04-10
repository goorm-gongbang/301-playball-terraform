import json
import os
from datetime import datetime, timedelta, timezone
from urllib import parse
from urllib import request

import boto3


KST = timezone(timedelta(hours=9))


def _region():
    return os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "ap-northeast-2"


def _get_secret(secret_name, region):
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def _format_kst(raw_time):
    if not raw_time:
        return "N/A"
    dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
    return dt.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")


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


def _find_latest_dump_time(s3_client, bucket, prefix):
    continuation_token = None
    latest_object = None

    while True:
        kwargs = {
            "Bucket": bucket,
            "Prefix": prefix,
            "MaxKeys": 1000,
        }
        if continuation_token:
            kwargs["ContinuationToken"] = continuation_token

        response = s3_client.list_objects_v2(**kwargs)
        for obj in response.get("Contents", []):
            last_modified = obj.get("LastModified")
            if last_modified and (latest_object is None or last_modified > latest_object):
                latest_object = last_modified

        if not response.get("IsTruncated"):
            break
        continuation_token = response.get("NextContinuationToken")

    return latest_object


def lambda_handler(event, context):
    region = _region()
    db_identifier = os.environ.get("DB_INSTANCE_IDENTIFIER", "").strip()
    secret_name = os.environ.get("DISCORD_SECRET_NAME", "").strip()
    critical_mention_text = os.environ.get("CRITICAL_MENTION_TEXT", "").strip()
    stale_hours = int(os.environ.get("SNAPSHOT_STALE_HOURS", "36"))
    dump_bucket = os.environ.get("DUMP_S3_BUCKET", "").strip()
    dump_prefix = os.environ.get("DUMP_S3_PREFIX", "").strip()
    dump_stale_hours = int(os.environ.get("DUMP_STALE_HOURS", str(stale_hours)))

    if not db_identifier or not secret_name:
        raise ValueError("DB_INSTANCE_IDENTIFIER or DISCORD_SECRET_NAME is empty")

    rds = boto3.client("rds", region_name=region)
    s3 = boto3.client("s3", region_name=region)
    secret = _get_secret(secret_name, region)

    instance = rds.describe_db_instances(DBInstanceIdentifier=db_identifier)["DBInstances"][0]
    backup_retention = int(instance.get("BackupRetentionPeriod", 0))
    latest_restorable = instance.get("LatestRestorableTime")

    critical_reasons = []
    warning_reasons = []

    if backup_retention <= 0:
        critical_reasons.append("PITR가 비활성 상태입니다. BackupRetentionPeriod가 0입니다.")

    if not latest_restorable:
        critical_reasons.append("LatestRestorableTime이 없어 복구 가능 시점을 확인할 수 없습니다.")

    snapshot_time = None
    snapshots = rds.describe_db_snapshots(
        DBInstanceIdentifier=db_identifier,
        SnapshotType="automated",
        MaxRecords=20,
    )["DBSnapshots"]
    if snapshots:
        snapshot_time = max(snap["SnapshotCreateTime"] for snap in snapshots if snap.get("SnapshotCreateTime"))

    now_utc = datetime.now(timezone.utc)
    if latest_restorable:
        latest_restorable_dt = latest_restorable.astimezone(timezone.utc)
        if now_utc - latest_restorable_dt > timedelta(hours=stale_hours):
            warning_reasons.append(f"LatestRestorableTime이 {stale_hours}시간 이상 갱신되지 않았습니다.")

    if snapshot_time:
        snapshot_dt = snapshot_time.astimezone(timezone.utc)
        if now_utc - snapshot_dt > timedelta(hours=stale_hours):
            warning_reasons.append(f"자동 백업 스냅샷이 {stale_hours}시간 이상 생성되지 않았습니다.")
    else:
        warning_reasons.append("자동 백업 스냅샷을 찾지 못했습니다.")

    latest_dump_time = None
    if dump_bucket and dump_prefix:
        latest_dump_time = _find_latest_dump_time(s3, dump_bucket, dump_prefix)
        if latest_dump_time:
            latest_dump_dt = latest_dump_time.astimezone(timezone.utc)
            if now_utc - latest_dump_dt > timedelta(hours=dump_stale_hours):
                warning_reasons.append(f"S3 보조 백업이 {dump_stale_hours}시간 이상 갱신되지 않았습니다.")
        else:
            warning_reasons.append("S3 보조 백업의 최근 성공 파일을 찾지 못했습니다.")

    if not critical_reasons and not warning_reasons:
        return {"statusCode": 200, "delivery": "ignored"}

    severity = "critical" if critical_reasons else "warning"
    webhook_key = os.environ.get("CRITICAL_WEBHOOK_KEY", "criticalWebhookUrl") if severity == "critical" else os.environ.get("WARNING_WEBHOOK_KEY", "warningWebhookUrl")
    webhook_url = (secret.get(webhook_key) or "").strip()
    if not webhook_url:
        raise ValueError(f"Webhook URL is empty for key: {webhook_key}")

    color = 15158332 if severity == "critical" else 16753920
    emoji = "🔴" if severity == "critical" else "🟡"
    level_name = "긴급" if severity == "critical" else "경고"
    reasons = critical_reasons or warning_reasons

    payload = {
        "username": os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-rds-backup-bot"),
        "embeds": [
            {
                "title": f"[{os.environ.get('ENVIRONMENT', 'unknown')}] {emoji} AWS {level_name} 알림 [{datetime.now(KST).strftime('%Y%m%d-%H%M%S')}]",
                "color": color,
                "fields": [
                    {"name": "알림", "value": "RDS 백업/복구 상태 이상", "inline": False},
                    {"name": "대상", "value": db_identifier, "inline": False},
                    {"name": "BackupRetentionPeriod", "value": str(backup_retention), "inline": True},
                    {"name": "LatestRestorableTime", "value": _format_kst(latest_restorable.isoformat() if latest_restorable else None), "inline": True},
                    {"name": "최근 자동 스냅샷", "value": _format_kst(snapshot_time.isoformat() if snapshot_time else None), "inline": False},
                    {"name": "최근 S3 보조 백업", "value": _format_kst(latest_dump_time.isoformat() if latest_dump_time else None), "inline": False},
                    {"name": "사유", "value": "\n".join(f"- {reason}" for reason in reasons)[:1024], "inline": False},
                ],
                "footer": {"text": "goormgb AWS RDS Backup Checker"},
            }
        ],
    }

    if severity == "critical":
        if critical_mention_text:
            payload["content"] = critical_mention_text
        payload["embeds"][0]["fields"].append(
            {
                "name": "확인 링크",
                "value": f"https://{region}.console.aws.amazon.com/rds/home?region={region}#database:id={parse.quote(str(db_identifier), safe='')};is-cluster=false",
                "inline": False,
            }
        )

    status = _post_to_discord(webhook_url, payload)
    return {"statusCode": 200, "delivery": f"sent:{status}", "severity": severity}
