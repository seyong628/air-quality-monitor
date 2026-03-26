-- =============================================================
-- 도시 대기질 실시간 모니터링 시스템 - MySQL 스키마
-- Database: air_monitor
-- =============================================================

CREATE DATABASE IF NOT EXISTS air_monitor
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE air_monitor;

-- -----------------------------------------------------------
-- 측정소 정보 테이블
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS stations (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  station_id   VARCHAR(20) NOT NULL UNIQUE,
  station_name VARCHAR(100) NOT NULL,
  district     VARCHAR(50) NOT NULL,
  address      VARCHAR(150),
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------
-- 대기질 측정값 테이블
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS air_readings (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  station_id  VARCHAR(20) NOT NULL,
  pm25        DECIMAL(6,1)  COMMENT 'PM2.5 μg/m³',
  pm10        DECIMAL(6,1)  COMMENT 'PM10 μg/m³',
  co2         DECIMAL(7,1)  COMMENT 'CO2 ppm',
  temperature DECIMAL(5,1)  COMMENT '기온 ℃',
  humidity    DECIMAL(5,1)  COMMENT '습도 %',
  aqi         INT           COMMENT '통합대기환경지수 0~500',
  grade       VARCHAR(10)   COMMENT '좋음/보통/나쁨/매우나쁨',
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_station_time (station_id, recorded_at),
  FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- -----------------------------------------------------------
-- 알람 테이블
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS air_alerts (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  station_id  VARCHAR(20) NOT NULL,
  alert_type  VARCHAR(50)  COMMENT 'pm25_bad/pm25_very_bad/pm10_bad/co2_high/temp_high/temp_low',
  value       DECIMAL(8,2),
  threshold   DECIMAL(8,2),
  message     VARCHAR(255),
  is_resolved TINYINT DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------
-- 측정소 초기 데이터
-- -----------------------------------------------------------
INSERT IGNORE INTO stations (station_id, station_name, district, address) VALUES
  ('ST-001', '강남구 측정소', '강남구', '서울시 강남구 학동로 426'),
  ('ST-002', '종로구 측정소', '종로구', '서울시 종로구 종로 1'),
  ('ST-003', '마포구 측정소', '마포구', '서울시 마포구 월드컵북로 396'),
  ('ST-004', '송파구 측정소', '송파구', '서울시 송파구 올림픽로 300'),
  ('ST-005', '노원구 측정소', '노원구', '서울시 노원구 노해로 437');
