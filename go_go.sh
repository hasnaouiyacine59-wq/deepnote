#!/bin/bash
set -e



sudo rm /etc/apt/sources.list.d/yarn.list
curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarn.gpg
echo "deb [signed-by=/usr/share/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/yarn.list

apt-get update -y
apt-get install -y tor torsocks python3-pip xvfb software-properties-common
DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:deadsnakes/ppa -y
apt-get update -y
apt-get install -y python3.10 python3.10-distutils python3.10-venv
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
python3.10 -m pip install -r requirements.txt
python3.10 -m playwright install firefox || true
python3.10 -m playwright install-deps
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
