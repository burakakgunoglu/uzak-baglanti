@echo off
rem Burak Akgunoglu Uzak Baglanti - derlemeyi yonetici olarak baslatir.
rem Calisma kaydi: derleme-gunlugu.txt
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0derle.ps1\"'"
