@echo off
chcp 65001

cd /D "%~dp0"
powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned; .\session_chooser.ps1" %*
