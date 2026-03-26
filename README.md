# 도시 대기질 실시간 모니터링 시스템

![MySQL](https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql)
![Python](https://img.shields.io/badge/Python-3.x-green?logo=python)
![Node--RED](https://img.shields.io/badge/Node--RED-3.x-red?logo=node-red)
![Grafana](https://img.shields.io/badge/Grafana-10.x-orange?logo=grafana)
![Zorin OS](https://img.shields.io/badge/OS-Zorin%20OS%2017-blue?logo=linux)

서울시 5개 구청 대기질 측정소의 PM2.5 · PM10 · CO2 · 기온 · 습도를
**Node-RED**와 **Grafana**로 실시간 시각화하는 모니터링 시스템

---

## 주요 기능

- `injector.py` — 교통량 패턴 기반 가상 대기질 데이터 5초마다 생성
- MySQL `air_readings` — PM2.5, PM10, CO2, 기온, 습도, AQI 저장
- MySQL `air_alerts` — PM2.5/PM10 나쁨, CO2 경보, 고·저온 자동 감지
- **Node-RED Dashboard** — 실시간 차트·게이지·알람 테이블 (`/ui`)
- **Grafana Dashboard** — 5초 자동 갱신, Time series·Bar gauge·Stat 패널

---

## Quick Start

```bash
# 1. 저장소 클론
git clone <your-repo-url>
cd sqlite_node-red

# 2. 전체 환경 설치 (LAMP + Node-RED + Grafana)
sudo bash setup.sh

# 3. 데이터 생성 시작
nohup python3 python/injector.py --interval 5 > /tmp/injector.log 2>&1 &

# 4. 대시보드 접속
#   Node-RED : http://localhost:1880/ui
#   Grafana  : http://localhost:3000  (admin/admin)
```

---

## 스크린샷

> *영상 촬영 후 스크린샷 추가 예정*

| Node-RED Dashboard | Grafana Dashboard |
|:------------------:|:-----------------:|
| ![nodered](#)      | ![grafana](#)     |

---

## 상세 문서

동작 설명 및 Mermaid 플로우차트 → **[project.md](./project.md)**
