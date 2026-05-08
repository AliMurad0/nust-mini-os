# 🖥️ NUST Mini-OS

A minimal 16-bit operating system written in **x86 Assembly (NASM)**, built as a Computer Organization & Assembly Language (COAL) project at NUST Balochistan Campus.

It boots from raw hardware (or a virtual machine like QEMU), displays an animated splash screen, and gives you an interactive shell with several built-in commands.

---

## 📸 Features

- Custom **2-stage boot** (bootloader → kernel)
- Animated **splash screen** with ASCII box art and a loading bar
- Interactive **command-line shell** with a `nust> ` prompt
- **Keyboard driver** (custom ISR via IVT hooking, supports Shift key)
- Built-in commands: `help`, `clear`, `echo`, `info`, `calc`, `date`, `time`, `mem`, `reboot`

---

## 📁 Project Structure

```
nust-mini-os/
├── boot.asm       # Stage 1: Bootloader (loaded at 0x7C00, exactly 512 bytes)
├── kernel.asm     # Stage 2: Kernel (loaded at 0x7E00, up to 4 sectors)
├── Makefile       # Build + run automation
└── README.md      # This file
```

> **Note:** `.bin` and `.img` files are build outputs and are excluded via `.gitignore`.

---

## ⚙️ How It Works

### Boot Flow
```
BIOS
 └─► boot.bin loaded at 0x7C00     (bootloader, 512 bytes)
      └─► Reads 4 sectors from disk into 0x7E00
           └─► Jumps to kernel at 0x7E00
                └─► Installs keyboard ISR → shows splash → runs shell
```

### Memory Layout
| Address   | Contents               |
|-----------|------------------------|
| `0x7C00`  | Bootloader (512 bytes) |
| `0x7E00`  | Kernel (up to 2 KB)    |
| `0x7C00`  | Stack (grows downward) |

### Keyboard Handling
The kernel hooks **INT 9** (hardware keyboard interrupt) by writing directly into the **Interrupt Vector Table (IVT)** at `0x0000:0x0024`. The custom ISR reads scan codes from port `0x60`, translates them using lookup tables (normal + shifted), and handles Enter/Backspace specially.

---

## 🛠️ Requirements

| Tool | Purpose |
|------|---------|
| [NASM](https://www.nasm.us/) | Assembler — compiles `.asm` → `.bin` |
| [QEMU](https://www.qemu.org/) | Virtual machine to run the OS |

### Install on Ubuntu/Debian
```bash
sudo apt update
sudo apt install nasm qemu-system-x86
```

### Install on Arch Linux
```bash
sudo pacman -S nasm qemu
```

---

## 🚀 Build & Run

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/nust-mini-os.git
cd nust-mini-os

# Build the OS image
make

# Run in QEMU
make run

# Clean build artifacts
make clean
```

### Manual build (without Make)
```bash
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin
cat boot.bin kernel.bin > os.bin
qemu-system-i386 -drive format=raw,file=os.bin
```

---

## 💬 Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `help` | Show all commands | `help` |
| `clear` | Clear the screen | `clear` |
| `echo` | Print text to screen | `echo Hello World` |
| `info` | Show OS info | `info` |
| `calc` | Basic calculator | `calc 10 + 5` |
| `date` | Show current date (from BIOS RTC) | `date` |
| `time` | Show current time (from BIOS RTC) | `time` |
| `mem` | Show conventional memory size | `mem` |
| `reboot` | Reboot the system | `reboot` |

### Calculator supports: `+`, `-`, `*`, `/`
```
nust> calc 25 * 4
100
nust> calc 100 / 0
Error: Division by zero!
```

---

## 🔧 Technical Notes

- **Architecture:** x86 16-bit Real Mode
- **Assembler:** NASM (flat binary output)
- **BIOS Interrupts used:** `INT 0x10` (video), `INT 0x13` (disk), `INT 0x1A` (RTC/timer), `INT 0x12` (memory)
- **Kernel origin:** `0x7E00` (right after the 512-byte bootloader)
- **Stack:** Set to `0x7C00`, grows downward into low memory
- **Color terminal:** Uses BIOS `AH=09h` for colored text output

---

## 👥 Authors

- **NUST Balochistan Campus** — COAL Course Project

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).