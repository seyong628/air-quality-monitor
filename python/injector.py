#!/usr/bin/env python3
"""
도시 대기질 실시간 모니터링 - 랜덤 데이터 생성기
MySQL air_monitor DB의 air_readings 테이블에 5초마다 INSERT
"""

import random
import math
import time
import argparse
import datetime
import mysql.connector
from mysql.connector import Error

# ---------------------------------------------------------------
# DB 연결 설정
# ---------------------------------------------------------------
DB_CONFIG = {
    "host":     "localhost",
    "port":     3306,
    "database": "air_monitor",
    "user":     "air_user",
    "password": "Air@1234!",
    "charset":  "utf8mb4",
}

# ---------------------------------------------------------------
# 측정소별 기본 프로파일
# ---------------------------------------------------------------
STATIONS = {
    "ST-001": {"name": "강남구 측정소", "pm25_base": 22, "pm10_base": 40, "co2_base": 430},
    "ST-002": {"name": "종로구 측정소", "pm25_base": 30, "pm10_base": 55, "co2_base": 470},
    "ST-003": {"name": "마포구 측정소", "pm25_base": 18, "pm10_base": 35, "co2_base": 415},
    "ST-004": {"name": "송파구 측정소", "pm25_base": 25, "pm10_base": 45, "co2_base": 440},
    "ST-005": {"name": "노원구 측정소", "pm25_base": 15, "pm10_base": 28, "co2_base": 400},
}

# ---------------------------------------------------------------
# 알람 임계값
# ---------------------------------------------------------------
THRESHOLDS = {
    "pm25_bad":      35.0,   # PM2.5 나쁨
    "pm25_very_bad": 75.0,   # PM2.5 매우나쁨
    "pm10_bad":      80.0,   # PM10 나쁨
    "pm10_very_bad": 150.0,  # PM10 매우나쁨
    "co2_high":      1000.0, # CO2 경보
    "temp_high":     35.0,   # 고온 경보
    "temp_low":      -10.0,  # 저온 경보
}


def traffic_factor(now: datetime.datetime) -> float:
    """교통량 기반 오염 가중치 (출퇴근 시간 최대)"""
    h = now.hour + now.minute / 60.0

    # 새벽 (0~6시): 최저
    if 0 <= h < 6:
        return 0.4

    # 아침 출근 (7~9시): 급증
    if 6 <= h < 9:
        return 0.4 + 1.0 * math.sin(math.pi * (h - 6) / 3)

    # 오전 (9~11시): 보통
    if 9 <= h < 11:
        return 0.9

    # 낮 (11~17시): 사인파 완만
    if 11 <= h < 17:
        return 0.75 + 0.15 * math.sin(math.pi * (h - 11) / 6)

    # 저녁 퇴근 (17~20시): 피크
    if 17 <= h < 20:
        return 0.9 + 0.6 * math.sin(math.pi * (h - 17) / 3)

    # 야간 (20~24시): 감소
    return 1.5 - 1.1 * ((h - 20) / 4)


def calc_aqi(pm25: float) -> tuple[int, str]:
    """PM2.5 기반 AQI 및 등급 계산 (한국 환경부 기준)"""
    if pm25 <= 15:
        aqi = int(pm25 / 15 * 50)
        grade = "좋음"
    elif pm25 <= 35:
        aqi = int(50 + (pm25 - 15) / 20 * 50)
        grade = "보통"
    elif pm25 <= 75:
        aqi = int(100 + (pm25 - 35) / 40 * 100)
        grade = "나쁨"
    else:
        aqi = int(200 + (pm25 - 75) / 75 * 100)
        grade = "매우나쁨"
    return min(aqi, 500), grade


def generate_reading(sid: str, profile: dict, tf: float) -> dict:
    """측정소 하나의 측정값 생성"""
    # 미세먼지 (계절별 변동 + 교통량 + 가우시안 노이즈)
    season_factor = 1.0 + 0.3 * math.sin(math.pi * datetime.date.today().month / 6)
    pm25 = max(1.0, profile["pm25_base"] * tf * season_factor + random.gauss(0, 3))
    pm10 = max(1.0, profile["pm10_base"] * tf * season_factor + random.gauss(0, 5))

    # CO2 (실내 환경보다 낮은 야외 기준)
    co2 = max(380.0, profile["co2_base"] + tf * 80 + random.gauss(0, 15))

    # 기온 (현재 월 기반 계절 온도)
    month = datetime.date.today().month
    temp_base = 10 + 15 * math.sin(math.pi * (month - 3) / 6)
    temperature = round(temp_base + random.gauss(0, 1.5), 1)

    # 습도
    humidity = round(random.uniform(30, 85), 1)

    pm25 = round(pm25, 1)
    pm10 = round(pm10, 1)
    co2  = round(co2, 1)
    aqi, grade = calc_aqi(pm25)

    return {
        "station_id":  sid,
        "pm25":        pm25,
        "pm10":        pm10,
        "co2":         co2,
        "temperature": temperature,
        "humidity":    humidity,
        "aqi":         aqi,
        "grade":       grade,
    }


def check_alerts(conn, sid: str, r: dict):
    """알람 조건 확인 및 INSERT"""
    alerts = []

    if r["pm25"] >= THRESHOLDS["pm25_very_bad"]:
        alerts.append(("pm25_very_bad", r["pm25"], THRESHOLDS["pm25_very_bad"], f"PM2.5 매우나쁨 ({r['pm25']} μg/m³)"))
    elif r["pm25"] >= THRESHOLDS["pm25_bad"]:
        alerts.append(("pm25_bad",      r["pm25"], THRESHOLDS["pm25_bad"],      f"PM2.5 나쁨 ({r['pm25']} μg/m³)"))

    if r["pm10"] >= THRESHOLDS["pm10_very_bad"]:
        alerts.append(("pm10_very_bad", r["pm10"], THRESHOLDS["pm10_very_bad"], f"PM10 매우나쁨 ({r['pm10']} μg/m³)"))
    elif r["pm10"] >= THRESHOLDS["pm10_bad"]:
        alerts.append(("pm10_bad",      r["pm10"], THRESHOLDS["pm10_bad"],      f"PM10 나쁨 ({r['pm10']} μg/m³)"))

    if r["co2"] >= THRESHOLDS["co2_high"]:
        alerts.append(("co2_high",      r["co2"],  THRESHOLDS["co2_high"],      f"CO2 농도 경보 ({r['co2']} ppm)"))

    if r["temperature"] >= THRESHOLDS["temp_high"]:
        alerts.append(("temp_high",     r["temperature"], THRESHOLDS["temp_high"], f"고온 경보 ({r['temperature']}℃)"))
    elif r["temperature"] <= THRESHOLDS["temp_low"]:
        alerts.append(("temp_low",      r["temperature"], THRESHOLDS["temp_low"],  f"저온 경보 ({r['temperature']}℃)"))

    if not alerts:
        return

    cursor = conn.cursor()
    sql = """INSERT INTO air_alerts
               (station_id, alert_type, value, threshold, message)
             VALUES (%s, %s, %s, %s, %s)"""
    for atype, val, thr, msg in alerts:
        cursor.execute(sql, (sid, atype, val, thr, msg))
    conn.commit()
    cursor.close()


def insert_readings(conn, readings: list[dict]):
    """air_readings 일괄 INSERT"""
    cursor = conn.cursor()
    sql = """INSERT INTO air_readings
               (station_id, pm25, pm10, co2, temperature, humidity, aqi, grade)
             VALUES
               (%(station_id)s, %(pm25)s, %(pm10)s, %(co2)s,
                %(temperature)s, %(humidity)s, %(aqi)s, %(grade)s)"""
    cursor.executemany(sql, readings)
    conn.commit()
    cursor.close()


def run(interval: int, count: int):
    """메인 루프"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        print(f"[DB] MySQL 연결 성공 — {DB_CONFIG['database']}")
    except Error as e:
        print(f"[오류] MySQL 연결 실패: {e}")
        return

    iteration = 0
    try:
        while True:
            iteration += 1
            now = datetime.datetime.now()
            tf  = traffic_factor(now)

            readings = []
            log_parts = [f"[{iteration:04d}] {now.strftime('%H:%M:%S')}"]

            for sid, profile in STATIONS.items():
                r = generate_reading(sid, profile, tf)
                readings.append(r)
                log_parts.append(f"{sid}: PM2.5={r['pm25']} AQI={r['aqi']}({r['grade']})")
                check_alerts(conn, sid, r)

            insert_readings(conn, readings)
            print(" | ".join(log_parts))

            if count and iteration >= count:
                break
            time.sleep(interval)

    except KeyboardInterrupt:
        print("\n[종료] 사용자 인터럽트")
    finally:
        conn.close()
        print("[DB] 연결 종료")


# ---------------------------------------------------------------
# 진입점
# ---------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="도시 대기질 데이터 생성기")
    parser.add_argument("--interval", type=int, default=5,  help="생성 간격(초), 기본값 5")
    parser.add_argument("--count",    type=int, default=0,  help="생성 횟수(0=무한)")
    parser.add_argument("--once",     action="store_true",  help="1회 실행 후 종료")
    args = parser.parse_args()

    if args.once:
        args.count = 1

    run(interval=args.interval, count=args.count)
