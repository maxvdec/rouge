set architecture i386:x86-64
target remote :1234

add-symbol-file zig-out/bin/rouge.efi 0x6000000

set breakpoint pending on

set disassembly-flavor intel
set print pretty on