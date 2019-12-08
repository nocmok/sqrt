format PE                                                            ; GUI
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
        sprintf, 'sprintf', \
        strcmp, 'strcmp'

import  kernel32, \
        GetCommandLine,'GetCommandLineA',\
        ExitProcess, 'ExitProcess'

section '.data' data readable writeable

fmt_out_buf db 256 dup(0)                                            ; буфер для форматированного вывода
fmt_lf_buf  db 256 dup(0)                                            ; буфер для строкового представления результата
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
eps         dq 10e-12                                                ; параметр задающий точность вычислений

section 'main' code readable executable

_main:

push ebp
mov ebp, esp

sub esp, 0x10                                                        ; оставляем место под локальные переменные
.x   equ ebp - 0x8                                                   ; для удобной работы с переменными

stdcall [GetCommandLine]                                             ; получаем строку аргументов
mov [argv_str], eax                                                  ; записываем адрес начала строки в eax
stdcall [strlen], [argv_str]                                         ; получаем длину строки аргументов
mov ecx, eax                                                         ; записываем длину строки в счетчик
inc ecx                                                              ; с учетом терминирующего нуля

mov edi, dword [argv_str]                                            ; edi будет итерироваться по строке
cld                                                                  ; устанавливаем прямое направление прохода по строке
mov al, byte ' '                                                     ; записываем символ с которым будем сравнивать каждый символ строки
repne scasb                                                          ; пропускаем первый аргумент в строке аргументов (который название запущенного исполняемого файла)
repe scasb                                                           ; пропускаем все пробелы перед первым аргументом, если они есть

dec edi                                                              ; возвращаемся на предыдущий символ
mov al, byte [edi]
test al, al                                                          ; проверяем байт на котором остановились
jne @f                                                               ; если последний байт терминирующий, то аргумент не передан

stdcall [MessageBox], 0, no_arg_str, cap, MB_OK                      ; выводим сообщение об ошибке
jmp _exit
@@:                                                                  ; иначе продолжаем выполнение

mov [argv_str], edi                                                  ; "отбрасываем" ненужный первый аргумент в строке аргументов

cinvoke strcmp, [argv_str], help_key                                 ; сравниваем строку аргументов со строкой "-h"
test eax, eax                                                        ; устанавливает ZF в 0 если строки равны
jnz @f

stdcall [MessageBox], 0, help_str, cap, MB_OK                        ; если передан ключ -h выводим окно help
jmp _exit
@@:                                                                  ; иначе продолжаем выполнение

lea edx, [.x]                                                        ; получаем адрес переменной x
stdcall [sscanf], [argv_str], lf_in_str, edx                         ; пробуем преобразовать строку к вещественному значению

test eax, eax                                                        ; устанавливает ZF в 0, если преобразование не удалось
jnz @f

ccall [wsprintf], fmt_out_buf, fail_str, [argv_str]                  ; выводим сообщение об ошибке
stdcall [MessageBox], 0, fmt_out_buf, cap, MB_OK
jmp _exit
@@:                                                                  ; иначе продолжаем выполнение

                                                                     ; проверка |x| <= 1
fld qword [.x]                                                       ; загружаем x на fpu стек
fabs                                                                 ; убираем знак
fld1                                                                 ; загружаем 1
fcomi st0, st1                                                       ; устанавливает флаг CF в 0, если 1 < |x|
jae @f

stdcall [MessageBox], 0, out_of_range_str, cap, MB_OK                ; выводим сообщение об ошибке, если выход за границы диапозона
jmp _exit
@@:                                                                  ; иначе продолжаем выполнение

                                                                     ; увеличивает x на 1
fld qword [.x]
fld1
faddp st1, st0
fst qword [.x]

sub esp, 0x8                                                         ; оставляем место под возвращаемое значение
stdcall _sqrt, [.x], [.x + 0x4], dword [eps], dword [eps + 0x4]      ; вызываем "функцию" извлечения корня
add esp, 0x10                                                        ; очищаем стек от аргументов
mov edx, esp                                                         ; записываем адрес возвращенного значения корня в edx
cinvoke sprintf, fmt_lf_buf, lf_out_str, [edx], [edx + 0x4]          ; получаем строковое представление числа
cinvoke wsprintf, fmt_out_buf, res_str, [argv_str], fmt_lf_buf       ; получаем отформатированную строку
stdcall [MessageBox], 0, fmt_out_buf, cap, MB_OK                     ; выводим результат в отформатированном виде

_exit:
mov esp, ebp
pop ebp

push 0
call [ExitProcess]

; double sqrt(double x, double eps)
_sqrt:

push ebp
mov ebp, esp

.res equ ebp + 0x18                                                  ; для удобного использования локальных переменных
.x equ ebp + 0x8
.eps equ ebp + 0x10

sub esp, 0x200                                                       ; оставляем место для сохранения состояния fpu
fsave [esp]                                                          ; сохраняем состояние fpu

                                                                     ; загружаем константы, требуемые при вычислениях
fld1
fld1
fadd st0, st0
fadd st1, st0
fdivp st1, st0                                                       ; загружаем 3/2

fld qword [.x]                                                       ; загружаем x - 1
fld1
fsubp st1, st0

fld qword [.eps]                                                     ; згружаем eps
fld1                                                                 ; загружаем итератор i

fld1                                                                 ; загружаем sum = 1 (результат вычислений)
fld1                                                                 ; загружаем delta = 1

                                                                     ; for(; |delta| > eps; ++i)

@@:
fld st0                                                              ; загружаем delta
fabs                                                                 ; опускаем знак
fcomip st4                                                           ; сравниваем с eps
jbe @f                                                               ; если |delta| <= eps выходим

fld st5                                                              ; st0 = 3/2
fsub st0, st3                                                        ; st0 = 3/2 - i
fmulp st1, st0                                                       ; delta *= (3/2 - i)
fmul st0, st4                                                        ; delta *= (x - 1)
fdiv st0, st2                                                        ; delta /= i
fadd st1, st0                                                        ; sum += delta

fld1
faddp st3, st0                                                       ; ++i
jmp @b
@@:

fxch st1                                                             ; swap(st0, st1)
fst qword [.res]                                                     ; сохраняем значение sum

frstor [esp]                                                         ; восстанавливаем состояние fpu
                                                                     ; add esp, 0x200

mov esp, ebp
pop ebp

ret