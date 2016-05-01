;=======================================================
; Lightweight 64-bit Linux http server in ASM
; Assemble with `nasm -f elf64 server.asm`
; Link with `ld -o asmux-server server.o`
; @author Anthony Hendrickson <ahendrickson@ausinc.com>
; @version 0.1.0
;=======================================================

CPU     x64

SECTION .data
        sock            dq      0
        client          dq      0
        max_clients     dw      10
        buflen          equ     512
        buffer          TIMES   buflen  \
                        db      0
        reclen          db      0
        __STDIN         equ     0
        __STDOUT        equ     1
        __IPPROTO_TCP   equ     6
        __SOCK_STREAM   equ     1
        __AF_INET       equ     2
        __NR_read       equ     0
        __NR_write      equ     1
        __NR_close      equ     3
        __NR_socket     equ     41
        __NR_accept     equ     43
        __NR_shutdown   equ     48      ; @TODO replace close() with shutdown()
        __NR_bind       equ     49
        __NR_listen     equ     50

SECTION .bss
        sock_address    resq    2

SECTION .text
        global  _start
_start:
        ; Socket
        mov     rax, __NR_socket
        mov	rdi, __AF_INET
        mov	rsi, __SOCK_STREAM
        mov 	rdx, __IPPROTO_TCP
        syscall
        mov     [sock], rax

        ; Socket Address
        push	dword	0              ; sa_zero : 64-bit zero-padding
        push	dword	0x0100007F     ; sa_addr : (127.0.0.1) 32-bit IP Address (network byte order)
        push	word	0x401f	       ; sa_port : (8000) 16-bit Port Address (network byte order)
        push	word	__AF_INET      ; sa_family
        mov     [sock_address], rsp    ; Pointer to socket address

        ; Bind
        mov	rax, __NR_bind
        mov     rdi, [sock]            ; socket
        mov     rsi, [sock_address]    ; sockaddr *
        mov     rdx, dword 16          ; 32-bit sizeof socket address
        syscall
        cmp     rax, 0
        jne     _server_close

        ; Listen
        mov	rax, __NR_listen
        mov	rdi, [sock]
        mov	rsi, [max_clients]
        syscall

_server_accept:
        ; Accept
        mov     rax, __NR_accept
        mov     rdi, [sock]
        mov     rsi, dword 0           ; addressof client address
        mov     rdx, dword 0           ; addressof client address size
        syscall
        cmp     rax, 0
        jle     _server_close
        mov     [client], rax

        ; Read client request to buffer
        mov     rax, __NR_read
        mov     rdi, [client]
        mov     rsi, buffer
        mov     rdx, buflen
        syscall
        mov     [reclen], rax

        ; Write buffer to client
        mov     rax, __NR_write
        mov     rdi, [client]
        mov     rsi, buffer
        mov     rdx, [reclen]
        syscall

        ; Close Client Socket
        mov     rax, __NR_close
        mov     rdi, [client]
        syscall

        ; Loop
        jmp      _server_accept

_server_close:
        ; Close Server Socket
        mov     rax, __NR_close
        mov     rdi, [sock]
        syscall

        ; Success
        xor     rax, rax

_exit:
        ; Exit program
        pop     rbp
        mov     rdi, rax
        mov     rax, 60
        syscall
