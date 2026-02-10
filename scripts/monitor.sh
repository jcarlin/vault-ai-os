#!/bin/bash
# scripts/monitor.sh
# Real-time GPU and system monitoring dashboard

# Check if watch is available
if ! command -v watch &> /dev/null; then
    echo "Installing 'watch' command..."
    apt-get update && apt-get install -y procps
fi

# Run monitoring dashboard
watch -n 2 -c "
echo '═══════════════════════════════════════════════════════════════'
echo '                    GPU & SYSTEM MONITOR                       '
echo '═══════════════════════════════════════════════════════════════'
echo ''
echo '=== GPU Status ==='
nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv,noheader,nounits | awk -F',' '{printf \"GPU %s: %s\\n  Temp: %s°C | GPU Util: %s%% | Mem Util: %s%% | Mem: %s/%s MB | Power: %s W\\n\\n\", \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8}'

echo '=== System Status ==='
uptime | awk '{print \"Uptime: \" \$3 \" \" \$4}'
free -h | awk 'NR==2{printf \"Memory: %s / %s (Used: %s)\\n\", \$3, \$2, \$3}'
df -h / | awk 'NR==2{printf \"Disk: %s / %s (Used: %s)\\n\", \$3, \$2, \$5}'
echo ''

echo '=== GPU Processes ==='
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | head -5
if [ \$(nvidia-smi --query-compute-apps=pid --format=csv,noheader | wc -l) -eq 0 ]; then
    echo 'No GPU processes running'
fi
echo ''

echo '=== Top CPU Processes ==='
ps aux --sort=-%cpu | awk 'NR<=6{printf \"%-8s %5s %5s %s\\n\", \$1, \$3\"%\", \$4\"%\", \$11}' | head -6
echo ''

echo 'Press Ctrl+C to exit | Updated every 2 seconds'
"
