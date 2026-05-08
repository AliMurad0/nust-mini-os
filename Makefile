all:
	nasm -f bin boot.asm -o boot.bin
	nasm -f bin kernel.asm -o kernel.bin
	cat boot.bin kernel.bin > os.bin

run:
	qemu-system-i386 -drive format=raw,file=os.bin

clean:
	rm -f boot.bin kernel.bin os.binMakefile