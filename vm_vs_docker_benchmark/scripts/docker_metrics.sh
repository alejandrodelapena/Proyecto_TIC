#!/bin/bash

OUTPUT_FILE="../results/docker_metrics/metrics_docker.csv"
INTERVAL=5
DURATION=60
SAMPLES=$(( DURATION / INTERVAL ))
CONTAINER_NAME="minecraft_docker"
PING_TARGET="localhost"

mkdir -p ../results/docker_metrics
echo "timestamp,cpu_percent,mem_percent,net_rx_kbps,net_tx_kbps,latency_ms" > "$OUTPUT_FILE"

NET_IFACE=$(ip route get 1 | awk '{print $5; exit}')

if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "[INFO] Iniciando contenedor Docker con docker-compose..."
  docker-compose -f ../scripts/docker-compose.yml up -d
  echo "[INFO] Esperando 20 segundos al arranque del servidor..."
  sleep 20
fi

echo "[INFO] Iniciando captura de métricas por $DURATION segundos..."

for ((i=0; i<SAMPLES; i++)); do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  STATS=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" $CONTAINER_NAME)
  CPU=$(echo $STATS | cut -d',' -f1 | tr -d '%')
  MEM=$(echo $STATS | cut -d',' -f2 | tr -d '%')

  RX_BEFORE=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
  TX_BEFORE=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)
  sleep $INTERVAL
  RX_AFTER=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
  TX_AFTER=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)

  RX_KBPS=$(( (RX_AFTER - RX_BEFORE) / 1024 / INTERVAL ))
  TX_KBPS=$(( (TX_AFTER - TX_BEFORE) / 1024 / INTERVAL ))

  LATENCY=$(ping -c 1 -q $PING_TARGET | awk -F'/' '/avg/ {print $5}')
  LATENCY=${LATENCY:-0.0}

  echo "$TIMESTAMP,$CPU,$MEM,$RX_KBPS,$TX_KBPS,$LATENCY" >> "$OUTPUT_FILE"
done

echo "[INFO] Finalizada la captura de métricas."
