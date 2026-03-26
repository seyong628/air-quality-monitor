#!/bin/bash
# =============================================================
# 도시 대기질 실시간 모니터링 시스템 — 전체 환경 설치 스크립트
# 대상 OS : Zorin OS 17 / Ubuntu 22.04 (VMware)
# 실행 방법: sudo bash setup.sh
# =============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR ]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "sudo 또는 root 로 실행하세요."

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
info "프로젝트 경로: $PROJECT_DIR"

# ---------------------------------------------------------------
# 1. 시스템 업데이트
# ---------------------------------------------------------------
info "시스템 업데이트 중..."
apt-get update -y && apt-get upgrade -y

# ---------------------------------------------------------------
# 2. LAMP 설치
# ---------------------------------------------------------------
info "Apache2 설치..."
apt-get install -y apache2
systemctl enable --now apache2

info "MySQL Server 설치..."
apt-get install -y mysql-server
systemctl enable --now mysql

info "PHP 설치..."
apt-get install -y php libapache2-mod-php php-mysql php-cli

info "Python3 / pip / mysql-connector 설치..."
apt-get install -y python3 python3-pip
pip3 install mysql-connector-python --break-system-packages 2>/dev/null \
  || pip3 install mysql-connector-python

# ---------------------------------------------------------------
# 3. MySQL — DB / 사용자 / 스키마 설정
# ---------------------------------------------------------------
info "MySQL 설정 중..."

DB_NAME="air_monitor"
DB_USER="air_user"
DB_PASS="Air@1234!"

mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME}
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

info "스키마 적용 중..."
mysql -u root ${DB_NAME} < "${PROJECT_DIR}/sql/schema.sql"
info "MySQL 설정 완료"

# ---------------------------------------------------------------
# 4. Node-RED 설치
# ---------------------------------------------------------------
info "Node.js 설치 중..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

info "Node-RED 설치 중..."
npm install -g --unsafe-perm node-red 2>/dev/null || true

NODERED_USER="${SUDO_USER:-$USER}"
NODERED_HOME="$(eval echo ~$NODERED_USER)"
NODERED_DIR="${NODERED_HOME}/.node-red"

info "Node-RED 플러그인 설치 (MySQL, Dashboard)..."
sudo -u "$NODERED_USER" bash -c "
  mkdir -p '${NODERED_DIR}'
  cd '${NODERED_DIR}'
  npm install node-red-node-mysql node-red-dashboard 2>/dev/null || true
"

info "Node-RED Flow 복사..."
sudo -u "$NODERED_USER" cp "${PROJECT_DIR}/nodered/flow.json" "${NODERED_DIR}/flows.json"

info "Node-RED 서비스 등록..."
cat > /etc/systemd/system/node-red.service <<EOF
[Unit]
Description=Node-RED
After=network.target mysql.service

[Service]
Type=simple
User=${NODERED_USER}
WorkingDirectory=${NODERED_HOME}
ExecStart=/usr/bin/node-red
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node-red

# ---------------------------------------------------------------
# 5. Grafana 설치
# ---------------------------------------------------------------
info "Grafana 설치 중..."
if ! command -v grafana-server &>/dev/null; then
  apt-get install -y apt-transport-https software-properties-common wget gnupg
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana.gpg
  echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list
  apt-get update -y
  apt-get install -y grafana
fi

info "Grafana Provisioning 설정 복사..."
cp "${PROJECT_DIR}/grafana/provisioning/datasources/mysql.yaml" \
   /etc/grafana/provisioning/datasources/air_mysql.yaml
cp "${PROJECT_DIR}/grafana/provisioning/dashboards/dashboard.yaml" \
   /etc/grafana/provisioning/dashboards/air_dashboard.yaml
cp "${PROJECT_DIR}/grafana/dashboard.json" \
   /etc/grafana/provisioning/dashboards/city_air_quality.json

systemctl enable --now grafana-server

# ---------------------------------------------------------------
# 6. Python 문법 검사
# ---------------------------------------------------------------
info "Python 문법 검사..."
python3 -m py_compile "${PROJECT_DIR}/python/injector.py" \
  && info "injector.py OK" \
  || error "injector.py 문법 오류"

# ---------------------------------------------------------------
# 7. 완료 안내
# ---------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  설치 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Node-RED 편집기   : http://localhost:1880"
echo "  Node-RED 대시보드 : http://localhost:1880/ui"
echo "  Grafana 대시보드  : http://localhost:3000  (admin / admin)"
echo ""
echo "  injector 실행:"
echo "  python3 ${PROJECT_DIR}/python/injector.py --interval 5"
echo ""
echo "  백그라운드 실행:"
echo "  nohup python3 ${PROJECT_DIR}/python/injector.py > /tmp/injector.log 2>&1 &"
echo ""
