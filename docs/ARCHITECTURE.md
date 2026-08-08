# The THATTEOS Handbook — Architecture

*What every subsystem does, why it thinks in threes, and where it lives.*

THATTEOS is a microkernel for a balanced ternary computing fabric. Where a
conventional kernel manages a CPU clocked by a crystal, THATTEOS manages a
fabric of ternary devices coordinated by photon schedules: addresses are
trits, privilege is one trit deep, and "permission AND request" is a single
hardware gate. In hosted mode all of this runs as a native Linux process —
same source, same semantics — which is what makes the design inspectable
today.

## The big picture

```
 userspace programs (userspace/*.mt — any license, see COPYING.SYSCALL-NOTE)
        │  syscalls / IPC
 ┌──────┴───────────────────────────────────────────────┐
 │  syscall/syscall.mt — dispatcher, 16 handlers         │
 ├───────────────────────────────────────────────────────┤
 │ kernel/    scheduling, processes, privilege, faults   │
 │ mm/        frames, page tables, virtual memory        │
 │ fs/        TritFS: inodes, descriptors, permissions   │
 │ ipc/       messages, pipes, trit streams              │
 │ security/  capability words, photon-schedule caps     │
 │ drivers/   tty                                        │
 └───────────────────────────────────────────────────────┘
```

## Three-ring security — the load-bearing idea

Privilege is a single trit: **+1 kernel, 0 service, −1 user**
(`kernel/privilege.mt`). Permission checking is not a comparison routine —
it is the **TMIN2 gate** (`kernel/tmin2.mt`), the ternary minimum:

    access = TMIN2(privilege, request)

A −1 (user) privilege can never produce a +1 (kernel) access, by algebra
rather than by code path. `userspace/init.mt` exists to prove the drop:
the first user process starts at +1 during boot and demonstrably cannot get
it back after dropping to −1.

## Subsystem tour (`src/`)

### kernel/
| Module | What it is |
|--------|------------|
| `scheduler.mt` | Priority scheduler built on the three-way branch (TBRANCH), with time quantum and starvation prevention |
| `process.mt` | Process control blocks, `sys_fork` / `sys_exec` / `sys_exit` |
| `context.mt` | T3ISA register-file snapshot for context switching |
| `privilege.mt` | The privilege trit: get/set, fault handler, `sys_priv_set` |
| `tmin2.mt` | The TMIN2 permission gate and three-ring model |
| `interrupt.mt` | 27-vector interrupt table, priority dispatch, nesting, statistics |
| `timer.mt` | System tick, sleep queue, timer interrupt handler |
| `signal.mt` | 9 signals, delivery, default handlers |
| `guard.mt` | Boundary validation for every kernel subsystem |
| `klog.mt` | Ring-buffer kernel log with **ternary severity** (−1 error / 0 warning / +1 info) |
| `panic.mt` | Structured panic and fault display |

### mm/ — memory in trits
| Module | What it is |
|--------|------------|
| `mmu.mt` | Physical frame allocator (frame table, alloc/free) |
| `pgtable.mt` | Page tables with conditional permissions, `map_page`, access fault handling |
| `vmem.mt` | Virtual memory manager: trit-addressed spaces, per-address privilege checks |

Addresses are balanced ternary words translated through **trit-trie** page
tables — branching factor 3, one trit consumed per level.

### fs/ — TritFS
| Module | What it is |
|--------|------------|
| `inode.mt` | Inode layer and filesystem image |
| `fdtable.mt` | Per-process file descriptor tables |
| `perms.mt` | Permission enforcement (ternary rings, not rwx bit triplets) |
| `tritfs.mt` | Integration driver tying the layers together |

### ipc/ — three ways to talk
| Module | What it is |
|--------|------------|
| `messages.mt` | Microkernel message queues: `sys_send` / `sys_recv` |
| `pipe.mt` | Unnamed byte-stream pipes (ring buffer) |
| `trit_stream.mt` | **Zero-copy trit streams**: channels modeled on physical SWCNT bus lines, where the sender's output current *is* the receiver's input current — nothing is copied because nothing moves twice |

### security/ — capabilities you can hold in nine trits
| Module | What it is |
|--------|------------|
| `capability.mt` | 9-trit capability words; attenuation (a capability can be weakened, never strengthened) and enforcement |
| `photon_cap.mt` | **Photon-schedule capabilities**: access to a fabric zone is granted by scheduling photon delivery to it — possession of the schedule IS the permission, making capabilities physically unforgeable on real hardware (the emulator models wavelengths as abstract WDM channel IDs) |

### syscall/, drivers/, userspace/
- `syscall/syscall.mt` — the dispatcher and all 16 syscall handlers; this is
  the boundary the [syscall note](../COPYING.SYSCALL-NOTE) refers to
- `drivers/tty.mt` — line-buffered TTY with formatted output
- `userspace/init.mt`, `login.mt`, `shell.mt` — the first user process,
  session management, and the shell

## Boot sequence (hosted mode)

`thatteos.mt` (repo root) is the hosted entry point: it initialises the
subsystems in dependency order — memory, interrupts, timer, TritFS, IPC,
security — starts `init`, drops privilege, and hands you the shell.
`build.sh` compiles it via manitc's LLVM backend and links the ManiT C
runtime.

## Where to go next

- Run it: [GETTING_STARTED.md](../GETTING_STARTED.md)
- The language it's written in: [manitc](https://github.com/manishthatte/manitc)
  and its [language reference](https://github.com/manishthatte/manitc/blob/main/docs/language-reference.md)
- The instruction set underneath: [T3ISA reference](https://github.com/manishthatte/manitc/blob/main/docs/t3isa-reference.md)
- Contribute a subsystem: [CONTRIBUTING.md](../CONTRIBUTING.md) — open a
  Discussion first for anything structural

---

Authored by **Manish Jagdish Thatte** · manish@manitlab.org · [manitlab.org](https://www.manitlab.org)

© Manish Jagdish Thatte, 2026
