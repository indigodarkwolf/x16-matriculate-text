@echo off

set EMU_DIR=..\..\vs2019\bin
set ASM=bin\acme\acme.exe
set ASM_OPTS=-f cbm -DMACHINE_C64=0

::set LINK=bin\cc65\bin\cl65.exe
::set LINK_OPTS=

%ASM% %ASM_OPTS% -o matriculate.prg matriculate.asm
::%LINK% %LINK_OPTS -o matriculate.prg matriculate.obj

copy matriculate.prg %EMU_DIR%
