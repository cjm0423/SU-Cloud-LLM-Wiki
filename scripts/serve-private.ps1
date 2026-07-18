# private 리포(이 리포)의 mkdocs 로컬 뷰어를 8000 포트로 띄운다.
#
# mkdocs는 실행 시점의 현재 디렉터리에 있는 mkdocs.yml을 읽기 때문에,
# 반드시 이 리포 루트로 이동한 뒤 이 리포의 .venv로 실행해야 한다.
# (그러지 않으면 다른 리포의 mkdocs.yml을 잘못 집어 plugin 오류가 난다.)
#
# 사용법: powershell -File scripts\serve-private.ps1

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    Write-Error "가상환경을 찾을 수 없습니다: $python"
    exit 1
}

Push-Location $root
try {
    & $python -m mkdocs serve --dev-addr=127.0.0.1:8000
}
finally {
    Pop-Location
}
