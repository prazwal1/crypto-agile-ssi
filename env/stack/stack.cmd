@echo off
rem Runs stack.ps1 without changing the machine execution policy.
rem Usage: stack start ^| check ^| refresh-tunnels ^| apply-patches ^| issue-offer ^| capture-baseline ^| reset-keys ^| stop
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stack.ps1" %*
