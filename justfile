
ovmf_prefix := `brew --prefix ovmf`
wanted_resolution := "x1024x768"
zig_build := "zig build -Dresolution=" + wanted_resolution
default: build

[macos]
pack:
    mkdir -p out/EFI/BOOT
    cp zig-out/bin/rouge.efi out/EFI/BOOT/BOOTX64.EFI
    if [ ! -f "disk.img" ]; then hdiutil create -fs FAT32 -size 64m -volname ROUGE disk.img && cp disk.img.dmg disk.img && rm disk.img.dmg; fi
    hdiutil attach disk.img -mountpoint /Volumes/ROUGE
    rm -rf /Volumes/ROUGE/*
    cp -r out/* /Volumes/ROUGE
    hdiutil detach /Volumes/ROUGE
    @echo "Image Successfully Packaged"

[linux]
pack:
    mkdir -p out/EFI/BOOT
    cp zig-out/bin/rouge.efi out/EFI/BOOT/BOOTX64
    if [ ! -f "disk.img" ]; then dd if=/dev/zero of=disk.img bs=1M count=64 && mkfs.vfat disk.img && mmd -i disk.img ::/EFI ::/EFI/BOOT && mcopy -i disk.img out/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI; fi
    rm -rf out
    @echo "Image Successfully Packaged"

build:
    {{zig_build}}
    just pack

build-debug:
    {{zig_build}} -Doptimize=Debug
    just pack

test:
    zig build test

debug:
    just build-debug
    qemu-system-x86_64 \
        -drive if=pflash,format=raw,readonly=on,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_VARS.fd \
        -m 512M \
        -drive format=raw,file=disk.img \
        -gdb tcp::1234 \
        -S \
        -serial stdio

run:
    just build
    qemu-system-x86_64 \
        -drive if=pflash,format=raw,readonly=on,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_VARS.fd \
        -m 512M \
        -drive format=raw,file=disk.img \
        -serial stdio
    
clean:
    rm -rf out
    rm -rf zig-out

lint:
    zig build test-lint
    zig build lint
    @echo "All Tests Passed"

check:
    zig fmt --check .
    {{zig_build}} lint
    {{zig_build}} test-lint
    {{zig_build}} test