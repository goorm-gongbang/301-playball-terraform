import json
import os
from datetime import datetime, timedelta, timezone
from urllib import request

import boto3

KST = timezone(timedelta(hours=9))
ec2 = boto3.client("ec2")


def _post_to_discord(webhook_url, payload):
    url = webhook_url.strip()
    if url.endswith("/slack"):
        url = url[: -len("/slack")]

    req = request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "goormgb-spot-bot/1.0",
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


def _describe_instance(instance_id):
    if not instance_id or not instance_id.startswith("i-"):
        return {}
    try:
        resp = ec2.describe_instances(InstanceIds=[instance_id])
    except Exception as e:
        print(f"describe_instances failed for {instance_id}: {e}")
        return {}

    reservations = resp.get("Reservations") or []
    if not reservations:
        return {}
    instances = reservations[0].get("Instances") or []
    if not instances:
        return {}

    inst = instances[0]
    tags = {t["Key"]: t["Value"] for t in (inst.get("Tags") or [])}
    placement = inst.get("Placement") or {}
    return {
        "instance_type": inst.get("InstanceType"),
        "availability_zone": placement.get("AvailabilityZone"),
        "private_ip": inst.get("PrivateIpAddress"),
        "nodepool": tags.get("karpenter.sh/nodepool"),
        "nodegroup": tags.get("eks:nodegroup-name"),
        "cluster": tags.get("aws:eks:cluster-name") or tags.get("eks:cluster-name"),
        "name": tags.get("Name"),
        "role": tags.get("role"),
    }


def _build_embed(event):
    detail_type = event.get("detail-type", "Unknown")
    detail = event.get("detail", {}) or {}
    region = event.get("region", "-")
    account = event.get("account", "-")
    instance_id = detail.get("instance-id", "-")
    action = detail.get("instance-action", "-")

    info = _describe_instance(instance_id)
    cluster = info.get("cluster") or os.environ.get("CLUSTER_NAME", "").strip() or "-"

    if info.get("nodepool"):
        group_label = "Karpenter NodePool"
        group_value = info["nodepool"]
    elif info.get("nodegroup"):
        group_label = "EKS NodeGroup"
        group_value = info["nodegroup"]
    elif info.get("role"):
        group_label = "Role Label"
        group_value = info["role"]
    else:
        group_label = "NodeGroup"
        group_value = "unknown"

    if detail_type == "EC2 Spot Instance Interruption Warning":
        title = "Spot Interruption Warning"
        color = 0xE67E22
        description = (
            "**2분 이내 Spot 인스턴스가 회수됩니다.**\n"
            "Karpenter가 자동으로 drain 후 신규 노드로 재스케줄합니다."
        )
    elif detail_type == "EC2 Instance Rebalance Recommendation":
        title = "Spot Rebalance Recommendation"
        color = 0xF1C40F
        description = "AWS가 더 안정적인 용량으로의 교체를 권장합니다."
    else:
        title = detail_type
        color = 0x95A5A6
        description = "알 수 없는 이벤트"

    fields = [
        {"name": "Cluster", "value": cluster, "inline": True},
        {"name": group_label, "value": group_value, "inline": True},
        {"name": "Instance Type", "value": info.get("instance_type") or "-", "inline": True},
        {"name": "Instance", "value": f"{instance_id}\n{info.get('name') or ''}".strip(), "inline": True},
        {"name": "AZ", "value": info.get("availability_zone") or region, "inline": True},
        {"name": "Action", "value": action, "inline": True},
        {"name": "Account", "value": account, "inline": True},
        {"name": "Private IP", "value": info.get("private_ip") or "-", "inline": True},
        {"name": "Time (KST)", "value": _format_kst(event.get("time")), "inline": True},
    ]

    return {
        "title": title,
        "description": description,
        "color": color,
        "fields": fields,
    }


def lambda_handler(event, context):
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if not webhook_url:
        raise ValueError("DISCORD_WEBHOOK_URL is empty")

    mention = os.environ.get("MENTION_TEXT", "").strip()
    username = os.environ.get("DISCORD_WEBHOOK_USERNAME", "goormgb-spot-bot")

    embed = _build_embed(event)
    payload = {
        "username": username,
        "embeds": [embed],
    }
    if mention:
        payload["content"] = mention

    status = _post_to_discord(webhook_url, payload)
    return {"status": status, "detail_type": event.get("detail-type")}
