# mkdocs가 읽을 docs/ 폴더를 저장소 루트 콘텐츠에 대한
# NTFS 정션(폴더)/하드링크(파일)로 (재)생성한다.
#
# docs/ 는 실제 파일을 복사하지 않고 원본을 그대로 가리키기 때문에
# 저장소 루트(00_Inbox 등)에서 편집한 내용이 별도 동기화 없이 바로 반영된다.
# docs/ 자체는 git에 커밋하지 않는다 — 클론 직후, 또는 최상위에 새 폴더가
# 추가됐을 때 이 스크립트를 다시 실행하면 된다.
#
# 사용법: powershell -File scripts\setup-mkdocs.ps1

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"

if (-not (Test-Path $docs)) {
    New-Item -ItemType Directory -Path $docs | Out-Null
}

$dirs = @(
    "00_Inbox", "01_Concepts", "02_QnA_Archive", "03_Guides",
    "04_Meetings", "05_People", "06_Decisions", "99_Templates"
)

foreach ($d in $dirs) {
    $link = Join-Path $docs $d
    $target = Join-Path $root $d
    if (Test-Path $link) { Remove-Item $link -Force -Recurse }
    cmd /c mklink /J "$link" "$target" | Out-Null
    Write-Host "junction: docs/$d -> $d"
}

$files = @{
    "index.md"             = "README.md"
    "STATUS-OVERVIEW.md"   = "STATUS-OVERVIEW.md"
}

foreach ($name in $files.Keys) {
    $link = Join-Path $docs $name
    $target = Join-Path $root $files[$name]
    if (Test-Path $link) { Remove-Item $link -Force }
    cmd /c mklink /H "$link" "$target" | Out-Null
    Write-Host "hardlink: docs/$name -> $($files[$name])"
}

$pagesContent = @"
nav:
  - index.md
  - 01_Concepts
  - 02_QnA_Archive
  - 03_Guides
  - 04_Meetings
  - 06_Decisions
  - 05_People
  - 00_Inbox
  - 99_Templates
  - STATUS-OVERVIEW.md
"@
Set-Content -Path (Join-Path $docs ".pages") -Value $pagesContent -Encoding utf8
Write-Host "generated: docs/.pages (최상위 탭 순서)"

Write-Host "`ndocs/ 준비 완료. mkdocs serve 또는 mkdocs build 실행 가능."
