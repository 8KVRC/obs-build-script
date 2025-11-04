#requires -Version 5.1
<#
.SYNOPSIS
  MSVC環境でFDK-AAC + FFmpeg + OBS Studioをゼロからビルド
.DESCRIPTION
  vcpkgを使わず、すべてソースからMSVC環境でビルドします
  - FDK-AAC (MSVC)
  - FFmpeg (MSVC + FDK-AAC有効化)
  - OBS Studio (MSVC + カスタムFFmpeg + FDK-AAC)
#>

param(
    [string]$WorkDir = "C:\temp",
    [string]$InstallPrefix = "C:\obs-build-deps",
    [string]$FFmpegBranch = "n8.0"  # 例: n7.1 / n8.0 など
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

# Ninjaの確認（Visual Studio付属のものを優先）
$ninjaPath = $null
$ninjaPaths = @(
    "$vsPath\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
    "$vsPath\MSBuild\Microsoft\VisualStudio\v17.0\Ninja\ninja.exe"
)

foreach ($path in $ninjaPaths) {
    if (Test-Path $path) {
        $ninjaPath = $path
        Write-Success "Ninja found: $ninjaPath"
        break
    }
}

if (-not $ninjaPath) {
    $ninjaCheck = Get-Command ninja -ErrorAction SilentlyContinue
    if ($ninjaCheck) {
        $ninjaPath = $ninjaCheck.Source
        Write-Success "Ninja found in PATH: $ninjaPath"
    } else {
        Write-Warning "Ninjaが見つかりません。Ninjaをインストールするか、スクリプトはNMakeを使用します。"
    }
}

if ($ninjaPath) {
    $env:PATH = "$(Split-Path $ninjaPath);$env:PATH"
}

# MSYS2の確認（FFmpegのconfigure用）
$msys2Bash = "C:\msys64\usr\bin\bash.exe"
if (-not (Test-Path $msys2Bash)) {
    Write-Warning "MSYS2が見つかりません。FFmpegのビルドにはMSYS2が必要です。"
    Write-Info "MSYS2をインストールしてください: https://www.msys2.org/"
    $continue = Read-Host "続行しますか？ (y/n)"
    if ($continue -ne 'y') {
        exit 1
    }
}

# ===== ディレクトリ作成 =====
Write-Step "ディレクトリの準備"

$dirs = @(
    $WorkDir,
    "$WorkDir\src",
    "$WorkDir\build",
    $InstallPrefix,
    "$InstallPrefix\bin",
    "$InstallPrefix\lib",
    "$InstallPrefix\include"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Info "作成: $dir"
    }
}

# ===== Visual Studio環境設定用バッチファイル =====
$envBatPath = "$WorkDir\vs-env.bat"
@"
@echo off
call "$vcvarsPath"
set PATH=$InstallPrefix\bin;%PATH%
set INCLUDE=$InstallPrefix\include;%INCLUDE%
set LIB=$InstallPrefix\lib;%LIB%
set PKG_CONFIG_PATH=$InstallPrefix\lib\pkgconfig
"@ | Out-File -FilePath $envBatPath -Encoding ASCII

Write-Success "環境設定ファイル: $envBatPath"

# ===== ヘルパー関数 =====
function Invoke-VSCommand {
    param(
        [string]$WorkDir,
        [string]$Command
    )
    
    $script = @"
call "$envBatPath"
cd /d "$WorkDir"
$Command
"@
    
    $tempBat = [System.IO.Path]::GetTempFileName() + ".bat"
    $script | Out-File -FilePath $tempBat -Encoding ASCII
    
    Write-Host "実行中: $Command" -ForegroundColor Gray
    & cmd.exe /c $tempBat
    $exitCode = $LASTEXITCODE
    Remove-Item $tempBat -ErrorAction SilentlyContinue
    
    if ($exitCode -ne 0) {
        throw "コマンドが失敗しました (exit code: $exitCode)"
    }
}

# ===== STEP 1: FDK-AACのビルド (MSVC) =====
Write-Step "STEP 1: FDK-AACのビルド (MSVC)"

$fdkSrc = "$WorkDir\src\fdk-aac"
$fdkBuild = "$WorkDir\build\fdk-aac"

if (-not (Test-Path $fdkSrc)) {
    Write-Info "FDK-AACをクローン中..."
    Push-Location "$WorkDir\src"
    & git clone https://github.com/mstorsjo/fdk-aac.git
    Pop-Location
}

if (-not (Test-Path "$InstallPrefix\lib\fdk-aac.lib")) {
    Write-Info "FDK-AACをビルド中..."
    
    New-Item -ItemType Directory -Path $fdkBuild -Force | Out-Null
    
    # NinjaまたはNMakeを選択
    $generator = if ($ninjaPath) { "Ninja" } else { "NMake Makefiles" }
    
    $cmakeCmd = @"
cmake -G "$generator" -S "$fdkSrc" -B "$fdkBuild" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX="$InstallPrefix" ^
    -DBUILD_SHARED_LIBS=OFF ^
    -DBUILD_PROGRAMS=OFF
cmake --build "$fdkBuild" --config Release
cmake --install "$fdkBuild" --config Release
"@
    
    Invoke-VSCommand -WorkDir $fdkBuild -Command $cmakeCmd
    Write-Success "FDK-AAC ビルド完了"
} else {
    Write-Success "FDK-AAC は既にインストール済み"
}

# ===== STEP 2: x264のビルド (MSVC) =====
Write-Step "STEP 2: x264のビルド (MSVC)"

$x264Src = "$WorkDir\src\x264"

if (-not (Test-Path $x264Src)) {
    Write-Info "x264をクローン中..."
    Push-Location "$WorkDir\src"
    & git clone --depth 1 https://code.videolan.org/videolan/x264.git
    Pop-Location
}

if (-not (Test-Path "$InstallPrefix\lib\libx264.lib")) {
    Write-Info "x264をビルド中（MSVCツールチェーン）..."

    # 事前に VS 環境変数ダンプを作成（スペースを含むパス問題を避ける）
    $vsEnvTxtPath = Join-Path $WorkDir "vsvars.txt"
    & cmd.exe /c "call `"$vcvarsPath`" && set" | Out-File -FilePath $vsEnvTxtPath -Encoding ASCII

        # MSYS2内で VS 環境を取り込みつつビルドするスクリプト（変数展開なしの単一引用ヒアストリング）
        $x264BuildScript = @'
#!/usr/bin/bash
set -e

X264_SRC="__X264_SRC__"
INSTALL_PREFIX_UNIX="__INSTALL_PREFIX_UNIX__"

# 必要ツール
pacman -S --needed --noconfirm nasm || true

# VS 環境を MSYS2 に取り込む（PowerShellで事前生成したファイルを使用）
VS_ENV_TXT=/c/temp/vsvars.txt
sed -i 's/\r$//' "$VS_ENV_TXT" 2>/dev/null || true

{
    echo "set -e";
    echo 'WIN_VSPATH=';
    while IFS= read -r line; do
        case "$line" in
            *=*) ;;
            *) continue;;
        esac
        name="${line%%=*}"
        val="${line#*=}"
        # 有効なPOSIX名のみ許可
        if echo "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'; then
            low="$(echo "$name" | tr 'A-Z' 'a-z')"
            esc_sq="${val//\'/\'"'"\'}"
            if [ "$low" = "path" ]; then
                printf "WIN_VSPATH='%s'\n" "$esc_sq"
            else
                printf "export %s='%s'\n" "$name" "$esc_sq"
            fi
        fi
    done < "$VS_ENV_TXT"

    cat <<'EOS'
if [ -n "$WIN_VSPATH" ]; then
  OLDIFS="$IFS"; IFS=';'
  msys_path=""
  for p in $WIN_VSPATH; do
    [ -z "$p" ] && continue
    u=$(cygpath -u "$p" 2>/dev/null || echo "$p")
    if [ -z "$msys_path" ]; then
      msys_path="$u"
    else
      msys_path="$msys_path:$u"
    fi
  done
  IFS="$OLDIFS"
  export PATH="$msys_path:$PATH"
fi
EOS
} > /tmp/vs-env.sh
source /tmp/vs-env.sh

cd "$X264_SRC"

# MSVC でビルド（64bit 明示: nasm win64, /MACHINE:X64）
CC=cl AR=lib LD=link STRIP=: AS=nasm ASFLAGS="-f win64" \
./configure \
    --prefix="$INSTALL_PREFIX_UNIX" \
    --enable-static \
    --disable-cli \
    --extra-cflags="-MD" \
    --extra-ldflags="/NODEFAULTLIB:libcmt /MACHINE:X64"

make -j$(nproc)
make install
'@

        # プレースホルダ置換
        $x264BuildScript = $x264BuildScript.Replace('__X264_SRC__', ($x264Src -replace '\\','/'))
        $x264BuildScript = $x264BuildScript.Replace('__INSTALL_PREFIX_UNIX__', ($InstallPrefix -replace '\\','/'))
        # 事前生成ファイルを使うため VCVAR の置換不要

        $x264BuildScript | Out-File -FilePath "$WorkDir\build-x264-msvc.sh" -Encoding ASCII

    # 行末CRLF→LFに変換しておく（shebangエラー回避）
    & $msys2Bash -lc "sed -i 's/\r$//' /c/temp/build-x264-msvc.sh"

    & $msys2Bash -lc "sed -i 's/\r$//' /c/temp/vsvars.txt || true; bash /c/temp/build-x264-msvc.sh"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "x264 ビルド完了"
    } else {
        Write-Warning "x264のビルドに失敗しました。スキップします。"
    }
} else {
    Write-Success "x264 は既にインストール済み"
}

# ===== STEP 3: FFmpegのビルド (MSVC + 共有ライブラリ) =====
Write-Step "STEP 3: FFmpegのビルド (MSVC + FDK-AAC + 共有ライブラリ)"

Write-Info "FFmpegをMSVCツールチェーン(--toolchain=msvc)で共有ライブラリ(.dll)としてビルドします"
Write-Info "MSYS2はconfigure/makeの実行にのみ使用します（コンパイラはMSVCのcl/linkを使用）"

$ffmpegSrc = "$WorkDir\src\ffmpeg"
$ffmpegInstall = "$WorkDir\ffmpeg-install"

if (-not (Test-Path $ffmpegSrc)) {
    Write-Info "FFmpegをクローン中... ($FFmpegBranch)"
    Push-Location "$WorkDir\src"
    & git clone --depth 1 --branch $FFmpegBranch https://git.ffmpeg.org/ffmpeg.git
    Pop-Location
} else {
    Push-Location $ffmpegSrc
    & git fetch --all --tags --prune
    & git checkout -f $FFmpegBranch
    Pop-Location
}

function Get-ExpectedAvcodecSuffix([string]$branch) {
    if ($branch -match '^(n)?8') { return '62' }
    elseif ($branch -match '^(n)?7') { return '61' }
    else { return '*' }
}

$expectedSuffix = Get-ExpectedAvcodecSuffix $FFmpegBranch
$expectedPattern = if ($expectedSuffix -eq '*') { 'avcodec-*.dll' } else { "avcodec-$expectedSuffix.dll" }
$needFfRebuild = -not (Get-ChildItem -Path (Join-Path "$ffmpegInstall\bin" $expectedPattern) -ErrorAction SilentlyContinue)

if ($needFfRebuild) {
    Write-Info "FFmpegをビルド中（MSVCツールチェーン, $FFmpegBranch）..."

    if (Test-Path $ffmpegInstall) {
        Write-Info "旧FFmpegインストールをクリーンアップ: $ffmpegInstall"
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $ffmpegInstall
    }

    # 事前に VS 環境変数ダンプを作成（スペースを含むパス問題を避ける）
    $vsEnvTxtPath = Join-Path $WorkDir "vsvars.txt"
    & cmd.exe /c "call `"$vcvarsPath`" && set" | Out-File -FilePath $vsEnvTxtPath -Encoding ASCII

    # MSYS2用のビルドスクリプトを生成
        $ffmpegBuildScript = @'
#!/usr/bin/bash
set -e

FFMPEG_SRC="__FFMPEG_SRC__"
FFMPEG_INSTALL_UNIX="__FFMPEG_INSTALL_UNIX__"

# Visual Studio 環境変数を取り込み（PowerShellで事前生成したファイルを使用）
VS_ENV_TXT=/c/temp/vsvars.txt
sed -i 's/\r$//' "$VS_ENV_TXT" 2>/dev/null || true

echo "MSVC 環境を読み込み中..."
{
    echo "set -e";
    echo 'WIN_VSPATH=';
    while IFS= read -r line; do
        case "$line" in
            *=*) ;;
            *) continue;;
        esac
        name="${line%%=*}"
        val="${line#*=}"
        if echo "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'; then
            low="$(echo "$name" | tr 'A-Z' 'a-z')"
            esc_sq="${val//\'/\'"'"\'}"
            if [ "$low" = "path" ]; then
                printf "WIN_VSPATH='%s'\n" "$esc_sq"
            else
                printf "export %s='%s'\n" "$name" "$esc_sq"
            fi
        fi
    done < "$VS_ENV_TXT"

    cat <<'EOS'
if [ -n "$WIN_VSPATH" ]; then
  OLDIFS="$IFS"; IFS=';'
  msys_path=""
  for p in $WIN_VSPATH; do
    [ -z "$p" ] && continue
    u=$(cygpath -u "$p" 2>/dev/null || echo "$p")
    if [ -z "$msys_path" ]; then
      msys_path="$u"
    else
      msys_path="$msys_path:$u"
    fi
  done
  IFS="$OLDIFS"
  export PATH="$msys_path:$PATH"
fi
EOS
} > /tmp/vs-env.sh
source /tmp/vs-env.sh

# 依存パス
INSTALL_PREFIX_WIN="__INSTALL_PREFIX_WIN__"
IP_WIN_PATH="$(cygpath -w "$INSTALL_PREFIX_WIN")"
IP_UNIX_PATH="$(cygpath -u "$INSTALL_PREFIX_WIN")"

export PKG_CONFIG_PATH="$IP_UNIX_PATH/lib/pkgconfig:$PKG_CONFIG_PATH"

cd "$FFMPEG_SRC"

./configure \
    --target-os=win64 \
    --toolchain=msvc \
    --arch=x86_64 \
    --prefix="$FFMPEG_INSTALL_UNIX" \
    --enable-gpl \
    --enable-nonfree \
    --enable-nvenc \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-htmlpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-programs \
    --enable-libfdk-aac \
    --enable-libx264 \
    --extra-cflags="-MD -I$IP_UNIX_PATH/include -I$IP_UNIX_PATH/include/ffnvcodec" \
    --extra-ldflags="/LIBPATH:$IP_WIN_PATH\\lib /MACHINE:X64"

make -j$(nproc)
make install

echo ""
echo "ビルド完了: $FFMPEG_INSTALL_UNIX"
ls -lh "$FFMPEG_INSTALL_UNIX/bin/"*.dll || true
'@

        # プレースホルダ置換
        $ffmpegBuildScript = $ffmpegBuildScript.Replace('__FFMPEG_SRC__', ($ffmpegSrc -replace '\\','/'))
        $ffmpegBuildScript = $ffmpegBuildScript.Replace('__FFMPEG_INSTALL_UNIX__', ($ffmpegInstall -replace '\\','/'))
        $ffmpegBuildScript = $ffmpegBuildScript.Replace('__INSTALL_PREFIX_WIN__', ($InstallPrefix -replace '\\','/'))
        # 事前生成ファイルを使うため VCVAR の置換不要

        $ffmpegBuildScript | Out-File -FilePath "$WorkDir\build-ffmpeg-msvc.sh" -Encoding ASCII

    Write-Info "FFmpegをビルドしています（MSVC + make。環境により時間がかかります）..."

    & $msys2Bash -lc "sed -i 's/\r$//' /c/temp/build-ffmpeg-msvc.sh; sed -i 's/\r$//' /c/temp/vsvars.txt || true; bash /c/temp/build-ffmpeg-msvc.sh"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "FFmpeg (MSVC) ビルド完了"

        # ビルド結果を表示
        Write-Host "`nビルドされたDLL:" -ForegroundColor Cyan
        Get-ChildItem "$ffmpegInstall\bin\*.dll" | ForEach-Object { 
            Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Gray
        }
    } else {
        throw "FFmpeg(MSVC)のビルドに失敗しました"
    }
} else {
    Write-Success "FFmpeg (MSVC) は既にインストール済み"
}

# ===== STEP 4: OBS Studioのビルド =====
Write-Step "STEP 4: OBS Studioのビルド (MSVC)"

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

Write-Info "カスタムFFmpeg: $ffmpegInstall"
Write-Info "FDK-AAC: $InstallPrefix"

# 環境変数をクリアして他のFFmpegが見つからないようにする
$env:PKG_CONFIG_PATH = "$ffmpegInstall\lib\pkgconfig"
$env:FFMPEG_ROOT = $ffmpegInstall

# .deps ディレクトリを削除（OBSの古いFFmpeg依存を排除）
if (Test-Path ".deps") {
    Write-Info ".deps ディレクトリを削除中（カスタムFFmpegを強制使用）..."
    Remove-Item -Path ".deps" -Recurse -Force -ErrorAction SilentlyContinue
}

# プリセットを使わず直接設定（FFmpegパスを確実に制御するため）
$cmakeArgs = @(
    "-S", ".",
    "-B", "build_x64",
    "-G", "Visual Studio 17 2022",
    "-A", "x64",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_INSTALL_PREFIX=$obsSrc\build_x64\install",
    "-DCMAKE_PREFIX_PATH=$ffmpegInstall",
    "-DENABLE_LIBFDK=ON",
    "-DLibfdk_INCLUDE_DIR=$InstallPrefix\include",
    "-DLibfdk_LIBRARY=$InstallPrefix\lib\fdk-aac.lib",
    "-DENABLE_BROWSER=OFF",
    "-DENABLE_WEBSOCKET=ON",
    "-DENABLE_VLC=OFF",
    "-DENABLE_PLUGINS=ON",
    "-DENABLE_UI=ON"
)

# カスタムFFmpegのすべてのライブラリパスを明示的に指定
if (Test-Path "$ffmpegInstall\include\libavcodec\avcodec.h") {
    Write-Info "カスタムFFmpegを使用します: $ffmpegInstall"
    
    # FFmpeg の各コンポーネントのインポートライブラリ (.lib) とDLL (.dll) を明示的に指定
    $cmakeArgs += "-DFFmpeg_ROOT=$ffmpegInstall"
    $cmakeArgs += "-DFFmpeg_avcodec_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_avcodec_IMPLIB=$ffmpegInstall\bin\avcodec.lib"
    $cmakeArgs += "-DFFmpeg_avcodec_LIBRARY=$ffmpegInstall\bin\avcodec-62.dll"
    $cmakeArgs += "-DFFmpeg_avformat_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_avformat_IMPLIB=$ffmpegInstall\bin\avformat.lib"
    $cmakeArgs += "-DFFmpeg_avformat_LIBRARY=$ffmpegInstall\bin\avformat-62.dll"
    $cmakeArgs += "-DFFmpeg_avutil_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_avutil_IMPLIB=$ffmpegInstall\bin\avutil.lib"
    $cmakeArgs += "-DFFmpeg_avutil_LIBRARY=$ffmpegInstall\bin\avutil-60.dll"
    $cmakeArgs += "-DFFmpeg_avdevice_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_avdevice_IMPLIB=$ffmpegInstall\bin\avdevice.lib"
    $cmakeArgs += "-DFFmpeg_avdevice_LIBRARY=$ffmpegInstall\bin\avdevice-62.dll"
    $cmakeArgs += "-DFFmpeg_avfilter_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_avfilter_IMPLIB=$ffmpegInstall\bin\avfilter.lib"
    $cmakeArgs += "-DFFmpeg_avfilter_LIBRARY=$ffmpegInstall\bin\avfilter-11.dll"
    $cmakeArgs += "-DFFmpeg_swresample_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_swresample_IMPLIB=$ffmpegInstall\bin\swresample.lib"
    $cmakeArgs += "-DFFmpeg_swresample_LIBRARY=$ffmpegInstall\bin\swresample-6.dll"
    $cmakeArgs += "-DFFmpeg_swscale_INCLUDE_DIR=$ffmpegInstall\include"
    $cmakeArgs += "-DFFmpeg_swscale_IMPLIB=$ffmpegInstall\bin\swscale.lib"
    $cmakeArgs += "-DFFmpeg_swscale_LIBRARY=$ffmpegInstall\bin\swscale-9.dll"
} else {
    Write-Warning "カスタムFFmpegが見つかりません。OBS公式のFFmpegを使用します。"
}

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
            
            # カスタムFFmpegのDLLをコピー（バージョン番号に依存しないように *.dll で判定）
            if (Test-Path "$ffmpegInstall\bin") {
                $ffDlls = Get-ChildItem "$ffmpegInstall\bin\*.dll" -ErrorAction SilentlyContinue
                if ($ffDlls -and $ffDlls.Count -gt 0) {
                    Write-Info "カスタムFFmpegのDLLをコピー中..."
                    Copy-Item "$ffmpegInstall\bin\*.dll" -Destination $obsBinDir -Force -ErrorAction SilentlyContinue
                    Write-Success "FFmpeg DLLをコピーしました"

                    # 主要DLLの存在チェック
                    $needed = @('avcodec','avformat','avutil','swresample','swscale')
                    $missing = @()
                    foreach ($n in $needed) {
                        if (-not (Get-ChildItem "$obsBinDir\${n}-*.dll" -ErrorAction SilentlyContinue)) {
                            $missing += $n
                        }
                    }
                    if ($missing.Count -gt 0) {
                        Write-Info ("一部のFFmpeg DLLが見つかりませんでした: " + ($missing -join ', '))
                        Write-Info "FFmpeg のインストール内容を確認してください: $ffmpegInstall\bin"
                    } else {
                        Write-Host "`nコピーされたFFmpeg DLL:" -ForegroundColor Cyan
                        Get-ChildItem "$obsBinDir\av*.dll" | ForEach-Object {
                            Write-Host "  $($_.Name)" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Info "FFmpeg の DLL が見つかりませんでした: $ffmpegInstall\bin"
                }
            } else {
                Write-Info "FFmpeg の bin ディレクトリが存在しません: $ffmpegInstall\bin"
            }
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
- FDK-AAC: $InstallPrefix
- FFmpeg: $ffmpegInstall
- OBS Studio: $obsSrc\build_x64\rundir\Release\bin\64bit\obs64.exe

次のステップ:
1. OBSを起動
2. 設定 > 出力 > 詳細
3. 音声エンコーダで「libfdk AAC」を選択
4. ビットレートで「576」を選択

"@ -ForegroundColor Cyan

Write-Success "完了！"
