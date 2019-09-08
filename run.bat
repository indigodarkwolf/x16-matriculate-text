@echo off
set EMU_DIR=..\..\vs2019\x16emu\bin
set EMU=.\x16emu_Debug.exe

cd %EMU_DIR%
%EMU% -prg "greenspace.prg" -debug