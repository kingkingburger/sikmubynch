@echo off
chcp 65001 >/dev/null
echo ============================================
echo   SIKMUBYNCH - Hunyuan3D-2 Server Start
echo ============================================
echo.

cd /d "C:\AI\HY3D2\Hunyuan3D2_WinPortable"

set "PATH=%PATH%;%cd%\MinGit\cmd;%cd%\python_standalone\Scripts"
set "PYTHONPYCACHEPREFIX=%cd%\pycache"
set "HF_HUB_CACHE=%cd%\HuggingFaceHub"
set "HY3DGEN_MODELS=%cd%\HuggingFaceHub"

echo Loading model (2-5 min)...
echo.

cd "Hunyuan3D-2"
"..\python_standalone\python.exe" -s gradio_app.py --enable_t23d

cd ..
pause
