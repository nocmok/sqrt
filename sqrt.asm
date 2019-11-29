format PE
use32

include 'win32a.inc'

entry _main

; import segment

section '.idata' import data readable

library kernel32, 'kernel32.dll', \
        user32, 'user32.dll', \
        msvcrt,'msvcrt.dll'

import  user32, \
        MessageBox, 'MessageBoxA'

import  msvcrt, \
        printf, 'printf', \
        scanf, 'scanf'

import  kernel32, \
        ExitProcess, 'ExitProcess'

        ; data segment

section '.data' data readable writeable
fmt_str db '%lf', 0
three_slash_two db '1.5=%lf', 10, 13, 0
delta db 'delta=%lf', 10, 13, 0
sum db 'sum=%lf', 10, 13, 0
x_str db 'x=%lf', 10, 13, 0
eps_str db 'eps=%lf', 10, 13, 0

; code segment

section 'main' code readable executable

_main:

pushad
mov ebp, esp

; reserves space for local variables
sub esp, 0x10
.x   equ ebp - 0x8    ; offset x = -0x8
.eps equ ebp - 0x10   ; offset eps = -0x10

                      ; scanf("%f", &x)

lea eax, [.x]         ; put adress of x to eax
push eax              ; push adress of x
push fmt_str
call [scanf]
add esp, 0x8

mov [esp - 4], dword 10e-10
fld dword [esp - 4]
fst qword [.eps]

sub esp, 0x8          ; reserves place for returned value
push dword [.eps + 0x4] dword [.eps]
push dword [.x + 0x4] dword [.x]
call _sqrt            ; calls sqr
add esp, 0x10

; printf("%f", x)

pushd fmt_str
call [printf]
add esp, 0xc

mov esp, ebp          ; clears stack from local variables
popad

push 0
call [ExitProcess]

_sqrt:

push ebp
mov ebp, esp

.res equ ebp + 0x18   ; offset res = (0x10)
.x equ ebp + 0x8
.eps equ ebp + 0x10

sub esp, 0x200        ; reserves place for fpu context
fsave [esp]

fld1
fld1
fadd st0, st0         ; get 2 at st0
fadd st1, st0         ; get 3 at st1
fdivp st1, st0        ; get 3/2 at st0

fld qword [.x]        ; load x - 1
fld1
fsubp st1, st0

fld qword [.eps]      ; load eps
fld1                  ; load iterator
                      ; using ecx isn't reasonable as iterator involved in compuations within loop
fld1                  ; load sum = 1
fld1                  ; load delta = 1

_for:

; for( ;abs(delta) > epsilon; )
fld st0
fabs                  ; load abs(delta)
fcomip st4
jbe _end

fld st5
fsub st0, st3
fmulp st1, st0
fmul st0, st4
fdiv st0, st2
fadd st1, st0

fld1
faddp st3, st0        ; increment iterator
jmp _for
_end:

fxch st1
fst qword [.res]

frstor [esp]
add esp, 0x200

mov esp, ebp
pop ebp

ret
