# Virtual Serial Testing

Use this when no USB serial device is available.

## Start

```bash
brew install socat
./test-lab/serial/start-virtual-serial.sh
```

Example output:

```text
PTY is /dev/ttys001
PTY is /dev/ttys002
```

## Test

Create a Serial session in MacMobaXterm:

- Device: first printed path, for example `/dev/ttys001`
- Baud: `115200`
- Data bits: `8`
- Parity: `N`
- Stop bits: `1`

In macOS Terminal:

```bash
screen /dev/ttys002 115200
```

Typing in either terminal should show text in the other.

Quit `screen` with `Ctrl-A`, then `K`, then `Y`.
