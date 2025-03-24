echo "Compiling the bootloader"
nasm -f bin boot.asm -o boot.bin

echo "Compiling the kernel"
nasm -f bin kernel.asm -o kernel.bin

echo "Creating a disk image"
dd if=/dev/zero of=x16pros.img bs=512 count=16

dd if=boot.bin of=x16pros.img conv=notrunc
dd if=kernel.bin of=x16pros.img bs=512 seek=1 conv=notrunc
echo "Done."

qemu-system-i386 -hda x16pros.img
