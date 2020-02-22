@echo off
set EMU_DIR=..\..\vs2019\x16-bin
set EMU=.\x16emu_Release.exe
REM set EMU_DIR=..\..\x16emu_win-r36
REM set EMU=.\x16emu.exe

cd %EMU_DIR%
%EMU% -prg "matriculate.prg" -debug -scale 2