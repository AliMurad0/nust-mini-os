; ============================================================
; NUST Mini-OS Kernel - Complete Clean Version
; Commands: help, clear, echo, info, reboot, calc, date, time, mem
; ============================================================

[BITS 16]
[ORG 0x7E00]

    jmp kernel_start      ; FIXED: Skip data variables

; ================== GLOBAL FLAGS ==================
shift_flag    db 0
current_color db 0x07     ; used by print_string_color
terminal_color db 0x07    ; default white on black

; ================== KERNEL START ==================
kernel_start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    call install_keyboard
    sti

    call show_splash
    call clear_screen
    call print_banner
    call clear_buffer
    call print_prompt

main_loop:
    hlt
    jmp main_loop

; ================== KEYBOARD SETUP ==================
install_keyboard:
    push es
    xor ax, ax
    mov es, ax
    mov word [es:0x24], keyboard_isr
    mov word [es:0x26], 0
    pop es
    ret

; ================== KEYBOARD ISR ==================
keyboard_isr:
    pusha
    in al, 0x60

    cmp al, 0x2A
    je kb_shift_on
    cmp al, 0xAA
    je kb_shift_off

    test al, 0x80
    jnz kb_done

    cmp al, 0x1C
    je kb_enter

    cmp al, 0x0E
    je kb_backspace

    call scancode_to_ascii
    or al, al
    jz kb_done

    call add_to_buffer
    call print_char
    jmp kb_done

kb_shift_on:
    mov byte [shift_flag], 1
    jmp kb_done

kb_shift_off:
    mov byte [shift_flag], 0
    jmp kb_done

kb_enter:
    xor bx, bx
    mov bl, [buf_index]
    mov byte [input_buffer + bx], 0
    call process_command
    call clear_buffer
    call print_prompt
    jmp kb_done

kb_backspace:
    call do_backspace
    jmp kb_done

kb_done:
    mov al, 0x20
    out 0x20, al
    popa
    iret

; ================== PRINT CHAR ==================
print_char:
    mov ah, 0x0E
    mov bh, 0x00          ; FIXED: Explicitly set video page 0
    int 0x10
    ret

; ================== PRINT STRING (no color) ==================
print_string:
    pusha
ps_next:
    lodsb
    or al, al
    jz ps_end
    call print_char
    jmp ps_next
ps_end:
    popa
    ret

; ================== PRINT STRING WITH COLOR ==================
; Call with: SI = string pointer, BL = color attribute
print_string_color:
    mov [current_color], bl       ; save color BEFORE pusha
    pusha
psc_next:
    lodsb
    or al, al
    jz psc_end

    cmp al, 13                    ; carriage return
    jne psc_not_cr
    call print_char               ; FIXED: Uses print_char directly
    jmp psc_next
psc_not_cr:
    cmp al, 10                    ; line feed
    jne psc_not_lf
    call print_char               ; FIXED: Uses print_char directly
    jmp psc_next
psc_not_lf:
    mov ah, 0x09                  ; write char with attribute
    mov bh, 0x00
    mov bl, [current_color]       ; reload color from memory
    mov cx, 1
    int 0x10
    mov ah, 0x03                  ; get cursor pos
    mov bh, 0x00
    int 0x10
    inc dl                        ; move cursor right
    mov ah, 0x02
    int 0x10
    jmp psc_next
psc_end:
    popa
    ret

; ================== CLEAR SCREEN ==================
clear_screen:
    pusha
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 0x00
    mov dl, 0x00
    int 0x10
    popa
    ret

; ================== DELAY (~0.5 sec per call) ==================
delay_1sec:
    pusha
    mov ah, 0x00
    int 0x1A
    mov bx, dx
delay_wait:
    int 0x1A
    sub dx, bx            ; FIXED: Wrap-around safe timer calculation
    cmp dx, 9
    jl delay_wait
    popa
    ret

; ================== LOADING BAR ==================
print_loading_bar:
    pusha
    mov byte [bar_count], 16
bar_loop:
    mov ah, 0x09
    mov al, 0xDB              ; block character
    mov bh, 0x00
    mov bl, 0x0A              ; bright green
    mov cx, 1
    int 0x10
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    call delay_1sec
    dec byte [bar_count]
    jnz bar_loop
    popa
    ret

bar_count db 0

; ================== SPLASH SCREEN ==================
show_splash:
    pusha
    call clear_screen

    ; 5 blank lines to center vertically
    mov cx, 5
splash_blank:
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    loop splash_blank

    mov bl, 0x0B              ; cyan borders
    mov si, splash_line1
    call print_string_color
    mov si, splash_line2
    call print_string_color

    mov bl, 0x0E              ; yellow title
    mov si, splash_line3
    call print_string_color

    mov bl, 0x0F              ; white info
    mov si, splash_line4
    call print_string_color
    mov si, splash_line5
    call print_string_color

    mov bl, 0x0B              ; cyan bottom border
    mov si, splash_line6
    call print_string_color
    mov si, splash_line7
    call print_string_color

    mov bl, 0x0A              ; green loading label
    mov si, splash_line8
    call print_string_color

    call print_loading_bar

    mov bl, 0x0A
    mov si, splash_line9
    call print_string_color

    popa
    ret

; ================== BANNER AND PROMPT ==================
banner db "NUST Mini OS NT",13,10,0
prompt db "nust> ",0

print_banner:
    mov bl, 0x0E              ; yellow
    mov si, banner
    call print_string_color
    ret

print_prompt:
    mov bl, 0x0A              ; green
    mov si, prompt
    call print_string_color
    ret

; ================== INPUT BUFFER ==================
input_buffer times 128 db 0
buf_index db 0

add_to_buffer:
    xor bx, bx
    mov bl, [buf_index]
    cmp bl, 127
    jae atb_done
    mov [input_buffer + bx], al
    inc bl
    mov [buf_index], bl
atb_done:
    ret

clear_buffer:
    mov cx, 128
    mov di, input_buffer
cb_loop:
    mov byte [di], 0
    inc di
    loop cb_loop
    mov byte [buf_index], 0
    ret

do_backspace:
    xor bx, bx
    mov bl, [buf_index]
    cmp bl, 0
    je bs_done
    dec bl
    mov [buf_index], bl
    mov al, 8
    call print_char
    mov al, ' '
    call print_char
    mov al, 8
    call print_char
bs_done:
    ret

; ================== SCANCODE TABLES ==================
scancode_table:
    db 0,27,"1234567890-=",8,9
    db "qwertyuiop[]",13,0
    db "asdfghjkl;'",96,0
    db 92,"zxcvbnm,./"
    times (0x39 - ($ - scancode_table)) db 0
    db " "
    times 128-($-scancode_table) db 0

shift_table:
    db 0,27,"!@#$%^&*()_+",8,9
    db "QWERTYUIOP{}",13,0
    db "ASDFGHJKL:",34
    db 126,0
    db 92,"ZXCVBNM<>?"
    times (0x39 - ($ - shift_table)) db 0
    db " "
    times 128-($-shift_table) db 0

scancode_to_ascii:
    cmp byte [shift_flag], 1
    jne sc_normal
    mov bx, shift_table
    jmp sc_do
sc_normal:
    mov bx, scancode_table
sc_do:
    xlat
    ret

; ================== STRING COMPARE ==================
; SI = input buffer, DI = command string
; Returns AX=0 if match, AX=1 if no match
strcmp_word:
sw_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, ' '
    je sw_check
    cmp al, bl
    jne sw_ne
    cmp al, 0
    je sw_eq
    inc si
    inc di
    jmp sw_loop
sw_check:
    cmp bl, 0
    je sw_eq
sw_ne:
    mov ax, 1
    ret
sw_eq:
    xor ax, ax
    ret

; ================== COMMAND DISPATCHER ==================
process_command:
    mov si, input_buffer

    push si
    mov di, cmd_help
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_help_run

    push si
    mov di, cmd_clear
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_clear_run

    push si
    mov di, cmd_echo
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_echo_run

    push si
    mov di, cmd_info
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_info_run

    push si
    mov di, cmd_reboot
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_reboot_run

    push si
    mov di, cmd_calc
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_calc_run

    push si
    mov di, cmd_date
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_date_run

    push si
    mov di, cmd_time
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_time_run

    push si
    mov di, cmd_mem
    call strcmp_word
    pop si
    cmp ax, 0
    je cmd_mem_run

    ; no match
    mov si, msg_unknown
    call print_string
    ret

; ================== HELP ==================
cmd_help_run:
    mov si, msg_help
    call print_string
    ret

; ================== CLEAR ==================
cmd_clear_run:
    call clear_screen
    ret

; ================== ECHO ==================
cmd_echo_run:
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    mov si, input_buffer
echo_find_space:
    lodsb
    cmp al, ' '
    jne echo_find_space
    call print_string
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    ret

; ================== INFO ==================
cmd_info_run:
    mov si, msg_info
    call print_string
    ret

; ================== REBOOT ==================
cmd_reboot_run:
    jmp 0FFFFh:0000h

; ================== DATE ==================
cmd_date_run:
    mov ah, 0x04          ; BIOS RTC read date
    int 0x1A
    ; CH=century CL=year DH=month DL=day (all BCD)

    mov al, 13
    call print_char
    mov al, 10
    call print_char

    mov si, msg_date_label
    call print_string

    mov al, dl            ; day
    call print_bcd
    mov al, '/'
    call print_char
    mov al, dh            ; month
    call print_bcd
    mov al, '/'
    call print_char
    mov al, ch            ; century
    call print_bcd
    mov al, cl            ; year
    call print_bcd

    mov al, 13
    call print_char
    mov al, 10
    call print_char
    ret

; ================== TIME ==================
cmd_time_run:
    mov ah, 0x02          ; BIOS RTC read time
    int 0x1A
    ; CH=hours CL=minutes DH=seconds (all BCD)

    mov al, 13
    call print_char
    mov al, 10
    call print_char

    mov si, msg_time_label
    call print_string

    mov al, ch            ; hours
    call print_bcd
    mov al, ':'
    call print_char
    mov al, cl            ; minutes
    call print_bcd
    mov al, ':'
    call print_char
    mov al, dh            ; seconds
    call print_bcd

    mov al, 13
    call print_char
    mov al, 10
    call print_char
    ret

; ================== MEM ==================
cmd_mem_run:
    mov al, 13
    call print_char
    mov al, 10
    call print_char

    mov si, msg_mem_label
    call print_string

    int 0x12              ; BIOS returns conventional memory KB in AX
    call print_number

    mov si, msg_mem_kb
    call print_string

    mov al, 13
    call print_char
    mov al, 10
    call print_char
    ret

; ================== CALCULATOR ==================
cmd_calc_run:
    mov al, 13
    call print_char
    mov al, 10
    call print_char

    mov si, input_buffer

    ; skip "calc" word
calc_skip_cmd:
    lodsb
    cmp al, ' '
    je calc_get_num1
    cmp al, 0
    je calc_done
    jmp calc_skip_cmd

    ; skip spaces, get first number
calc_get_num1:
    lodsb
    cmp al, ' '
    je calc_get_num1
    cmp al, 0
    je calc_done
    dec si
    call parse_number
    mov bx, ax            ; BX = first number

    ; skip spaces, get operator
calc_get_op:
    lodsb
    cmp al, ' '
    je calc_get_op
    cmp al, 0
    je calc_done
    mov dl, al            ; DL = operator

    ; skip spaces, get second number
calc_get_num2:
    lodsb
    cmp al, ' '
    je calc_get_num2
    cmp al, 0
    je calc_done
    dec si
    call parse_number
    mov cx, ax            ; CX = second number

    mov ax, bx            ; AX = first number

    cmp dl, '+'
    je calc_add
    cmp dl, '-'
    je calc_sub
    cmp dl, '*'
    je calc_mul
    cmp dl, '/'
    je calc_div
    jmp calc_done

calc_add:
    add ax, cx
    jmp calc_print

calc_sub:
    sub ax, cx
    jmp calc_print

calc_mul:
    xor dx, dx
    mul cx
    jmp calc_print

calc_div:
    cmp cx, 0
    je calc_div_err
    xor dx, dx
    div cx
    jmp calc_print

calc_div_err:
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    mov bl, 0x0C          ; bright red
    mov si, msg_div_zero
    call print_string_color
    ret

calc_print:
    call print_number
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    ret

calc_done:
    ret

; ================== NUMBER PARSER ==================
; Input: SI pointing to digit string
; Output: AX = parsed number
parse_number:
    push bx
    push cx
    push dx
    xor ax, ax
    xor bx, bx

parse_num_next:
    lodsb
    cmp al, '0'
    jb parse_num_done
    cmp al, '9'
    ja parse_num_done
    sub al, '0'
    mov bl, al
    mov cx, ax
    mov ax, [temp_result]
    mov dx, 10
    mul dx
    mov [temp_result], ax
    xor bh, bh
    add ax, bx
    mov [temp_result], ax
    jmp parse_num_next

parse_num_done:
    dec si
    mov ax, [temp_result]
    mov word [temp_result], 0
    pop dx
    pop cx
    pop bx
    ret

temp_result dw 0

; ================== PRINT BCD BYTE ==================
; Input: AL = BCD byte (e.g. 0x26 prints as "26")
print_bcd:
    push ax
    push bx
    mov bl, al
    shr al, 4             ; high nibble
    add al, '0'
    call print_char
    mov al, bl
    and al, 0x0F          ; low nibble
    add al, '0'
    call print_char
    pop bx
    pop ax
    ret

; ================== PRINT NUMBER ==================
; Input: AX = number to print
print_number:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    xor cx, cx
pn_conv:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne pn_conv
pn_print:
    pop dx
    add dl, '0'
    mov al, dl
    call print_char
    loop pn_print
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ================== DATA SECTION ==================

; --- Command strings ---
cmd_help     db "help",0
cmd_clear    db "clear",0
cmd_echo     db "echo",0
cmd_info     db "info",0
cmd_reboot   db "reboot",0
cmd_calc     db "calc",0
cmd_date     db "date",0
cmd_time     db "time",0
cmd_mem      db "mem",0

; --- Messages ---
msg_help db 13,10,"Commands:",13,10
         db "  help   - show this list",13,10
         db "  clear  - clear screen",13,10
         db "  echo   - echo text",13,10
         db "  info   - OS info",13,10
         db "  calc   - calculator (e.g. calc 5 + 3)",13,10
         db "  date   - show date",13,10
         db "  time   - show time",13,10
         db "  mem    - show memory",13,10
         db "  reboot - reboot system",13,10,0

msg_info    db 13,10,"  NUST Mini OS v1.0 NT",13,10
            db "  NUST Balochistan Campus",13,10,0

msg_unknown db 13,10,"  Unknown command. Type help.",13,10,0

msg_div_zero  db "  Error: Division by zero!",13,10,0
msg_date_label db "  Date: ",0
msg_time_label db "  Time: ",0
msg_mem_label  db "  Memory: ",0
msg_mem_kb     db " KB conventional memory",13,10,0

; --- Splash screen lines ---
splash_line1 db "            ",0xC9,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBB,13,10,0
splash_line2 db "            ",0xBA,"                                      ",0xBA,13,10,0
splash_line3 db "            ",0xBA,"   N  U  S  T     M I N I  O S        ",0xBA,13,10,0
splash_line4 db "            ",0xBA,"         Version 1.0 NT                ",0xBA,13,10,0
splash_line5 db "            ",0xBA,"    NUST Balochistan Campus            ",0xBA,13,10,0
splash_line6 db "            ",0xBA,"                                      ",0xBA,13,10,0
splash_line7 db "            ",0xC8,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBC,13,10,0
splash_line8 db 13,10,"            Booting NUST Mini OS  [",0
splash_line9 db "]  Please wait...",13,10,0

times 4096-($-$$) db 0
