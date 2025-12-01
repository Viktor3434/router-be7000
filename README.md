# Xiaomi BE7000 Router Docker with ByeDPI in container

**The project is at the development stage**

---

> **Educational Project** - This project is created for learning purposes to explore Docker containerization and networking.

## 🛠 Prerequisites

- Xiaomi BE7000 router with SSH access obtained via [xmir-patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
- USB storage device
- install docker utils from router UI
- You need to know the basics of working with docker and docker-compose


## Project files

```
├── files
│   ├── hosts.txt — list of hosts for byedpi
│   └── nginx-pac.conf — configuration file for nginx
├── README.md
├── scripts
│   ├── change-opa-policy.sh       — fixes the regular expression for the OPA policy (by default, it does not allow adding :ro or :rw for volumemount)
│   ├── create-alias.sh            — safely adds docker-binaries dir to the PATH variable.
│   ├── download-docker-compose.sh — downloads docker-compose and verifies that it works correctly using the hello-world container.
│   └── main.sh                    — downloads and runs the scripts above
└── templates
    ├── docker-compose.yaml.template — describes all containers and their settings (you need to understand what this means to use it)
    ├── nginx-proxy.pac.template     — proxy autoconfiguration file supplied by nginx
    └── privoxy.conf.template        — configuration file for a container with privoxy (listens to http and sends to local SOCKS)
```

## How to use it

```
curl -L https://github.com/Viktor3434/router-be7000/raw/refs/heads/main/scripts/main.sh | sh
```
after you see the message "Setup completed successfully!"

1. Run: `cd /mnt/.../mi_docker/files && docker-compose up -d`
2. Configure browser to use PAC: `http://${ROUTER_IP}:8888/proxy.pac`
3. Check logs: `docker-compose logs`

# Conceptually about what it is

```
Client Device
↓
[Browser/App] → HTTP/HTTPS Request
↓
┌─────────────────────────────────────────────────────┐
│ Xiaomi BE7000 Router                                │
│ ┌─────────┐   ┌─────────────┐   ┌─────────────┐     │
│ │  Nginx  │ → │   Privoxy   │ → │   ByeDPI    │ →  Internet 
│ │  (PAC)  │   │ (HTTP Proxy)│   │  (Socks5)   │     │
│ └─────────┘   └─────────────┘   └─────────────┘     │
└─────────────────────────────────────────────────────┘
```

## P.S.:
A selection of DPI commands can be found in an excellent Android app. [romanvht/ByeByeDPI](https://github.com/romanvht/ByeByeDPI)