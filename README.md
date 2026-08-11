# thatteOS — a balanced ternary operating system

[![CI](https://github.com/manishthatte/thatteOS/actions/workflows/ci.yml/badge.svg)](https://github.com/manishthatte/thatteOS/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

**thatteOS** is a microkernel operating system written entirely in
[ManiT](https://github.com/manishthatte/maniTC), the balanced ternary systems
language. It manages a photonic-ternary computing fabric the way a
conventional kernel manages a CPU — except the clock is a photon schedule,
addresses are trits, and privilege is a single trit deep.

What's here, all in ManiT source:

- **Kernel** (`src/`): bootstrap, interrupt dispatch, three-ring security
  (+1 kernel / 0 service / −1 user), scheduler, process management,
  trit-addressed virtual memory with trit-trie page tables, syscall dispatch,
  message-passing IPC, trit-stream channels, photon-schedule capability
  security, TTY driver
- **Interactive shell** (`thatteos.mt`): builds and runs on Linux today
  (hosted mode) via the maniTC LLVM backend
- **Userspace** (`userspace/`): calculator, Fibonacci, file manager, text
  editor, web browser, SDL2 GUI apps, IPC/capability demos — all in ManiT
- **Tests** (`tests/`): kernel + userspace regression suite

**New here? Read [GETTING_STARTED.md](GETTING_STARTED.md)**, then
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — the handbook of every kernel
subsystem.

## Quick start (hosted mode, Linux)

```sh
# 1. Build the compiler (sibling repo)
git clone https://github.com/manishthatte/maniTC
cd maniTC && cargo build --release && cd ..

# 2. Build and run the thatteOS shell
git clone https://github.com/manishthatte/thatteOS
cd thatteOS && bash build.sh
./thatteos

# 3. Userspace programs
bash userspace/build.sh
./userspace/bin/calc
```

Requires `clang-19` (or set `CLANG`), and optionally libcurl + SDL2/SDL2_ttf
for the browser and GUI programs.

## License

- **AGPL-3.0** ([LICENSE](LICENSE)) with the
  **[syscall boundary note](COPYING.SYSCALL-NOTE)**: programs that *run on*
  thatteOS via its syscalls/IPC are **not** captured by the kernel's license —
  write and distribute them under any terms.
- **Commercial licenses** for proprietary kernel derivatives:
  manish@manitlab.org

Contributions require the one-line CLA — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Patents

The photonic-ternary hardware architecture thatteOS manages is covered by
twelve patent applications filed with the Indian Patent Office (2026), sole
inventor Manish Jagdish Thatte — see [NOTICE](NOTICE). The AGPL's patent
grant (§11) applies to this software as released; hardware implementations
require a separate license.

---

Authored by **Manish Jagdish Thatte** · manish@manitlab.org · [manitlab.org](https://www.manitlab.org)

© Manish Jagdish Thatte, 2026
