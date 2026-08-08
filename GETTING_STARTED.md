# Getting Started with THATTEOS

*From clone to a running ternary operating system in five minutes.*

THATTEOS is a microkernel operating system written entirely in
[ManiT](https://github.com/manishthatte/manitc). In **hosted mode** it
compiles to a native Linux binary through the manitc LLVM backend — the
kernel's subsystems (scheduler, virtual memory, IPC, three-ring security,
TritFS) run as a self-contained system with an interactive shell.

## 0. Prerequisites

- The **manitc** compiler, built in a sibling directory:

  ```sh
  git clone https://github.com/manishthatte/manitc
  cd manitc && cargo build --release && cd ..
  ```

- **clang** (scripts default to `clang-19`; override with `CLANG=clang-XX`)
- Optional, for the browser and GUI programs: `libcurl`, `SDL2`, `SDL2_ttf`
  (`sudo apt install libcurl4-openssl-dev libsdl2-dev libsdl2-ttf-dev`)

## 1. Build and enter the shell

```sh
git clone https://github.com/manishthatte/thatteos
cd thatteos
bash build.sh
./thatteos
```

You are now in the THATTEOS shell. Try:

```
help          list all commands
ls            list files (TritFS — the ternary file system)
pwd           working directory
cat <file>    print a file
echo <text>   print text
trit <n>      show a number in balanced ternary
priv          show your privilege ring (+1 kernel / 0 service / -1 user)
ps            process list
uptime        ticks since boot
exit          leave the shell
```

Everything you see — the scheduler behind `ps`, the privilege trit behind
`priv`, the file system behind `ls` — is ManiT source in this repository.

## 2. Build and run userspace

```sh
bash userspace/build.sh
./userspace/bin/calc          # ternary calculator
./userspace/bin/fib           # Fibonacci in balanced ternary
./userspace/bin/fm            # full-screen file manager (TUI)
./userspace/bin/editor x.txt  # text editor (TUI)
./userspace/bin/browser       # text-mode web browser (needs libcurl)
./userspace/bin/gui_fm        # graphical file manager (needs SDL2 + a display)
```

Demos worth reading before running:

- `caps_demo` — 9-trit capability words and attenuation
- `ipc_demo` — signed-current message dispatch
- `stream_demo` — zero-copy trit-stream channels
- `sysinfo` — system introspection

## 3. Run the regression tests

```sh
bash tests/test_all.sh
```

## 4. Write your own THATTEOS program

Create `userspace/hi.mt`:

```manit
use std::io;

fn main() {
    io::println("my first THATTEOS program");
}
```

Compile it the same way `userspace/build.sh` does (manitc → LLVM IR → link
with the ManiT runtime), or add `hi` to the `PROGRAMS` list in
`userspace/build.sh` and rebuild.

Programs that run on THATTEOS are **yours under any license** — see
[COPYING.SYSCALL-NOTE](COPYING.SYSCALL-NOTE).

## 5. Understand what you're running

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — the THATTEOS handbook:
every kernel subsystem, what it does, and where it lives in `src/`.

## 6. Questions?

Open a [GitHub Discussion](https://github.com/manishthatte/thatteos/discussions).
Contributions welcome — read [CONTRIBUTING.md](CONTRIBUTING.md) (one-line CLA
required).

---

Authored by **Manish Jagdish Thatte** · manish@manitlab.org · [manitlab.org](https://www.manitlab.org)

© Manish Jagdish Thatte, 2026
