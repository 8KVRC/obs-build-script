<#
.SYNOPSIS
  MSVC環境でのビルドに必要なMSYS2パッケージをインストール
#>

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

# MSYS2の確認
$msys2Bash = "C:\msys64\usr\bin\bash.exe"
if (-not (Test-Path $msys2Bash)) {
    Write-Host "MSYS2が見つかりません。" -ForegroundColor Red
    Write-Host "以下からダウンロードしてインストールしてください:" -ForegroundColor Yellow
    Write-Host "https://www.msys2.org/" -ForegroundColor Yellow
    exit 1
}

Write-Success "MSYS2 found: $msys2Bash"

Write-Step "MSYS2パッケージのインストール"

# 必要なパッケージをインストール
$packages = @(
    'make',
    'diffutils',
    'pkg-config',
    'yasm',
    'nasm'
)

Write-Host "以下のパッケージをインストールします:" -ForegroundColor Yellow
$packages | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

$installCmd = "pacman -S --needed --noconfirm " + ($packages -join ' ')

& $msys2Bash -lc $installCmd

if ($LASTEXITCODE -eq 0) {
    Write-Success "すべてのパッケージがインストールされました"
} else {
    Write-Error "パッケージのインストールに失敗しました"
}

# ===== nv-codec-headers のインストール =====
Write-Step "nv-codec-headers のインストール (NVIDIA nvenc用)"

$InstallPrefix = "C:\obs-build-deps"
$WorkDir = "C:\temp"
$nvHeadersSrc = "$WorkDir\src\nv-codec-headers"

# ディレクトリ作成
if (-not (Test-Path "$WorkDir\src")) {
    New-Item -ItemType Directory -Path "$WorkDir\src" -Force | Out-Null
}

# nv-codec-headers をクローン
if (-not (Test-Path "$nvHeadersSrc\.git")) {
    Write-Host "nv-codec-headers をクローン中 (n13.0.19.0)..." -ForegroundColor Yellow
    
    # 既存のディレクトリがあれば削除
    if (Test-Path $nvHeadersSrc) {
        Remove-Item -Path $nvHeadersSrc -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Push-Location "$WorkDir\src"
    & git clone https://github.com/FFmpeg/nv-codec-headers.git -b n13.0.19.0
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "警告: nv-codec-headers のクローンに失敗しました。nvencは無効になります。" -ForegroundColor Yellow
        Write-Host "nvencが不要な場合は、このまま続行できます。" -ForegroundColor Gray
    }
}

# nv-codec-headers をインストール
$targetInclude = "$InstallPrefix\include\ffnvcodec"
$targetPkgConfig = "$InstallPrefix\lib\pkgconfig"

if (Test-Path "$nvHeadersSrc\.git") {
    if (-not (Test-Path "$targetInclude\nvEncodeAPI.h")) {
        Write-Host "nv-codec-headers をインストール中..." -ForegroundColor Yellow
        
        # インストール先を作成
        New-Item -ItemType Directory -Path $targetInclude -Force | Out-Null
        New-Item -ItemType Directory -Path $targetPkgConfig -Force | Out-Null
        
        # MSYS2経由でmakeを実行してインストール
        $installScript = @"
#!/usr/bin/bash
set -e

cd '$($nvHeadersSrc -replace '\\','/')'

# PREFIX を指定して .pc ファイルを生成
PREFIX='$($InstallPrefix -replace '\\','/')'
sed "s#@@PREFIX@@#`$PREFIX#" ffnvcodec.pc.in > ffnvcodec.pc

# ヘッダーをコピー
mkdir -p "`$PREFIX/include/ffnvcodec"
cp -f include/ffnvcodec/*.h "`$PREFIX/include/ffnvcodec/"

# .pc ファイルをコピー
mkdir -p "`$PREFIX/lib/pkgconfig"
cp -f ffnvcodec.pc "`$PREFIX/lib/pkgconfig/"

echo "nv-codec-headers installed to `$PREFIX"
"@
        
        $installScript | Out-File -FilePath "$WorkDir\install-nvheaders.sh" -Encoding ASCII
        
        & $msys2Bash -lc "sed -i 's/\r$//' /c/temp/install-nvheaders.sh; bash /c/temp/install-nvheaders.sh"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "nv-codec-headers インストール完了"
            
            # インストールされたファイルを確認
            if (Test-Path "$targetInclude\nvEncodeAPI.h") {
                Write-Host "`nインストールされたヘッダー:" -ForegroundColor Gray
                Get-ChildItem -Path $targetInclude -Filter "*.h" | ForEach-Object {
                    Write-Host "  $($_.Name)" -ForegroundColor Gray
                }
            }
            
            if (Test-Path "$targetPkgConfig\ffnvcodec.pc") {
                Write-Success "pkg-config ファイル: $targetPkgConfig\ffnvcodec.pc"
            }
        } else {
            Write-Host "警告: nv-codec-headers のインストールに失敗しました。nvencは無効になります。" -ForegroundColor Yellow
        }
    } else {
        Write-Success "nv-codec-headers は既にインストール済み"
    }
} else {
    Write-Host "nv-codec-headers がスキップされました。" -ForegroundColor Gray
}

Write-Host "`n準備完了！次のステップ:" -ForegroundColor Cyan
Write-Host "  .\build-scripts\00-build-all-msvc.ps1" -ForegroundColor Green
