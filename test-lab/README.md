# Test Lab

This folder provides local services for manually testing MacMobaXterm without a separate server.

## Protocol Coverage

| Feature | Local endpoint | Username | Password | Notes |
| --- | --- | --- | --- | --- |
| SSH | `127.0.0.1:2222` | `tester` | `password` | Also supports shell login |
| SFTP | `127.0.0.1:2222` | `tester` | `password` | Uses the same SSH service |
| FTP | `127.0.0.1:2121` | `tester` | `password` | Passive ports `21100-21110` |
| Telnet | `127.0.0.1:2323` | none | none | Opens a shell in a throwaway container |
| Serial | generated `/dev/ttys*` pair | n/a | n/a | Use `serial/start-virtual-serial.sh` |

VNC and RDP are intentionally excluded for now.

## Docker Services

Install Docker Desktop first, then run:

```bash
cd test-lab
docker compose up -d
```

First startup will build three small Alpine-based images locally.

Check services:

```bash
docker compose ps
nc -vz 127.0.0.1 2222
nc -vz 127.0.0.1 2121
nc -vz 127.0.0.1 2323
```

Stop services:

```bash
docker compose down
```

Reset all service data:

```bash
docker compose down -v
```

## Virtual Serial Pair

Install `socat` once:

```bash
brew install socat
```

Start a virtual pair:

```bash
./test-lab/serial/start-virtual-serial.sh
```

The script prints two device paths. Use the first one in MacMobaXterm's Serial session, then connect to the second one from Terminal:

```bash
screen /dev/ttysXXX 115200
```

Text typed on either side should appear on the other side.

Quit `screen` with `Ctrl-A`, then `K`, then `Y`.
