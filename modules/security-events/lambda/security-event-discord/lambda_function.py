import json
import os
from datetime import datetime, timedelta, timezone
from urllib import parse
from urllib import request

import boto3


KST = timezone(timedelta(hours=9))
secretsmanager = boto3.client("secretsmanager")
TEST_MARKERS = ("test/", "test-", "-test", "/test-")

SENSITIVE_PORTS = {
    int(p.strip())
    for p in os.environ.get("SENSITIVE_PORTS", "22,3389,3306,5432,6379").split(",")
    if p.strip()
}


def _post_to_discord(webhook_url, username, payload):
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


def _resolve_webhook_url(severity):
    secret_name = os.environ.get("DISCORD_SECRET_NAME", "").strip()
    if secret_name:
        secret = _get_secret(secret_name)
        key_name = {
            "critical": os.environ.get("CRITICAL_WEBHOOK_KEY", "securityCriticalWebhookUrl"),
            "warning": os.environ.get("WARNING_WEBHOOK_KEY", "securityWarningWebhookUrl"),
            "info": os.environ.get("INFO_WEBHOOK_KEY", "securityInfoWebhookUrl"),
        }[severity]
        return (secret.get(key_name) or "").strip()

    return os.environ.get("DISCORD_WEBHOOK_URL", "").strip()


def _is_test_event(detail):
    request_parameters = detail.get("requestParameters", {}) or {}
    values = [
        detail.get("eventName"),
        request_parameters.get("groupId"),
        request_parameters.get("trailName"),
        request_parameters.get("userName"),
        request_parameters.get("roleName"),
        request_parameters.get("bucketName"),
        request_parameters.get("dBInstanceIdentifier"),
        request_parameters.get("dBSnapshotIdentifier"),
        request_parameters.get("resourceArn"),
    ]
    lowered = " ".join(str(value or "").lower() for value in values)
    return any(marker in lowered for marker in TEST_MARKERS)


def _format_kst(raw_time):
    if not raw_time:
        return datetime.now(timezone.utc).astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")
    dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
    return dt.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")


def _user_identity(detail):
    user = detail.get("userIdentity", {}) or {}
    arn = user.get("arn")
    principal = user.get("principalId")
    user_type = user.get("type")
    return arn or principal or user_type or "unknown"


def _has_risky_ingress(detail):
    request_parameters = detail.get("requestParameters", {}) or {}
    permissions = request_parameters.get("ipPermissions", {}) or {}

    items = permissions.get("items", []) or []
    for item in items:
        from_port = item.get("fromPort")
        to_port = item.get("toPort")

        ip_ranges = (item.get("ipRanges", {}) or {}).get("items", []) or []
        ipv6_ranges = (item.get("ipv6Ranges", {}) or {}).get("items", []) or []

        open_to_world = any(r.get("cidrIp") == "0.0.0.0/0" for r in ip_ranges) or any(
            r.get("cidrIpv6") == "::/0" for r in ipv6_ranges
        )

        if not open_to_world:
            continue

        if from_port is None or to_port is None:
            return True

        for port in SENSITIVE_PORTS:
            if from_port <= port <= to_port:
                return True

    return False


def _classify_event(detail_type, detail):
    event_source = detail.get("eventSource", "")
    event_name = detail.get("eventName", "")
    additional_event_data = detail.get("additionalEventData", {}) or {}

    if detail_type == "AWS Console Sign In via CloudTrail" and event_name == "ConsoleLogin":
        login_result = (detail.get("responseElements", {}) or {}).get("ConsoleLogin")
        user_type = (detail.get("userIdentity", {}) or {}).get("type")
        mfa_used = additional_event_data.get("MFAUsed", "No")

        if login_result == "Success" and user_type == "Root":
            if mfa_used != "Yes":
                return "루트 계정 로그인 감지 (MFA 미사용)", "critical"
            return "루트 계정 로그인 감지", "critical"

        return None, None

    if event_source == "iam.amazonaws.com":
        if event_name in {"CreateAccessKey", "UpdateAccessKey", "DeleteAccessKey"}:
            return "AccessKey 변경 감지", "critical"
        if event_name in {
            "AttachUserPolicy",
            "PutUserPolicy",
            "AttachRolePolicy",
            "PutRolePolicy",
            "CreatePolicyVersion",
            "SetDefaultPolicyVersion",
            "CreateLoginProfile",
            "UpdateLoginProfile",
        }:
            return "IAM 인증/권한 설정 변경 감지", "critical"

    if event_source == "ec2.amazonaws.com" and event_name in {
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
    }:
        if event_name == "AuthorizeSecurityGroupIngress" and _has_risky_ingress(detail):
            return "보안그룹 위험 인바운드 변경 감지", "critical"
        return None, None

    if event_source == "cloudtrail.amazonaws.com":
        if event_name in {"StopLogging", "DeleteTrail"}:
            return "CloudTrail 비활성/삭제 시도 감지", "critical"
        if event_name in {"UpdateTrail", "PutEventSelectors", "PutInsightSelectors", "StartLogging"}:
            return "CloudTrail 설정 변경 감지", "critical"

    if event_source == "s3.amazonaws.com":
        if event_name in {"PutBucketPolicy", "DeleteBucketPolicy"}:
            return "S3 버킷 정책 변경 감지", "critical"
        if event_name in {"PutBucketPublicAccessBlock", "DeleteBucketPublicAccessBlock"}:
            return "S3 공개 접근 차단 설정 변경 감지", "critical"
        if event_name in {"PutBucketAcl", "PutBucketEncryption", "DeleteBucketEncryption"}:
            return "S3 보안 설정 변경 감지", "critical"

    if event_source == "rds.amazonaws.com" and event_name in {
        "ModifyDBInstance",
        "DeleteDBSnapshot",
        "ModifyDBSnapshotAttribute",
    }:
        return "RDS 설정/스냅샷 변경 감지", "critical"

    return None, None


def _build_console_link(detail, aws_region, event_name):
    event_source = detail.get("eventSource", "")
    request_parameters = detail.get("requestParameters", {}) or {}

    if event_source == "iam.amazonaws.com":
        user_name = request_parameters.get("userName")
        role_name = request_parameters.get("roleName")
        if user_name:
            return f"https://console.aws.amazon.com/iam/home?region=global#/users/details/{parse.quote(str(user_name), safe='')}"
        if role_name:
            return f"https://console.aws.amazon.com/iam/home?region=global#/roles/details/{parse.quote(str(role_name), safe='')}"

    if event_source == "ec2.amazonaws.com":
        group_id = request_parameters.get("groupId")
        if group_id:
            return f"https://{aws_region}.console.aws.amazon.com/ec2/home?region={aws_region}#SecurityGroup:groupId={parse.quote(str(group_id), safe='')}"

    if event_source == "s3.amazonaws.com":
        bucket_name = request_parameters.get("bucketName")
        if bucket_name:
            return f"https://s3.console.aws.amazon.com/s3/buckets/{parse.quote(str(bucket_name), safe='')}?region={aws_region}&tab=permissions"

    if event_source == "rds.amazonaws.com":
        db_identifier = request_parameters.get("dBInstanceIdentifier")
        snapshot_identifier = request_parameters.get("dBSnapshotIdentifier")
        if db_identifier:
            return f"https://{aws_region}.console.aws.amazon.com/rds/home?region={aws_region}#database:id={parse.quote(str(db_identifier), safe='')};is-cluster=false"
        if snapshot_identifier:
            return f"https://{aws_region}.console.aws.amazon.com/rds/home?region={aws_region}#snapshot:id={parse.quote(str(snapshot_identifier), safe='')}"

    if event_source == "cloudtrail.amazonaws.com":
        trail_name = request_parameters.get("trailName")
        if trail_name:
            return f"https://{aws_region}.console.aws.amazon.com/cloudtrailv2/home?region={aws_region}#/trails/{parse.quote(str(trail_name), safe='')}"
        return f"https://{aws_region}.console.aws.amazon.com/cloudtrailv2/home?region={aws_region}#/events"

    return f"https://{aws_region}.console.aws.amazon.com/cloudtrailv2/home?region={aws_region}#/events?EventName={parse.quote(str(event_name), safe='')}"


def lambda_handler(event, context):
    username = os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-security-bot").strip()
    critical_mention_text = os.environ.get("CRITICAL_MENTION_TEXT", "").strip()

    detail_type = event.get("detail-type", "")
    detail = event.get("detail", {}) or {}
    event_name = detail.get("eventName", "unknown")
    aws_region = detail.get("awsRegion") or event.get("region") or "unknown"
    source_ip = detail.get("sourceIPAddress", "unknown")
    actor = _user_identity(detail)
    title, severity = _classify_event(detail_type, detail)
    test_prefix = "[TEST] " if _is_test_event(detail) else ""

    if not title:
        return {"statusCode": 200, "delivery": "ignored", "eventName": event_name}

    webhook_url = _resolve_webhook_url(severity)
    if not webhook_url:
        print("Discord webhook is empty, skipping delivery")
        return {"statusCode": 200, "delivery": "skipped", "eventName": event_name, "severity": severity}

    request_parameters = detail.get("requestParameters", {}) or {}
    response_elements = detail.get("responseElements", {}) or {}
    additional_event_data = detail.get("additionalEventData", {}) or {}
    error_code = detail.get("errorCode", "")
    target = (
        request_parameters.get("groupId")
        or request_parameters.get("trailName")
        or request_parameters.get("userName")
        or request_parameters.get("roleName")
        or request_parameters.get("bucketName")
        or request_parameters.get("dBInstanceIdentifier")
        or request_parameters.get("dBSnapshotIdentifier")
        or request_parameters.get("resourceArn")
        or "unknown"
    )

    login_result = response_elements.get("ConsoleLogin")
    mfa_used = additional_event_data.get("MFAUsed")

    fields = [
        {"name": "이벤트", "value": event_name, "inline": True},
        {"name": "리전", "value": aws_region, "inline": True},
        {"name": "대상", "value": str(target), "inline": True},
        {"name": "행위자", "value": str(actor), "inline": False},
        {"name": "Source IP", "value": str(source_ip), "inline": True},
        {"name": "발생 시각 (KST)", "value": _format_kst(event.get("time")), "inline": True},
    ]

    if error_code:
        fields.append({"name": "에러 코드", "value": str(error_code), "inline": True})

    if login_result:
        fields.append({"name": "로그인 결과", "value": str(login_result), "inline": True})

    if mfa_used:
        fields.append({"name": "MFA 사용", "value": str(mfa_used), "inline": True})

    if severity == "critical":
        fields.append(
            {
                "name": "확인 링크",
                "value": _build_console_link(detail, aws_region, event_name),
                "inline": False,
            }
        )

    payload = {
        "username": username,
        "embeds": [
            {
                "title": f"🚨 {test_prefix}AWS 보안 알림 - {title}",
                "color": 15158332,
                "fields": fields,
                "footer": {"text": "goormgb AWS Security Event Alert"},
            }
        ],
    }
    if severity == "critical" and critical_mention_text:
        payload["content"] = critical_mention_text

    status = _post_to_discord(webhook_url, username, payload)
    return {"statusCode": 200, "delivery": f"sent:{status}", "eventName": event_name, "severity": severity}
