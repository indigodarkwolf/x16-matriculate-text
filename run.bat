@echo off
set EMU_DIR=..\..\vs2019\bin
set EMU=.\x16emu_Release.exe

cd %EMU_DIR%
%EMU% -prg "matriculate.prg" -debug -scale 2