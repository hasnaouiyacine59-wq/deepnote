#!/bin/bash
set -e



sudo rm -f /etc/apt/sources.list.d/yarn.list /usr/share/keyrings/yarn.gpg
curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarn.gpg
echo "deb [signed-by=/usr/share/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/yarn.list

apt-get update -y
apt-get install -y tor torsocks python3-pip xvfb software-properties-common curl

# Install Python 3.10 on Ubuntu 18.04 without PPA (avoids hanging)
if ! command -v python3.10 &>/dev/null; then
    curl -fsSL https://github.com/indygreg/python-build-standalone/releases/download/20230507/cpython-3.10.11+20230507-x86_64-unknown-linux-gnu-install_only.tar.gz \
        | tar -xz -C /usr/local --strip-components=1
fi

python3.10 -m ensurepip --upgrade
python3.10 -m pip install --upgrade pip
python3.10 -m pip install -r requirements.txt
python3.10 -m playwright install firefox || true
# install-deps fails on broken Ubuntu 18.04 packages; install manually
apt-get install -y --fix-broken
apt-get install -y \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 \
    libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 \
    libpango-1.0-0 libx11-6 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libxshmfence1 || true
mkdir -p content/

setsid tor -f torrc1 >content/tor1.log 2>&1 &
setsid tor -f torrc2 >content/tor2.log 2>&1 &
setsid tor -f torrc3 >content/tor3.log 2>&1 &
#setsid tor -f torrc4 >content/tor4.log 2>&1 &

echo "Waiting for Tor to bootstrap..."
for port in 9051 9053 9055; do
    for i in $(seq 1 30); do
        if echo -e 'AUTHENTICATE ""\r\nGETINFO status/bootstrap-phase\r\nQUIT\r\n' | nc -q1 127.0.0.1 "$port" 2>/dev/null | grep -q "PROGRESS=100"; then
            echo "Tor on port $port ready."
            break
        fi
        sleep 2
    done
done

echo "Tor ready, starting sessions..."

run_loop() {
    local socks=$1 ctrl=$2
    while true; do
        nice -n 10 python3.10 cum.py --socks-port "$socks" --control-port "$ctrl"
        sleep 2
    done
}

run_loop 9050 9051 &
run_loop 9052 9053 &
run_loop 9054 9055 &
#run_loop 9056 9057 &

wait
