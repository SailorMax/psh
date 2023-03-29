@echo off
chcp 65001 > nul

cd /D "%~dp0"
powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned; .\session_chooser.ps1" %*
