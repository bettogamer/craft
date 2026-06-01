@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-local.ps1" %*
