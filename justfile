
ovmf_prefix := `brew --prefix ovmf`

default: build

pack:
    mkdir -p out/EFI/BOOT
    cp zig-out/bin/rouge.efi out/EFI/BOOT/BOOTX64.EFI
    if [ ! -f "disk.img" ]; then hdiutil create -fs FAT32 -size 64m -volname ROUGE disk.img && cp disk.img.dmg disk.img && rm disk.img.dmg; fi
    hdiutil attach disk.img -mountpoint /Volumes/ROUGE
    rm -rf /Volumes/ROUGE/*
    cp -r out/* /Volumes/ROUGE
    hdiutil detach /Volumes/ROUGE

build:
    zig build
    just pack

test:
    zig build test

run:
    just build
    qemu-system-x86_64 \
        -drive if=pflash,format=raw,readonly=on,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file={{ovmf_prefix}}/share/OVMF/OvmfX64/OVMF_VARS.fd \
        -m 512M \
        -drive format=raw,file=disk.img
    
clean:
    rm -rf out
    rm -rf zig-out