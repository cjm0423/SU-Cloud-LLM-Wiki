# sibling 리포 SU-Cloud-Wiki-Public의 mkdocs 로컬 뷰어를 8001 포트로 띄운다.
#
# mkdocs는 실행 시점의 현재 디렉터리에 있는 mkdocs.yml을 읽기 때문에,
# 반드시 public 리포 루트로 이동한 뒤 그 리포의 .venv로 실행해야 한다.
# (그러지 않으면 이 리포의 mkdocs.yml을 잘못 집어 plugin 오류가 난다.)
#
# 사용법: powershell -File scripts\serve-public.ps1

$ErrorActionPreference = "Stop"

$privateRoot = Split-Path -Parent $PSScriptRoot
$publicRoot = Join-Path (Split-Path -Parent $privateRoot) "SU-Cloud-Wiki-Public"
$python = Join-Path $publicRoot ".venv\Scripts\python.exe"

if (-not (Test-Path $publicRoot)) {
    Write-Error "public 리포를 찾을 수 없습니다: $publicRoot"
    exit 1
}
if (-not (Test-Path $python)) {
    Write-Error "가상환경을 찾을 수 없습니다: $python"
    exit 1
}

Push-Location $publicRoot
try {
    & $python -m mkdocs serve --dev-addr=127.0.0.1:8001
}
finally {
    Pop-Location
}
