@echo off
chcp 65001 > nul

powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned; %~dp0session_chooser.ps1" %*
