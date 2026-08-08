# Contributing

Thank you for your interest in THATTEOS. Contributions are welcome — bug
reports, kernel modules, userspace programs, docs, tests.

## Ground rules

1. **CLA required.** Every contribution needs the one-line CLA agreement —
   see [CLA.md](CLA.md). Add this line to your PR description:

       I have read and agree to CLA.md (ManiT Individual CLA v1.0)

   PRs without it cannot be merged, however good the code. (This is what
   keeps the project's dual licensing — free AGPL + commercial — legally
   sound.)

2. **License.** The kernel is AGPL-3.0 with the
   [syscall boundary note](COPYING.SYSCALL-NOTE): programs that run ON
   THATTEOS are yours under any license; kernel code itself is copyleft.

3. **Think in threes.** THATTEOS is balanced-ternary from first principles:
   three privilege rings, three-valued logic, trit addressing. PRs that
   bolt binary idioms onto the kernel will be asked to re-think — open a
   GitHub Discussion first for anything structural.

4. **Language.** Kernel and userspace are written in ManiT — see the
   [manitc](https://github.com/manishthatte/manitc) repo for the language
   reference and compiler.

5. **Tests.** Run `bash tests/test_all.sh` before submitting; new
   subsystems need coverage there.

© Manish Jagdish Thatte, 2026
