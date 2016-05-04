; Converts a string to 32-bit integer
; The eax register is used to easily convert endian-ness...
; if needed: use `xchg ah, al`
; @param rsi Points to string
; @return eax integer conversion
atoi_32:
        xor     eax, eax
.top:
        movzx   edi, byte [rsi] ; get nth-character
        inc     rsi             ; increment n
        cmp     edi, '0'        ; check if valid
        jb      .done
        cmp     edi, '9'
        ja      .done
        sub     edi, '0'        ; convert character to number
        imul    eax, 10         ; multiply "result so far" by ten
        add     eax, edi        ; add in current digit
        jmp     .top            ; repeat until done
.done:
        ret
