;=======================================================
; Lightweight 64-bit Linux http server in ASM
; Assemble with `nasm -f elf64 server.asm`
; Link with `ld -o asmux-server server.o`
; @author Anthony Hendrickson <ahendrickson@ausinc.com>
; @version 0.2.0
;=======================================================

        CPU     x64

        SECTION .data

        ; HTTP Header Constants
        HTTP_H_200_MSG  db      "HTTP/1.1 200 OK",                        0xa, \
                                "Content-Type: text/html; charset=UTF-8", 0xa, \
                                "Content-Encoding: UTF-8",                0xa, \
                                "Server: Asmux/0.2.0 (Linux x86_64)",     0xa, \
                                "Connection: close",                      0xa, \
                                                                          0xa
        HTTP_H_200_LEN  equ     $ - HTTP_H_200_MSG

        ; @TODO "Date: Weekday, day Month Year hh:mm:ss GMT"
        ; @TODO "Content-Length: <number>"

        ; File / Socket Variables
        filename        db      "index.html", 0
        filepntr        dq      0
        port            dw      "8000"
        sock            dq      0
        client          dq      0
        sockopt_off     dw      0
        sockopt_on      dw      1
        readlen         dq      0

        ; Server / System Constants
        MAX_CLIENTS     equ     10
        BUFLEN          equ     512
        __O_RDONLY      equ     00
        __O_WRONLY      equ     01
        __O_RDWR        equ     02
        __SOL_SOCKET    equ     1
        __SO_REUSEADDR  equ     2
        __SO_REUSEPORT  equ     15
        __STDIN         equ     0
        __STDOUT        equ     1
        __IPPROTO_TCP   equ     6
        __SOCK_STREAM   equ     1
        __AF_INET       equ     2
        __NR_read       equ     0
        __NR_write      equ     1
        __NR_open       equ     2
        __NR_close      equ     3
        __NR_brk        equ     12
        __NR_socket     equ     41
        __NR_accept     equ     43
        __NR_shutdown   equ     48      ; @TODO replace close() with shutdown() on sockets
        __NR_bind       equ     49
        __NR_listen     equ     50
        __NR_setsockopt equ     54
        __NR_gettimeofday equ   96


        SECTION .bss

        sock_address    resq    2


        SECTION .text

        %include "includes/atoi_32.asm"

        global  _start

_start:

        ; Setup Port Address (Variable)
        add     rsp, 16
        pop     rsi
        sub     rsp, 16
        call    atoi_32
        xchg    ah, al
        mov     [port], eax

        ; Setup Socket Address Struct
        push    rbp
        mov     rbp, rsp
        push	qword	0              ; sa_zero : 64-bit zero-padding
        push	dword	0x0100007F     ; sa_addr : (127.0.0.1) 32-bit IP Address (network byte order)
        push	word	[port]	       ; sa_port : (8000) 16-bit Port Address (network byte order)
        push	word	__AF_INET      ; sa_family
        mov     [sock_address], rsp    ; Pointer to socket address
        add     rsp, 16
        pop     rbp

        ; Create Socket
        mov     rax, __NR_socket
        mov	rdi, __AF_INET
        mov	rsi, __SOCK_STREAM
        mov 	rdx, __IPPROTO_TCP
        syscall
        mov     [sock], rax

        ; Reuse address and port (i.e., restarting)  -- @TODO refactor
        mov     rax, __NR_setsockopt
        mov     rdi, [sock]
        mov     rsi, __SOL_SOCKET
        mov     rdx, __SO_REUSEADDR
        mov     r10, sockopt_on
        mov     r8, dword 32
        syscall
        cmp     rax, 0
        jne     _server_close

        mov     rax, __NR_setsockopt
        mov     rdi, [sock]
        mov     rsi, __SOL_SOCKET
        mov     rdx, __SO_REUSEPORT
        mov     r10, sockopt_on
        mov     r8, dword 32
        syscall
        cmp     rax, 0
        jne     _server_close

        ; Bind
        mov	rax, __NR_bind
        mov     rdi, [sock]            ; socket
        mov     rsi, [sock_address]    ; sockaddr *
        mov     rdx, dword 32          ; 32-bit sizeof socket address
        syscall
        cmp     rax, 0
        jne     _server_close

        ; Listen
        mov	rax, __NR_listen
        mov	rdi, [sock]
        mov	rsi, MAX_CLIENTS
        syscall

_server_accept:

        SECTION .data

        reqbuf  TIMES   BUFLEN  \
                db      0
        reqlen  dw      0


        SECTION .bss

        time    resq    2


        SECTION .text

        ; Accept
        mov     rax, __NR_accept
        mov     rdi, [sock]
        mov     rsi, dword 0           ; addressof client address
        mov     rdx, dword 0           ; addressof client address size
        syscall
        cmp     rax, 0
        jle     _server_close
        mov     [client], rax

        ; Read client request into request buffer
        mov     rax, __NR_read
        mov     rdi, [client]
        mov     rsi, reqbuf
        mov     rdx, BUFLEN
        syscall
        mov     [reqlen], rax

        ; Print request headers to stdout
        mov     rax, __NR_write
        mov     rdi, __STDOUT
        mov     rsi, reqbuf
        mov     rdx, [reqlen]
        syscall

        ; @TODO handle headers from request buffer

        ; Open index.html into buffer
        mov     rax, __NR_open
        mov     rdi, filename
        mov     rsi, __O_RDONLY
        syscall
        cmp     rax, 0
        jle     _client_close           ; @TODO This should be HTTP 404
        mov     [filepntr], rax

        mov     rcx, qword 0

_send_headers:

        ; Setup time structure
        push    rbp
        mov     rbp, rsp
        push    qword 1                 ; tv_usec
        push    qword 0                 ; tv_sec
        mov     [time], rsp
        add     rsp, 16
        pop     rbp

        ; Get time
        mov     rax, __NR_gettimeofday
        mov     rdi, [time]
        mov     rsi, 0
        syscall

        ; Send response headers to client
        mov     rax, __NR_write
        mov     rdi, [client]
        mov     rsi, HTTP_H_200_MSG
        mov     rdx, HTTP_H_200_LEN
        syscall

        ; Reset readlen to 0
        mov     qword [readlen], 0

_read_html:

        SECTION .data

        resbuf  TIMES   BUFLEN  \
                db      0


        SECTION .text


        ; Read file contents into memory
        mov     rax, __NR_read
        mov     rdi, [filepntr]
        mov     rsi, resbuf
        mov     rdx, BUFLEN
        syscall

        mov     rcx, rax
        cmp     rcx, 0                  ; Check for error / end of reading/writing
        jge     _remalloc               ; Continue and maybe realloc memory
        jmp     _client_close           ; Read error: close client

_remalloc:

        cmp     rcx, 0                  ; Check EOF
        je      _write_html             ; Write output when EOF...

        add     [readlen], rcx          ; Update response content-length

        ; @TODO need to work out the kinks in this
        cmp     qword [readlen], BUFLEN
        jle     _read_html
        mov     rax, resbuf
        add     rax, [readlen]
        mov     rdi, rax
        mov     rax, __NR_brk           ; Allocate space for content in memory
        syscall
        mov     [resbuf], rax

        jmp     _read_html              ; Keep on reading!

_write_html:

        ; Write output buffer to client
        mov     rax, __NR_write
        mov     rdi, [client]
        mov     rsi, resbuf
        mov     rdx, [readlen]
        syscall

_client_close:

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
