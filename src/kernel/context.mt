// kernel/context.mt — THATTE-OS CPU context save/restore
// Module: T3ISA register file snapshot for context switching
//
// Demonstrates Thatte3 Claims:
//   Claim 2  — T3ISA register file (9 general + 3 special)
//   Claim 7  — Context switch: save current, restore next
//
// T3ISA register file:
//   r0 .. r8   — 9 general-purpose t27 registers (ternary word)
//   PC         — Program Counter (27-trit address)
//   SP         — Stack Pointer  (27-trit address)
//   LR         — Link Register  (return address)
//
// All values stored as int (host-width proxy for t27 balanced ternary word).

use std::io;

// ---------------------------------------------------------------------------
// CPUContext: full T3ISA register snapshot
// ---------------------------------------------------------------------------

struct CPUContext {
    pub pid: int,    // owner process
    pub r0: int, pub r1: int, pub r2: int,
    pub r3: int, pub r4: int, pub r5: int,
    pub r6: int, pub r7: int, pub r8: int,
    pub pc: int,     // program counter
    pub sp: int,     // stack pointer
    pub lr: int,     // link register (return address)
    pub valid: bool, // true = saved snapshot is live
}

// ---------------------------------------------------------------------------
// RegFile: the nine general-purpose registers, as one value
// ---------------------------------------------------------------------------
//
// Introduced 30 August 2026 because the kernel could not be built for its own
// target. `context_save` took thirteen parameters and `context_switch` took
// fifteen, and the T3 backend refuses both:
//
//     [T3ISA] `context_save` takes 13 parameters, but the T3 calling
//     convention passes arguments only in R1-R8 and has no stack argument
//     area. Pass the extra values in a struct, or split the function.
//
// LLVM has no such limit, so on the hosted backend those signatures compiled
// and ran for months. **The two backends disagreed about whether this module
// was legal at all**, and nothing said so, because nothing in this repository
// ever compiled src/ for T3.
//
// Passing the register file as one value is also the honest model: on real
// T3ISA hardware r0..r8 ARE one thing — the register file — and spreading them
// across nine argument slots to describe a snapshot of all nine was always a
// transcription of the struct that should have existed.
struct RegFile {
    pub r0: int, pub r1: int, pub r2: int,
    pub r3: int, pub r4: int, pub r5: int,
    pub r6: int, pub r7: int, pub r8: int,
}

fn empty_regfile() -> RegFile {
    return RegFile { r0: 0, r1: 0, r2: 0, r3: 0, r4: 0, r5: 0, r6: 0, r7: 0, r8: 0 };
}

fn empty_context(pid: int) -> CPUContext {
    return CPUContext { pid: pid,
        r0: 0, r1: 0, r2: 0,
        r3: 0, r4: 0, r5: 0,
        r6: 0, r7: 0, r8: 0,
        pc: 0, sp: 0, lr: 0,
        valid: false };
}

// ---------------------------------------------------------------------------
// context_save: snapshot register state for process pid
// ---------------------------------------------------------------------------

fn context_save(pid: int, pc: int, sp: int, lr: int, regs: RegFile) -> CPUContext {
    io::print("[CTX] context_save: PID=");
    io::print_int(pid);
    io::print("  PC=");
    io::print_int(pc);
    io::print("  SP=");
    io::println_int(sp);
    return CPUContext { pid: pid,
        r0: regs.r0, r1: regs.r1, r2: regs.r2,
        r3: regs.r3, r4: regs.r4, r5: regs.r5,
        r6: regs.r6, r7: regs.r7, r8: regs.r8,
        pc: pc, sp: sp, lr: lr,
        valid: true };
}

// ---------------------------------------------------------------------------
// context_restore: log the register values being loaded
// ---------------------------------------------------------------------------

fn context_restore(ctx: CPUContext) {
    if !ctx.valid {
        io::print("[CTX] context_restore: PID=");
        io::print_int(ctx.pid);
        io::println(" — no saved context (first run)");
        return;
    }
    io::print("[CTX] context_restore: PID=");
    io::print_int(ctx.pid);
    io::print("  PC=");
    io::print_int(ctx.pc);
    io::print("  SP=");
    io::print_int(ctx.sp);
    io::print("  LR=");
    io::println_int(ctx.lr);
    io::print("  r0=");  io::print_int(ctx.r0);
    io::print("  r1=");  io::print_int(ctx.r1);
    io::print("  r2=");  io::print_int(ctx.r2);
    io::print("  r3=");  io::print_int(ctx.r3);
    io::print("  r4=");  io::print_int(ctx.r4);
    io::print("  r5=");  io::println_int(ctx.r5);
    io::print("  r6=");  io::print_int(ctx.r6);
    io::print("  r7=");  io::print_int(ctx.r7);
    io::print("  r8=");  io::println_int(ctx.r8);
}

// ---------------------------------------------------------------------------
// ContextBank: 9-slot context table (one per process slot)
// ---------------------------------------------------------------------------

struct ContextBank {
    pub c0: CPUContext, pub c1: CPUContext, pub c2: CPUContext,
    pub c3: CPUContext, pub c4: CPUContext, pub c5: CPUContext,
    pub c6: CPUContext, pub c7: CPUContext, pub c8: CPUContext,
}

fn context_bank_init() -> ContextBank {
    return ContextBank {
        c0: empty_context(0), c1: empty_context(1), c2: empty_context(2),
        c3: empty_context(3), c4: empty_context(4), c5: empty_context(5),
        c6: empty_context(6), c7: empty_context(7), c8: empty_context(8),
    };
}

fn context_bank_get(bank: ContextBank, pid: int) -> CPUContext {
    if pid < 0 || pid > 8 {
        io::print("[CTX] context_bank_get: invalid PID ");
        io::print_int(pid);
        io::println(" (valid: 0-8) — returning empty context");
        return empty_context(pid);
    }
    if pid == 0 { return bank.c0; }
    elif pid == 1 { return bank.c1; }
    elif pid == 2 { return bank.c2; }
    elif pid == 3 { return bank.c3; }
    elif pid == 4 { return bank.c4; }
    elif pid == 5 { return bank.c5; }
    elif pid == 6 { return bank.c6; }
    elif pid == 7 { return bank.c7; }
    else { return bank.c8; }
}

fn context_bank_set(bank: ContextBank, ctx: CPUContext) -> ContextBank {
    let pid = ctx.pid;
    if pid < 0 || pid > 8 {
        io::print("[CTX] context_bank_set: invalid PID ");
        io::print_int(pid);
        io::println(" (valid: 0-8) — bank unchanged");
        return bank;
    }
    if pid == 0 { return ContextBank { c0: ctx, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 1 { return ContextBank { c0: bank.c0, c1: ctx, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 2 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: ctx,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 3 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: ctx,     c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 4 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: ctx,     c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 5 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: ctx,
        c6: bank.c6, c7: bank.c7, c8: bank.c8 }; }
    elif pid == 6 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: ctx,     c7: bank.c7, c8: bank.c8 }; }
    elif pid == 7 { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: ctx,     c8: bank.c8 }; }
    else { return ContextBank { c0: bank.c0, c1: bank.c1, c2: bank.c2,
        c3: bank.c3, c4: bank.c4, c5: bank.c5,
        c6: bank.c6, c7: bank.c7, c8: ctx }; }
}

// ---------------------------------------------------------------------------
// context_switch: save current, restore next
// ---------------------------------------------------------------------------

fn context_switch(bank: ContextBank, from_pid: int, to_pid: int,
                  cur_pc: int, cur_sp: int, cur_lr: int,
                  cur_regs: RegFile) -> ContextBank {
    io::print("[CTX] context_switch: PID ");
    io::print_int(from_pid);
    io::print(" -> PID ");
    io::println_int(to_pid);

    // Save current process context
    let saved = context_save(from_pid, cur_pc, cur_sp, cur_lr, cur_regs);
    let new_bank = context_bank_set(bank, saved);

    // Restore next process context
    let next_ctx = context_bank_get(new_bank, to_pid);
    context_restore(next_ctx);

    return new_bank;
}

// ---------------------------------------------------------------------------
// main: demonstrate context save/restore
// ---------------------------------------------------------------------------
