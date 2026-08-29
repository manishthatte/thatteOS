// entry_kernel.mt — the kernel's entry point
// Author: Manish Jagdish Thatte
//
// One function, and it is a module of its own so that the SAME 26 kernel
// modules can also be built as `kernel_demos` (src/kernel_demos.manifest)
// without two `fn main`s colliding in the one flat namespace a concatenated
// program has.

fn main() {
    kernel_main();
}
