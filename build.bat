@echo off

set PROJECT=matriculate
set EMU_DIR=..\..\vs2019\x16-bin

set OBJ_DIR=obj

set ASM=..\bin\cc65\bin\ca65.exe
set LNK=..\bin\cc65\bin\cl65.exe

:: Raw binaries

%ASM% -o tables/graphics_tables.o tables/graphics_tables.asm
%LNK% -o graphics_tables.seq tables/graphics_tables.o --target none

:: Executable

%ASM% -o %PROJECT%.o %PROJECT%.asm --cpu 65C02
%LNK% -o %PROJECT%.prg -DC64 %PROJECT%.o

copy graphics_tables.seq %EMU_DIR%
copy %PROJECT%.prg %EMU_DIR%
