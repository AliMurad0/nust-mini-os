; ============================================================
; NUST Mini-OS  —  Bootloader  (boot.asm)
; Compiled with: nasm -f bin boot.asm -o boot.bin
; Must be exactly 512 bytes. Last 2 bytes must be 0xAA55.
; ============================================================

[BITS 16]       ; Tell NASM: generate 16-bit x86 machine code
[ORG 0x7C00]    ; Tell NASM: code will be loaded at RAM address 0x7C00

start:
    cli                  ; Disable hardware interrupts during setup
                         ; (prevents random interrupts crashing segment setup)

    ; ── Setup Segment Registers ──────────────────────────────
    ; In 16-bit real mode, all memory access uses segment:offset pairs.
    ; We set all segments to 0 so that addresses are simple.
    xor ax, ax           ; AX = 0  (faster and smaller than: mov ax, 0)
    mov ds, ax           ; Data Segment register = 0
    mov es, ax           ; Extra Segment register = 0
    mov ss, ax           ; Stack Segment register = 0
    mov sp, 0x7C00       ; Stack Pointer = just below our bootloader code
                         ; (the x86 stack grows DOWNWARD in memory)
    sti                  ; Re-enable hardware interrupts — safe now

    call clear_screen    ; Call our screen-clear function (defined below)
    call load_kernel     ; Call our disk-read function to load the kernel
    jmp  0x0000:0x7E00   ; Far jump to kernel: CS=0x0000, IP=0x7E00
    jmp  $               ; Safety: infinite loop (this line is never reached)

; ── Function: clear_screen ──────────────────────────────────
; Uses BIOS INT 0x10, Function AH=0x06 (Scroll Screen Window Up)
; Setting AL=0 clears the entire screen region.
clear_screen:
    pusha                ; Save all general-purpose registers to stack
    mov ah, 0x06         ; BIOS function 0x06 = scroll up (0 = clear)
    mov al, 0x00         ; AL=0 means scroll 0 lines = clear entire window
    mov bh, 0x07         ; Attribute byte: white text (0x07) on black bg
    mov cx, 0x0000       ; Top-left of region: row=0, col=0
    mov dx, 0x184F       ; Bottom-right: row=24 (0x18), col=79 (0x4F)
    int 0x10             ; Call BIOS Video Interrupt
    mov ah, 0x02         ; BIOS function 0x02 = Set Cursor Position
    mov bh, 0x00         ; Video page 0
    mov dx, 0x0000       ; Move cursor to row=0, col=0 (top-left)
    int 0x10             ; Call BIOS to move cursor
    popa                 ; Restore all saved registers from stack
    ret                  ; Return to caller

; ── Function: load_kernel ───────────────────────────────────
; Uses INT 0x13 AH=0x02 to read sectors 2-5 from the boot disk
; and places them at memory address 0x7E00.
load_kernel:
    pusha
    mov ah, 0x02         ; BIOS disk function: Read Sectors
    mov al, 4            ; Read 4 sectors (4 × 512 = 2048 bytes for kernel)
    mov ch, 0            ; Cylinder number: 0 (first cylinder)
    mov cl, 2            ; Starting sector: 2 (sector 1 = bootloader itself)
    mov dh, 0            ; Head number: 0
    mov dl, 0x80         ; Drive: 0x80 = first hard disk / USB drive
    mov bx, 0x7E00       ; Destination: load kernel to RAM address 0x7E00
    int 0x13             ; Call BIOS Disk Interrupt
    jc  .error           ; CF (Carry Flag) = 1 means an error occurred
    popa
    ret
.error:
    mov si, msg_err      ; Point SI at the error message string
    call print_string    ; Print the error message
    jmp $                ; Hang here forever (infinite loop)

; ── Function: print_string ──────────────────────────────────
; Input: SI register must point to a null-terminated ASCII string
; Prints each character using INT 0x10 AH=0x0E (Teletype Output)
print_string:
    pusha

.loop:
    lodsb                ; Load byte at [DS:SI] into AL, then SI = SI + 1
    or  al, al           ; Test if AL is zero (null terminator = end of string)
    jz  .done            ; If zero: all characters printed, exit loop
    mov ah, 0x0E         ; BIOS function: Teletype Output (print 1 character)
    int 0x10             ; Print character in AL to current cursor position
    jmp .loop            ; Go back and process next character
.done:
    popa
    ret

; ── Data Section ────────────────────────────────────────────
msg_err  db "ERROR: Kernel load failed! Check USB.", 13, 10, 0
; 13 = Carriage Return (move cursor to start of line)
; 10 = Line Feed (move cursor down one line) — together = newline
; 0  = Null terminator (signals end of string to print_string)

; ── Boot Sector Padding + Magic Signature ───────────────────
times 510-($-$$) db 0   ; Fill all remaining bytes with 0x00
                         ; $ = current position, $$ = start of section
                         ; Expression ensures file is padded to exactly 510 bytes
dw 0xAA55               ; REQUIRED: Boot signature at bytes 511-512
                         ; BIOS checks for this exact pattern to confirm bootability
