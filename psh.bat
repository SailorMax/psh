@echo off
chcp 65001 > nul

powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned; Unblock-File -LiteralPath %~dp0session_chooser.ps1; %~dp0session_chooser.ps1" %*
