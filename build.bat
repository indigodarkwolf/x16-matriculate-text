@echo off

set EMU_DIR=..\..\vs2019\x16-bin
set EMU=.\x16emu_Release.exe
REM set EMU_DIR=..\..\x16emu_win-r36
REM set EMU=.\x16emu.exe

set ASM=..\bin\cc65\bin\cl65.exe
set ASM_OPTS=--cpu 65c02

::set LINK=bin\cc65\bin\cl65.exe
::set LINK_OPTS=

%ASM% %ASM_OPTS% -o matriculate.prg matriculate.asm
::%LINK% %LINK_OPTS -o matriculate.prg matriculate.obj

copy matriculate.prg %EMU_DIR%
