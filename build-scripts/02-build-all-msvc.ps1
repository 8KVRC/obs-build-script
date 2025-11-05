#requires -Version 5.1
<#
.SYNOPSIS
  MSVC環境でFDK-AAC + FFmpeg + OBS Studioをゼロからビルド
.DESCRIPTION
  vcpkgを使わず、すべてソースからMSVC環境でビルドします
  obs-depsでビルドした依存関係を使用します
  - FDK-AAC (MSVC)
  - FFmpeg (MSVC + FDK-AAC有効化)
  - OBS Studio (MSVC + カスタムFFmpeg + FDK-AAC)
#>

param(
    [string]$WorkDir = "C:\temp"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Yellow
}

# UTF-8 (no BOM) でファイルを書き出すヘルパー
function Set-ContentUtf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Value
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

# ===== 環境チェック =====
Write-Step "環境のチェック"

# Visual Studio 2022の検出
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vsWhere)) {
    throw "Visual Studio 2022が見つかりません。インストールしてください。"
}

$vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    throw "Visual Studio 2022 (C++ tools)が見つかりません。"
}

$vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
Write-Success "Visual Studio 2022: $vsPath"

# CMakeの検出（Visual Studio付属のものを優先）
$cmakePath = $null
$cmakePaths = @(
    "$vsPath\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
    "C:\Program Files\CMake\bin\cmake.exe",
    "C:\Program Files (x86)\CMake\bin\cmake.exe"
)

foreach ($path in $cmakePaths) {
    if (Test-Path $path) {
        $cmakePath = $path
        Write-Success "CMake found: $cmakePath"
        break
    }
}

if (-not $cmakePath) {
    $cmakeCheck = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmakeCheck) {
        $cmakePath = $cmakeCheck.Source
        Write-Success "CMake found in PATH: $cmakePath"
    } else {
        throw "CMakeが見つかりません。Visual Studio InstallerでCMakeコンポーネントをインストールするか、https://cmake.org/ からダウンロードしてください。"
    }
}

# PATHに追加
$env:PATH = "$(Split-Path $cmakePath);$env:PATH"

# Gitの確認
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Gitが見つかりません。https://git-scm.com/download/win からインストールしてください。"
}
Write-Success "Git found"



# ===== obs-depsの検出 =====
Write-Step "obs-depsの検出"

# obs-depsのビルド結果を探す
$ObsDepsPath = $null
if (Test-Path "$WorkDir\obs-deps\windows") {
    $ffmpegDirs = Get-ChildItem -Path "$WorkDir\obs-deps\windows" -Directory -Filter "obs-ffmpeg-*" -ErrorAction SilentlyContinue
    if ($ffmpegDirs) {
        $ObsDepsPath = $ffmpegDirs[0].FullName
        Write-Success "obs-deps発見: $ObsDepsPath"
        
        # 主要ファイルの確認
        if (Test-Path "$ObsDepsPath\lib\fdk-aac.lib") {
            Write-Success "✓ FDK-AAC"
        }
        if (Test-Path "$ObsDepsPath\bin\avcodec*.dll") {
            Write-Success "✓ FFmpeg"
        }
    }
}

if (-not $ObsDepsPath) {
    Write-Warning "obs-depsが見つかりません"
    Write-Info "obs-depsをビルドしてください:"
    Write-Info "  .\build-scripts\01-build-obs-deps.ps1"
    throw "obs-depsが必要です"
}

# ===== ディレクトリ作成 =====
Write-Step "ディレクトリの準備"

$dirs = @(
    $WorkDir,
    "$WorkDir\src",
    "$WorkDir\build"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Info "作成: $dir"
    }
}

# ===== 依存関係の確認 =====
Write-Step "依存関係の確認"

Write-Host "`nFFmpeg DLL:" -ForegroundColor Cyan
Get-ChildItem "$ObsDepsPath\bin\av*.dll" -ErrorAction SilentlyContinue | ForEach-Object { 
    Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Gray
}

# ===== OBS Studioのビルド =====
Write-Step "OBS Studioのビルド"

$obsSrc = "$WorkDir\obs-studio"

if (-not (Test-Path $obsSrc)) {
    Write-Info "OBS Studioをクローン中..."
    Push-Location $WorkDir
    & git clone --recursive https://github.com/obsproject/obs-studio.git
    Pop-Location
}

Push-Location $obsSrc

# 特定バージョンをチェックアウト
Write-Info "OBS Studio 32.0.2をチェックアウト..."
& git fetch --all --tags
& git checkout -f 32.0.2
& git submodule update --init --recursive

# 古いビルドとCMakeキャッシュを完全削除
Write-Info "古いビルドディレクトリとキャッシュを完全削除..."
Get-ChildItem -Path . -Directory -Filter "build*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".deps" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".cache" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "CMakeCache.txt" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "CMakeFiles" -Recurse -Force -ErrorAction SilentlyContinue

# ===== OBS ソースコードへのパッチ適用 =====
Write-Info "OBS ソースコードにFDK-AAC関連のパッチを適用します (320kbps→576kbps / カットオフ20kHz)"

# 文字列置換ユーティリティ
function Set-TextReplace {
    param(
        [Parameter(Mandatory=$true)][string]$File,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [switch]$Regex
    )
    if (-not (Test-Path $File)) { return $false }
    $content = Get-Content -Path $File -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return $false }
    $new = if ($Regex) { [System.Text.RegularExpressions.Regex]::Replace($content, $Pattern, $Replacement) } else { $content.Replace($Pattern, $Replacement) }
    if ($new -ne $content) {
        Set-ContentUtf8NoBom -Path $File -Value $new
        Write-Success "パッチ適用: $File"
        return $true
    } else {
        Write-Info "変更なし: $File"
        return $false
    }
}

# 1) 320 → 576 の置換（候補ファイルを順に試す）
$settingsCandidates = @()
$settingsCandidates += (Join-Path $obsSrc 'frontend\settings\OBSBasicSettings.cpp')
$settingsCandidates += (Join-Path $obsSrc 'UI\window-basic-settings.cpp')
$settingsCandidates += (Join-Path $obsSrc 'UI\frontend-plugins\frontend-tools\output-timer.cpp')

$settingsFileUsed = $null
foreach ($cand in $settingsCandidates) {
    if (Test-Path $cand) { $settingsFileUsed = $cand; break }
}

if ($settingsFileUsed) {
    Write-Info "ビットレート上限の修正対象: $settingsFileUsed"
    # bash版は単純に 's/320/576/g' だったため、同じ方針で置換
    [void](Set-TextReplace -File $settingsFileUsed -Pattern '320' -Replacement '576')
} else {
    Write-Info 'ビットレート設定ファイルが見つかりませんでした（スキップ）'
}

# 2) obs-libfdk.c に AACENC_BANDWIDTH を追加（idempotent）
$libfdkFile = Join-Path $obsSrc 'plugins\obs-libfdk\obs-libfdk.c'
if (Test-Path $libfdkFile) {
    $text = Get-Content -Path $libfdkFile -Raw
    if ($text -notmatch 'AACENC_BANDWIDTH') {
        $lines = $text -split "\r?\n"
        $idx = -1
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'CHECK_LIBFDK\(.*AACENC_AFTERBURNER') { $idx = $i; break }
        }
        if ($idx -ge 0) {
            # 元行のインデントを流用
            $indent = ($lines[$idx] -match '^(\s*)') | Out-Null; $indent = $Matches[1]
            $insert = "$indent" + 'CHECK_LIBFDK(aacEncoder_SetParam(enc->fdkhandle, AACENC_BANDWIDTH, 20000));'
            $newLines = @()
            $newLines += $lines[0..$idx]
            $newLines += $insert
            if ($idx + 1 -lt $lines.Count) { $newLines += $lines[($idx+1)..($lines.Count-1)] }
            Set-ContentUtf8NoBom -Path $libfdkFile -Value ($newLines -join "`r`n")
            Write-Success "AACENC_BANDWIDTH を追加: $libfdkFile"
        } else {
            Write-Info 'AACENC_AFTERBURNER の直後が見つからず、帯域設定の自動挿入をスキップしました'
        }
    } else {
        Write-Info 'AACENC_BANDWIDTH は既に設定済み（スキップ）'
    }
} else {
    Write-Info 'obs-libfdk.c が見つからず、帯域設定の追加をスキップしました'
}

# ※既にチェックアウト直後に削除済みなのでここでは不要

# CMake設定
Write-Info "CMakeを設定中..."
Write-Info "使用するobs-deps: $ObsDepsPath"

# 環境変数設定
$env:PKG_CONFIG_PATH = "$ObsDepsPath\lib\pkgconfig"
$env:FFMPEG_ROOT = $ObsDepsPath

# .deps ディレクトリを削除（OBSの古いFFmpeg依存を排除）
if (Test-Path ".deps") {
    Write-Info ".deps ディレクトリを削除中（カスタムFFmpegを強制使用）..."
    Remove-Item -Path ".deps" -Recurse -Force -ErrorAction SilentlyContinue
}

# CMake引数を設定
$cmakeArgs = @(
    "-S", ".",
    "-B", "build_x64",
    "-G", "Visual Studio 17 2022",
    "-A", "x64",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_INSTALL_PREFIX=$obsSrc\build_x64\install",
    "-DCMAKE_PREFIX_PATH=$ObsDepsPath",
    "-DFFmpeg_ROOT=$ObsDepsPath",
    "-DENABLE_LIBFDK=ON",
    "-DLibfdk_INCLUDE_DIR=$ObsDepsPath\include",
    "-DLibfdk_LIBRARY=$ObsDepsPath\lib\fdk-aac.lib",
    "-DENABLE_BROWSER=OFF",
    "-DENABLE_WEBSOCKET=ON",
    "-DENABLE_VLC=OFF",
    "-DENABLE_PLUGINS=ON",
    "-DENABLE_UI=ON"
)

Write-Info "CMake実行中..."
$ErrorActionPreference = 'Continue'
$cmakeOutput = & cmake @cmakeArgs 2>&1
$cmakeExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

if ($cmakeExitCode -eq 0) {
    Write-Success "CMake設定成功"
    
    # CMakeCache.txt から FFmpeg の検出結果を表示
    $cacheFile = "$obsSrc\build_x64\CMakeCache.txt"
    if (Test-Path $cacheFile) {
        Write-Host "`nFFmpeg 検出結果:" -ForegroundColor Cyan
        $ffmpegVars = Select-String -Path $cacheFile -Pattern "FFmpeg_av.*_(LIBRARY|IMPLIB|INCLUDE_DIR):" | ForEach-Object { $_.Line }
        foreach ($line in $ffmpegVars) {
            if ($line -match "avcodec-(\d+)\.dll|avformat-(\d+)\.dll|avutil-(\d+)\.dll") {
                Write-Host "  $line" -ForegroundColor Green
            } else {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "`nCMake設定に失敗しました (Exit Code: $cmakeExitCode)" -ForegroundColor Red
    Write-Host "`nCMake出力:" -ForegroundColor Yellow
    $cmakeOutput | ForEach-Object { Write-Host $_ }
    throw "CMake configuration failed"
}

Pop-Location

Write-Success "OBS Studio の設定が完了しました"

# ===== ビルド実行 =====
Write-Step "OBS Studioのビルド"

$msbuildPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1

if ($msbuildPath) {
    Write-Info "MSBuildでビルド中..."
    
    & $msbuildPath "$obsSrc\build_x64\obs-studio.sln" `
        -p:Configuration=Release `
        -p:Platform=x64 `
        -maxcpucount `
        -verbosity:minimal
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "OBS Studio ビルド成功！"
        
        $obsExe = "$obsSrc\build_x64\rundir\Release\bin\64bit\obs64.exe"
        $obsBinDir = "$obsSrc\build_x64\rundir\Release\bin\64bit"
        
        if (Test-Path $obsExe) {
            Write-Host "`n実行ファイル: $obsExe" -ForegroundColor Green
            Write-Host "サイズ: $([math]::Round((Get-Item $obsExe).Length / 1MB, 2)) MB" -ForegroundColor Gray
        }
    } else {
        throw "OBS Studioのビルドに失敗しました"
    }
} else {
    throw "MSBuildが見つかりません"
}

# ===== 完了 =====
Write-Step "すべてのビルドが完了しました！"

Write-Host @"

ビルド結果:
- obs-deps (FDK-AAC, x264, FFmpeg等): $ObsDepsPath
- OBS Studio: $obsSrc\build_x64\rundir\Release\bin\64bit\obs64.exe

次のステップ:
1. OBSを起動
2. 設定 > 出力 > 詳細
3. 音声エンコーダで「libfdk AAC」を選択
4. ビットレートで「576」を選択

"@ -ForegroundColor Cyan

Write-Success "完了！"
