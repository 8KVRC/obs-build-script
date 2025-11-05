#requires -Version 5.1
<#
.SYNOPSIS
  obs-depsをビルドしてFFmpeg依存関係を準備
.DESCRIPTION
  OBS公式のobs-depsリポジトリをクローンし、FFmpeg用の依存関係をビルドします
#>

param(
    [string]$WorkDir = "C:\temp",
    [ValidateSet('x64', 'arm64')]
    [string]$Target = 'x64',
    [ValidateSet('Debug', 'RelWithDebInfo', 'Release', 'MinSizeRel')]
    [string]$Configuration = 'Release',
    [switch]$Clean
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

# ===== 環境チェック =====
Write-Step "環境のチェック"

# PowerShell バージョン情報の表示
Write-Info "PowerShell環境を確認中..."
Write-Host "  エディション: $($PSVersionTable.PSEdition)" -ForegroundColor Gray
Write-Host "  バージョン: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "  実行ファイル: $PSHOME\pwsh.exe" -ForegroundColor Gray

# PowerShell Core (pwsh) の確認
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell Core (pwsh) v7以降の使用を推奨します"
    Write-Info "現在のバージョン: $($PSVersionTable.PSVersion)"
    
    # pwsh.exeが利用可能か確認
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $pwshVersion = (pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>$null)
        Write-Info "PowerShell Core (pwsh) が利用可能です: バージョン $pwshVersion"
        Write-Host "`nこのスクリプトをPowerShell Core (pwsh)で実行し直すことを推奨します:" -ForegroundColor Yellow
        Write-Host "  pwsh -File .\build-scripts\01-build-obs-deps.ps1" -ForegroundColor Cyan
        
        $switchToPwsh = Read-Host "`nPowerShell Core (pwsh) で再実行しますか? (Y/N)"
        if ($switchToPwsh -eq 'Y' -or $switchToPwsh -eq 'y') {
            # pwshで再実行
            $scriptPath = $MyInvocation.MyCommand.Path
            $params = @()
            if ($WorkDir -ne "C:\temp") { $params += "-WorkDir `"$WorkDir`"" }
            if ($Target -ne 'x64') { $params += "-Target $Target" }
            if ($Configuration -ne 'Release') { $params += "-Configuration $Configuration" }
            if ($Clean) { $params += "-Clean" }
            
            $pwshCommand = "pwsh -File `"$scriptPath`" $($params -join ' ')"
            Write-Info "実行コマンド: $pwshCommand"
            
            Invoke-Expression $pwshCommand
            exit $LASTEXITCODE
        }
    } else {
        Write-Warning "PowerShell Core (pwsh) が見つかりません"
        Write-Info "https://github.com/PowerShell/PowerShell からインストールしてください"
    }
} else {
    Write-Success "PowerShell Core v$($PSVersionTable.PSVersion.Major) で実行中"
}

# Gitの確認
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Gitが見つかりません。https://git-scm.com/download/win からインストールしてください。"
}

$gitPath = (Get-Command git).Source
Write-Success "Git found: $gitPath"

# MSYS2環境で実行されているかを判定
$isMsys2Environment = $false
if ($env:MSYSTEM) {
    # MSYS2環境変数が設定されている（MSYS2ターミナルから実行）
    $isMsys2Environment = $true
    Write-Info "MSYS2環境で実行されています (MSYSTEM=$env:MSYSTEM)"
}

# PowerShellから実行している場合、MSYS2にGitがインストールされているか確認
if (-not $isMsys2Environment) {
    Write-Info "PowerShell環境で実行されています"
    
    # MSYS2がインストールされているか確認
    $msys2Path = "C:\msys64"
    $msys2GitPath = "$msys2Path\usr\bin\git.exe"
    
    if (Test-Path $msys2Path) {
        Write-Info "MSYS2が検出されました: $msys2Path"
        
        # MSYS2内にGitがインストールされているか確認
        if (Test-Path $msys2GitPath) {
            Write-Warning "MSYS2内にGitがインストールされています: $msys2GitPath"
            Write-Warning "後続のビルド処理でMSYS2を使用する際にGitが競合してエラーになる可能性があります"
            Write-Host "`n推奨対応:" -ForegroundColor Yellow
            Write-Host "  MSYS2からGitをアンインストールしてください:" -ForegroundColor Cyan
            Write-Host "  方法1: MSYS2ターミナルで実行 → pacman -R git" -ForegroundColor Gray
            Write-Host "  方法2: 環境変数PATHからC:\msys64\usr\binを削除" -ForegroundColor Gray
            
            $continue = Read-Host "`nこのまま続行しますか? (ビルドエラーが発生する可能性があります) (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                throw "ビルドを中止しました。MSYS2のGitをアンインストールしてから再実行してください"
            }
        } else {
            Write-Success "MSYS2内にGitはインストールされていません（競合なし）"
        }
    }
    
    # Windows版Gitが使用されているか確認
    if ($gitPath -notmatch "msys64") {
        Write-Success "Windows版Git for Windowsが使用されています"
    }
} else {
    # MSYS2環境で実行されている場合の警告
    if ($gitPath -match "msys64") {
        Write-Warning "MSYS2のGitが検出されました: $gitPath"
        Write-Warning "このビルドスクリプトはWindows版Git for Windowsでの使用を推奨します"
        
        # Windows版Gitがインストールされているか確認
        $windowsGitPath = "C:\Program Files\Git\cmd\git.exe"
        if (Test-Path $windowsGitPath) {
            Write-Host "`n推奨対応:" -ForegroundColor Yellow
            Write-Host "  PowerShell (pwsh) でこのスクリプトを実行してください" -ForegroundColor Cyan
            Write-Host "  （MSYS2ターミナルではなくWindows PowerShellから実行）" -ForegroundColor Cyan
            
            $continue = Read-Host "`nこのまま続行しますか? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                throw "ビルドを中止しました"
            }
        } else {
            Write-Warning "Windows版Git for Windowsがインストールされていません"
            Write-Info "https://git-scm.com/download/win からインストールすることを推奨します"
        }
    }
}

# Visual Studio環境チェック
Write-Info "Visual Studio環境を確認中..."

# VSSetup モジュールの確認
if (-not (Get-Module -ListAvailable -Name VSSetup)) {
    Write-Warning "VSSetupモジュールが見つかりません。Visual Studioの確認をスキップします"
} else {
    Import-Module VSSetup -ErrorAction SilentlyContinue
    
    $vsInstance = Get-VSSetupInstance | Select-VSSetupInstance -Latest
    
    if ($vsInstance) {
        Write-Success "Visual Studio $($vsInstance.DisplayName) が見つかりました"
        Write-Info "インストールパス: $($vsInstance.InstallationPath)"
        
        # 必要なコンポーネントのチェック
        $requiredComponents = @(
            @{ Id = 'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset'; Name = 'LLVM(clang-cl)ツールセットのMSBuildサポート' },
            @{ Id = 'Microsoft.VisualStudio.Component.VC.Llvm.Clang'; Name = 'Windows用C++ Clangコンパイラ' },
            @{ Id = 'Microsoft.VisualStudio.Workload.NativeDesktop'; Name = 'C++によるデスクトップ開発' },
            @{ Id = 'Microsoft.VisualStudio.Component.Windows11SDK.22621'; Name = 'Windows 11 SDK (10.0.22621.0)' }
        )
        
        $installedPackages = $vsInstance.Packages
        $missingComponents = @()
        
        foreach ($component in $requiredComponents) {
            $installed = $installedPackages | Where-Object { $_.Id -eq $component.Id }
            if ($installed) {
                Write-Success "$($component.Name) - インストール済み"
            } else {
                Write-Warning "$($component.Name) - 未インストール"
                $missingComponents += $component.Name
            }
        }
        
        # CMakeの確認
        if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
            Write-Warning "CMakeが見つかりません。Visual Studio Installerから追加インストールしてください"
            $missingComponents += "CMake"
        } else {
            $cmakeVersion = (cmake --version 2>&1 | Select-Object -First 1) -replace 'cmake version ', ''
            Write-Success "CMake - インストール済み (バージョン: $cmakeVersion)"
        }
        
        # Windows SDK確認
        $sdkPath = "C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0"
        if (Test-Path $sdkPath) {
            Write-Success "Windows 11 SDK (10.0.22621.0) - パス確認済み"
        } else {
            Write-Warning "Windows 11 SDK (10.0.22621.0) のパスが見つかりません"
            # 他のSDKバージョンを表示
            $sdkVersions = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\Include" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            if ($sdkVersions) {
                Write-Info "インストール済みSDK: $($sdkVersions -join ', ')"
            }
        }
        
        if ($missingComponents.Count -gt 0) {
            Write-Host "`n警告: 以下のコンポーネントが不足しています:" -ForegroundColor Yellow
            $missingComponents | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            Write-Host "`nVisual Studio Installerから上記のコンポーネントをインストールしてください。" -ForegroundColor Yellow
            
            $continue = Read-Host "`n続行しますか? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                throw "ビルドを中止しました"
            }
        } else {
            Write-Success "すべての必要なコンポーネントがインストールされています"
        }
    } else {
        Write-Warning "Visual Studioが見つかりません"
    }
}

# ===== obs-depsのクローン =====
Write-Step "obs-depsのクローン"

$obsDepsRepo = "$WorkDir\obs-deps"

# 作業ディレクトリが存在しない場合は作成
if (-not (Test-Path $WorkDir)) {
    Write-Info "作業ディレクトリを作成中: $WorkDir"
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Write-Success "作業ディレクトリを作成しました"
}

if (-not (Test-Path "$obsDepsRepo\.git")) {
    Write-Info "obs-depsをクローン中（LF改行コード設定）..."
    Push-Location $WorkDir
    
    # LF改行コードでクローン（パッチ適用のため）
    & git clone -c core.eol=lf -c core.autocrlf=true https://github.com/obsproject/obs-deps.git
    
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "obs-depsのクローンに失敗しました"
    }
    
    # クローン後もLF改行コード設定を確認（GitHub issue #258の推奨設定）
    Push-Location $obsDepsRepo
    & git config --global core.eol lf
    & git config --global core.autocrlf true
    
    # タグ 2025-08-23 にチェックアウト
    Write-Info "タグ 2025-08-23 にチェックアウト中..."
    & git checkout -f 2025-08-23
    
    Pop-Location
    
    Write-Success "obs-deps クローン完了 (tag: 2025-08-23)"
} else {
    Write-Info "obs-depsを更新中（LF改行コード設定）..."
    Push-Location $obsDepsRepo
    
    # LF改行コード設定（GitHub issue #258の推奨設定）
    & git config --global core.eol lf
    & git config --global core.autocrlf true
    
    & git fetch origin --tags
    & git checkout -f 2025-08-23
    
    Pop-Location
    Write-Success "obs-deps 更新完了 (tag: 2025-08-23)"
}


# ===== libfdk-aacビルドスクリプトの追加 =====
Write-Step "libfdk-aacビルドスクリプトの追加"

$fdkAacScript = @'
param(
    [string] $Name = 'libfdk-aac',
    [string] $Version = '2.0.3',
    [string] $Uri = 'https://github.com/mstorsjo/fdk-aac.git',
    [string] $Hash = '716f4394641d53f0d79c9ddac3fa93b03a49f278',
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Clean {
    Set-Location $Path
    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        '-DBUILD_SHARED_LIBS:BOOL=OFF'
        '-DBUILD_PROGRAMS:BOOL=OFF'
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Options = @(
        '--build', "build_${Target}"
        '--config', $Configuration
    )

    if ( $VerbosePreference -eq 'Continue' ) {
        $Options += '--verbose'
    }

    Invoke-External cmake @Options
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}
'@

$fdkAacScriptPath = "$obsDepsRepo\deps.ffmpeg\35-libfdk-aac.ps1"

# 既存のlibfdk-aacスクリプトがあるかチェック
if (-not (Test-Path $fdkAacScriptPath)) {
    $fdkAacScript | Out-File -FilePath $fdkAacScriptPath -Encoding UTF8 -Force
    Write-Success "libfdk-aacスクリプトを追加: $fdkAacScriptPath"
} else {
    Write-Success "libfdk-aacスクリプトは既に存在します"
}

# ===== FFmpegスクリプトの修正 =====
Write-Step "FFmpegスクリプトの修正"

$ffmpegScriptPath = "$obsDepsRepo\deps.ffmpeg\99-ffmpeg.ps1"
if (Test-Path $ffmpegScriptPath) {
    $ffmpegContent = Get-Content -Path $ffmpegScriptPath -Raw
    
    # --enable-libfdk-aac と --enable-nonfree が含まれているか確認
    if ($ffmpegContent -notmatch '--enable-libfdk-aac') {
        Write-Info "FFmpegスクリプトにlibfdk-aacサポートを追加中..."
        
        # '--enable-gpl' の後に追加
        $ffmpegContent = $ffmpegContent -replace "(--enable-gpl')", "`$1`n        '--enable-nonfree'`n        '--enable-libfdk-aac'"
        
        $ffmpegContent | Out-File -FilePath $ffmpegScriptPath -Encoding UTF8 -Force
        Write-Success "FFmpegスクリプトを修正しました"
    } else {
        Write-Success "FFmpegスクリプトは既にlibfdk-aacサポートを含んでいます"
    }
}

# ===== Build-Dependencies.ps1の修正（libfdk-aac保護） =====
Write-Step "Build-Dependencies.ps1の修正（libfdk-aac保護）"

$buildDepsScript = "$obsDepsRepo\Build-Dependencies.ps1"
if (Test-Path $buildDepsScript) {
    $buildDepsContent = Get-Content -Path $buildDepsScript -Raw
    
    # libfdk-aacがExcludeリストに含まれているか確認
    if ($buildDepsContent -notmatch 'fdk-aac\.lib') {
        Write-Info "Build-Dependencies.ps1にlibfdk-aac保護を追加中..."
        
        # 1. lib/*.lib の保護（fdk-aac.libを追加）
        $buildDepsContent = $buildDepsContent -replace "(Get-ChildItem \./lib -Exclude '.*?)(','cmake')", "`$1','fdk-aac.lib','libfdk-aac.lib`$2"
        
        # 2. lib/cmake の保護（fdk-aacディレクトリを追加）
        $buildDepsContent = $buildDepsContent -replace "(Get-ChildItem \./lib/cmake -Exclude ')(LibDataChannel','MbedTLS')", "`$1LibDataChannel','MbedTLS','fdk-aac'"
        
        # 3. pkgconfig削除の行をコメントアウト（fdk-aac.pc保護のため）
        # Get-ChildItem -Attribute Directory -Recurse -Include 'pkgconfig' | Remove-Item -Force -Recurse
        # → fdk-aac.pcを保護するため、個別削除に変更
        $buildDepsContent = $buildDepsContent -replace "(\s+)(Get-ChildItem -Attribute Directory -Recurse -Include 'pkgconfig' \| Remove-Item -Force -Recurse)", "`$1# `$2 (libfdk-aac保護のためコメントアウト)"
        
        $buildDepsContent | Out-File -FilePath $buildDepsScript -Encoding UTF8 -Force
        Write-Success "Build-Dependencies.ps1を修正しました（fdk-aac完全保護）"
    } else {
        Write-Success "Build-Dependencies.ps1は既にlibfdk-aac保護を含んでいます"
    }
}


# ===== obs-depsのビルド =====
Write-Step "obs-depsのビルド (FFmpeg依存関係)"

Push-Location $obsDepsRepo

# ハッシュテーブルを使用してパラメータをスプラッティング
$buildArgs = @{
    PackageName = 'ffmpeg'
    Target = $Target
    Configuration = $Configuration
}

if ($Clean) {
    $buildArgs['Clean'] = $true
}

Write-Info "ビルドコマンド: .\Build-Dependencies.ps1 -PackageName $($buildArgs.PackageName) -Target $($buildArgs.Target) -Configuration $($buildArgs.Configuration)"
Write-Info "作業ディレクトリ: $obsDepsRepo"
Write-Info "PowerShellバージョン: $($PSVersionTable.PSVersion)"
Write-Info "これには時間がかかります（30分～1時間程度）..."

# obs-depsスクリプトの存在確認
$buildScriptPath = Join-Path $obsDepsRepo "Build-Dependencies.ps1"
if (-not (Test-Path $buildScriptPath)) {
    throw "Build-Dependencies.ps1が見つかりません: $buildScriptPath"
}
Write-Success "Build-Dependencies.ps1を確認: $buildScriptPath"

try {
    # PowerShell Coreが推奨されているため、pwshで実行を試す
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Info "PowerShell Core (pwsh) でobs-depsをビルド中..."
        $buildCommand = "pwsh -File .\Build-Dependencies.ps1 -PackageName $($buildArgs.PackageName) -Target $($buildArgs.Target) -Configuration $($buildArgs.Configuration)"
        if ($Clean) {
            $buildCommand += " -Clean"
        }
        
        Write-Info "実行コマンド: $buildCommand"
        Invoke-Expression $buildCommand
        $exitCode = $LASTEXITCODE
    } else {
        Write-Info "PowerShell 5.1 でobs-depsをビルド中..."
        & .\Build-Dependencies.ps1 @buildArgs
        $exitCode = $LASTEXITCODE
    }
    
    if ($exitCode -eq 0) {
        Write-Success "obs-deps ビルド完了"
    } else {
        throw "obs-depsのビルドに失敗しました (Exit Code: $exitCode)"
    }
} catch {
    Write-Host "エラー詳細:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "スタックトレース:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    throw
} finally {
    Pop-Location
}

# ===== ビルド結果の確認 =====
Write-Step "ビルド結果の確認"

# obs-depsの出力場所（windowsディレクトリ）
$obsDepsOutput = "$obsDepsRepo\windows"

if (Test-Path $obsDepsOutput) {
    Write-Success "ビルド出力を発見: $obsDepsOutput"
    
    # obs-ffmpeg-x64 ディレクトリを探す
    $ffmpegDirs = Get-ChildItem -Path $obsDepsOutput -Directory -Filter "obs-ffmpeg-*" -ErrorAction SilentlyContinue
    
    if ($ffmpegDirs) {
        foreach ($dir in $ffmpegDirs) {
            Write-Host "`nFFmpegディレクトリ: $($dir.FullName)" -ForegroundColor Cyan
            
            # ディレクトリ構造を表示
            if (Test-Path "$($dir.FullName)\bin") {
                Write-Host "bin:" -ForegroundColor Gray
                Get-ChildItem "$($dir.FullName)\bin" -File -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object {
                    Write-Host "  $($_.Name)" -ForegroundColor Gray
                }
            }
            
            if (Test-Path "$($dir.FullName)\lib") {
                Write-Host "lib:" -ForegroundColor Gray
                Get-ChildItem "$($dir.FullName)\lib" -Filter "*.lib" -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object {
                    Write-Host "  $($_.Name)" -ForegroundColor Gray
                }
            }
            
            # FFmpeg DLLの確認
            if (Test-Path "$($dir.FullName)\bin") {
                $ffmpegDlls = Get-ChildItem "$($dir.FullName)\bin\av*.dll" -ErrorAction SilentlyContinue
                if ($ffmpegDlls) {
                    Write-Host "`nFFmpeg DLL:" -ForegroundColor Cyan
                    $ffmpegDlls | ForEach-Object {
                        Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Gray
                    }
                }
            }
        }
    }
} else {
    Write-Warning "ビルド出力が見つかりません: $obsDepsOutput"
    Write-Info "ビルドが正常に完了していることを確認してください"
}

Write-Host "`n完了！次のステップ:" -ForegroundColor Cyan
Write-Host "  .\build-scripts\02-build-all-msvc.ps1" -ForegroundColor Green
