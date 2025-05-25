#!/bin/bash

OUTPUT_FILE="../results/vm_metrics/metrics_vm.csv"
INTERVAL=5
DURATION=60
SAMPLES=$(( DURATION / INTERVAL ))
PING_TARGET="localhost"

mkdir -p ../results/vm_metrics
echo "timestamp,cpu_percent,mem_percent,net_rx_kbps,net_tx_kbps,latency_ms" > "$OUTPUT_FILE"

NET_IFACE=$(ip route get 1 | awk '{print $5; exit}')

echo "[INFO] Iniciando servidor desde ../results/minecraft-server..."
cd ../results/minecraft-server
java -Xmx2G -Xms2G -jar minecraft_server.jar nogui &
SERVER_PID=$!
cd - > /dev/null

echo "[INFO] Esperando 20 segundos al arranque del servidor..."
sleep 20

echo "[INFO] Iniciando captura de métricas por $DURATION segundos..."

for ((i=0; i<SAMPLES; i++)); do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  CPU=$(top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4}')
  MEM=$(free | awk '/Mem:/ { printf("%.2f", $3/$2 * 100.0) }')

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

