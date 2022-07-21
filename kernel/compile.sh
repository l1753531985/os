gcc -c ./main.c -o ./main.o && ld ./main.o -Ttext 0xc0001500 -e main -o kernel.bin && dd if=./kernel.bin of=/root/bochs/bin/hd60M.img bs=512 count=200 seek=9 conv=notrunc
