"""
CDN Realtime Stats — CloudFront RT Log → Redis → CloudWatch

기능:
  1. HyperLogLog 고유 접속자 집계 (PFADD/PFCOUNT)
  2. IP별 요청 수 카운트 → 임계치 초과 시 blocklist 등록
  3. 요청 수 / 고유 IP 비율(ratio) 분석 → 공격 유형 판별
"""

import base64
import json
import os
import time
import boto3
import redis

# --- Config ---
REDIS_HOST = os.environ["REDIS_HOST"]
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_DB = int(os.environ.get("REDIS_DB", "3"))  # DB 3: realtime-stats 전용
REDIS_TLS = os.environ.get("REDIS_TLS", "false").lower() == "true"
ENVIRONMENT = os.environ.get("ENVIRONMENT", "staging")
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "PlayBall/RealtimeStats")

# 봇 탐지 임계치 (환경변수로 튜닝 가능)
BOT_REQ_THRESHOLD = int(os.environ.get("BOT_REQ_THRESHOLD", "200"))  # IP당 1분 요청 수
BOT_BLOCKLIST_TTL = int(os.environ.get("BOT_BLOCKLIST_TTL", "3600"))  # blocklist TTL (1시간)

# ratio 알림 임계치
RATIO_SINGLE_IP_ATTACK = float(os.environ.get("RATIO_SINGLE_IP_ATTACK", "50"))
RATIO_BOTNET_ATTACK = float(os.environ.get("RATIO_BOTNET_ATTACK", "1.2"))
MIN_REQUESTS_FOR_RATIO = int(os.environ.get("MIN_REQUESTS_FOR_RATIO", "500"))

# HyperLogLog 키 TTL (초)
TTL_MINUTE = 300
TTL_HOUR = 7200
TTL_DAY = 172800

# IP 요청 카운터 TTL
TTL_IP_COUNTER = 60  # 1분

cloudwatch = boto3.client("cloudwatch")
redis_client = redis.Redis(
    host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB,
    socket_timeout=2, ssl=REDIS_TLS,
)

# 내부 대역 (Pod 간 통신) — blocklist 제외
INTERNAL_PREFIXES = ("10.", "172.16.", "172.17.", "172.18.", "172.19.",
                     "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
                     "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
                     "172.30.", "172.31.", "192.168.")


def is_internal(ip):
    return any(ip.startswith(p) for p in INTERNAL_PREFIXES)


def parse_cloudfront_log(data):
    """CloudFront RT 로그 필드 파싱 (탭 구분)."""
    fields = data.split("\t")
    if len(fields) < 4:
        return None
    return {
        "timestamp": fields[0],
        "client_ip": fields[1] if len(fields) > 1 else None,
        "method": fields[2] if len(fields) > 2 else None,
        "uri": fields[3] if len(fields) > 3 else None,
        "status": fields[5] if len(fields) > 5 else None,
        "user_agent": fields[8] if len(fields) > 8 else None,
    }


def handler(event, context):
    now = time.gmtime()
    minute_key = f"visitors:{ENVIRONMENT}:min:{time.strftime('%Y%m%d%H%M', now)}"
    hour_key = f"visitors:{ENVIRONMENT}:hour:{time.strftime('%Y%m%d%H', now)}"
    day_key = f"visitors:{ENVIRONMENT}:day:{time.strftime('%Y%m%d', now)}"
    total_req_key = f"total_req:{ENVIRONMENT}:min:{time.strftime('%Y%m%d%H%M', now)}"

    # 로그 파싱
    ip_counts = {}  # IP별 요청 수 (이번 배치)
    total_requests = 0

    for record in event.get("Records", []):
        payload = base64.b64decode(record["kinesis"]["data"]).decode("utf-8")
        for line in payload.strip().split("\n"):
            parsed = parse_cloudfront_log(line)
            if not parsed or not parsed["client_ip"]:
                continue
            ip = parsed["client_ip"]
            if is_internal(ip):
                continue
            ip_counts[ip] = ip_counts.get(ip, 0) + 1
            total_requests += 1

    if not ip_counts:
        return {"processed": 0}

    ips = set(ip_counts.keys())

    # =========================================
    # 1. HyperLogLog 고유 접속자 집계
    # =========================================
    pipe = redis_client.pipeline()
    for key, ttl in [(minute_key, TTL_MINUTE), (hour_key, TTL_HOUR), (day_key, TTL_DAY)]:
        pipe.pfadd(key, *ips)
        pipe.expire(key, ttl)

    # 총 요청 수 카운터 (ratio 분석용)
    pipe.incrby(total_req_key, total_requests)
    pipe.expire(total_req_key, TTL_MINUTE)

    # =========================================
    # 2. IP별 요청 수 카운트 + blocklist
    # =========================================
    for ip, count in ip_counts.items():
        ip_key = f"req_count:{ENVIRONMENT}:{ip}"
        pipe.incrby(ip_key, count)
        pipe.expire(ip_key, TTL_IP_COUNTER)

    pipe.execute()

    # blocklist 판정 (임계치 초과 IP)
    new_blocked = []
    for ip, batch_count in ip_counts.items():
        ip_key = f"req_count:{ENVIRONMENT}:{ip}"
        total_count = redis_client.get(ip_key)
        if total_count and int(total_count) > BOT_REQ_THRESHOLD:
            blocklist_key = f"blocklist:{ENVIRONMENT}"
            added = redis_client.sadd(blocklist_key, ip)
            redis_client.expire(blocklist_key, BOT_BLOCKLIST_TTL)
            if added:
                new_blocked.append({"ip": ip, "requests": int(total_count)})

    # =========================================
    # 3. Ratio 분석 (요청 수 / 고유 IP)
    # =========================================
    count_minute = redis_client.pfcount(minute_key)
    count_hour = redis_client.pfcount(hour_key)
    count_day = redis_client.pfcount(day_key)

    total_req_minute = int(redis_client.get(total_req_key) or 0)
    ratio = total_req_minute / max(count_minute, 1)
    blocklist_size = redis_client.scard(f"blocklist:{ENVIRONMENT}") or 0

    # 공격 유형 판별
    attack_type = "normal"
    if total_req_minute >= MIN_REQUESTS_FOR_RATIO:
        if ratio > RATIO_SINGLE_IP_ATTACK:
            attack_type = "single_ip_attack"  # 소수 IP가 대량 요청
        elif count_minute > 1000 and ratio < RATIO_BOTNET_ATTACK:
            attack_type = "botnet_distributed"  # 다수 IP가 각 1건씩

    # =========================================
    # CloudWatch 메트릭 전송
    # =========================================
    metrics = [
        {"MetricName": "UniqueVisitors1Min", "Value": count_minute, "Unit": "Count"},
        {"MetricName": "UniqueVisitors1Hour", "Value": count_hour, "Unit": "Count"},
        {"MetricName": "UniqueVisitorsToday", "Value": count_day, "Unit": "Count"},
        {"MetricName": "TotalRequests1Min", "Value": total_req_minute, "Unit": "Count"},
        {"MetricName": "ReqPerVisitorRatio", "Value": ratio, "Unit": "None"},
        {"MetricName": "BlocklistSize", "Value": blocklist_size, "Unit": "Count"},
        {"MetricName": "NewBlocked", "Value": len(new_blocked), "Unit": "Count"},
    ]

    dim = [{"Name": "Environment", "Value": ENVIRONMENT}]
    cloudwatch.put_metric_data(
        Namespace=METRIC_NAMESPACE,
        MetricData=[{**m, "Dimensions": dim} for m in metrics],
    )

    return {
        "processed": total_requests,
        "unique_ips": len(ips),
        "visitors_minute": count_minute,
        "visitors_hour": count_hour,
        "visitors_day": count_day,
        "ratio": round(ratio, 2),
        "attack_type": attack_type,
        "new_blocked": new_blocked,
        "blocklist_size": blocklist_size,
    }
