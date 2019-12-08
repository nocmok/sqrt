format PE ;GUI
use32
entry _main

include 'win32a.inc'

section '.idata' import data readable

library kernel32, 'kernel32.dll', \
        user32, 'user32.dll', \
        msvcrt,'msvcrt.dll'

import  user32, \
        MessageBox, 'MessageBoxA',\
        wsprintf,'wsprintfA'

import  msvcrt, \
        printf, 'printf', \
        sscanf, 'sscanf', \
        strlen,'strlen', \
        sprintf, 'sprintf'

import  kernel32, \
        GetCommandLine,'GetCommandLineA',\
        ExitProcess, 'ExitProcess'

section '.data' data readable writeable

fmt_out_buf db 256 dup(0) ; буфер для форматированного вывода
fmt_lf_buf  db 256 dup(0) ; буфер для строкового представления результата
lf_in_str   db '%lf', 0
lf_out_str  db '%.3lf', 0
argv_str    dd ?
fail_str    db 'error: incorrect argument: %s', 10, 13, 'type -h to get help info', 0
out_of_range_str    db 'error: value should belong to the range [-1, 1]', 0

no_arg_str  db 'error: require to provide argument', 10, 13, 'type -h to get help info', 0

help_key    db '-h', 0
help_key_sz dd 3
help_str    db 'This program calculate sqrt(x + 1) by Taylor series.', 10, 13
            db 'First arg should be floating point value in range [-1, 1].', 10, 13
            db 'The output is calculated expression with defined precision.', 0

cap         db 'Square root v1.0', 0
res_str     db 'sqrt(1 + %s) = %s', 0

section 'main' code readable executable

_main:

push ebp
mov ebp, esp

sub esp, 0x10
.x   equ ebp - 0x8        ; offset x = -0x8
.eps equ ebp - 0x10       ; offset eps = -0x10

stdcall [GetCommandLine]
mov [argv_str], eax
stdcall [strlen], [argv_str]
mov ecx, eax
inc ecx

mov edi, dword [argv_str]
cld ; set walking direction throught str
mov al, byte ' '
repne scasb               ; skip program name
repe scasb

dec edi
mov al, byte 0
scasb
jne @f

stdcall [MessageBox], 0, no_arg_str, cap, MB_OK
jmp _exit
@@:

dec edi
mov [argv_str], edi

mov esi, dword help_key
mov ecx, dword [help_key_sz]
repe cmpsb

jne @f

stdcall [MessageBox], 0, help_str, cap, MB_OK
jmp _exit
@@:

lea edx, [.x]
stdcall [sscanf], [argv_str], lf_in_str, edx

fld qword [.x]
fabs
fld1
fcomip st0, st1
jae @f

stdcall [MessageBox], 0, out_of_range_str, cap, MB_OK
jmp _exit
@@:

mov edx, eax
test edx, edx
jnz @f

ccall [wsprintf], fmt_out_buf, fail_str, [argv_str]
stdcall [MessageBox], 0, fmt_out_buf, cap, MB_OK
jmp _exit
@@:

push dword 10e-12
fld dword [esp]
fst qword [.eps]

fld qword [.x]
fld1
faddp st1, st0
fst qword [.x]

sub esp, 0x8              ; reserves place for returned value
mov edx, esp
stdcall _sqrt, [.x], [.x + 0x4], [.eps], [.eps + 0x4]

cinvoke sprintf, fmt_lf_buf, lf_out_str, [edx], [edx + 0x4]
cinvoke wsprintf, fmt_out_buf, res_str, [argv_str], fmt_lf_buf
stdcall [MessageBox], 0, fmt_out_buf, cap, MB_OK

_exit:
mov esp, ebp              ; clears stack
pop ebp

push 0
call [ExitProcess]

_sqrt:

push ebp
mov ebp, esp

.res equ ebp + 0x18       ; offset res = (0x10)
.x equ ebp + 0x8
.eps equ ebp + 0x10

sub esp, 0x200            ; reserves place for fpu context
fsave [esp]

fld1
fld1
fadd st0, st0             ; get 2 at st0
fadd st1, st0             ; get 3 at st1
fdivp st1, st0            ; get 3/2 at st0

fld qword [.x]            ; load x - 1
fld1
fsubp st1, st0

fld qword [.eps]          ; load eps
fld1                      ; load iterator
                          ; using ecx isn't reasonable as iterator involved in compuations within loop
fld1                      ; load sum = 1
fld1                      ; load delta = 1

@@:
fld st0
fabs                      ; load abs(delta)
fcomip st4
jbe @f

fld st5
fsub st0, st3
fmulp st1, st0
fmul st0, st4
fdiv st0, st2
fadd st1, st0

fld1
faddp st3, st0            ; increment iterator
jmp @b
@@:

fxch st1
fst qword [.res]

frstor [esp]
add esp, 0x200

mov esp, ebp
pop ebp

ret