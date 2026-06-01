# Virtual Serial Testing

Use this when no USB serial device is available.

## Start

```bash
brew install socat
./test-lab/serial/start-virtual-serial.sh
```

Example output:

```text
Use this path in MacMobaXterm:
  /tmp/macmobaxterm-serial-app

Use this path in Terminal:
  screen /tmp/macmobaxterm-serial-peer 115200
```

## Test

Create a Serial session in MacMobaXterm:

- Device: `/tmp/macmobaxterm-serial-app`
- Baud: `115200`
- Data bits: `8`
- Parity: `N`
- Stop bits: `1`

In macOS Terminal:

```bash
screen /tmp/macmobaxterm-serial-peer 115200
```

Typing in either terminal should show text in the other. This is a raw serial link, so there is no shell prompt and no local echo unless the other side sends the text back.

Quit `screen` with `Ctrl-A`, then `K`, then `Y`.
