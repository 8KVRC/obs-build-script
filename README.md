# FFmpeg + OBS Studio ビルド (Windows/PowerShell)# FFmpeg + OBS Studio ビルド (Windows/PowerShell)



Windows環境でlibfdk-aacを有効にしたFFmpegとOBS Studioを**MSVCツールチェーン**でビルドするプロジェクトです。Windows環境でlibfdk-aacを有効にしたFFmpegとOBS Studioを**MSVCツールチェーン**でビルドするプロジェクトです。



## 概要## 概要



このプロジェクトは、Visual Studio 2022のMSVCコンパイラを使用して以下をソースからビルドします：このプロジェクトは、Visual Studio 2022のMSVCコンパイラを使用して以下をソースからビルドします：



- **FDK-AAC** - 高品質AACエンコーダー（静的ライブラリ）- **FDK-AAC** - 高品質AACエンコーダー（静的ライブラリ）

- **x264** - H.264ビデオエンコーダー（静的ライブラリ）- **x264** - H.264ビデオエンコーダー（静的ライブラリ）

- **FFmpeg** - メディアライブラリ（**共有ライブラリ .dll**形式、FDK-AAC/x264有効）- **FFmpeg** - メディアライブラリ（**共有ライブラリ .dll**形式、FDK-AAC/x264有効）

- **OBS Studio** - 配信・録画ソフト（カスタムFFmpeg統合、FDK-AAC 576kbps対応）- **OBS Studio** - 配信・録画ソフト（カスタムFFmpeg統合、FDK-AAC 576kbps対応）



## 特徴## 特徴



✅ **MSVC環境でのフルビルド** - すべてVisual Studio 2022でコンパイル  ✅ **MSVC環境でのフルビルド** - すべてVisual Studio 2022でコンパイル  

✅ **FDK-AAC統合** - 高品質AACエンコーディング（576kbps上限パッチ適用）  ✅ **FDK-AAC統合** - 高品質AACエンコーディング（576kbps上限パッチ適用）  

✅ **OBS Studio自動パッチ** - FDK-AACビットレート上限を320→576kbpsに拡張  ✅ **OBS Studio自動パッチ** - FDK-AACビットレート上限を320→576kbpsに拡張  

✅ **帯域幅設定** - AACENC_BANDWIDTH=20kHzを自動設定  ✅ **帯域幅設定** - AACENC_BANDWIDTH=20kHzを自動設定  

✅ **共有ライブラリ形式** - FFmpegは.dll形式でビルド（OBSとの統合に最適）  ✅ **共有ライブラリ形式** - FFmpegは.dll形式でビルド（OBSとの統合に最適）  

✅ **PowerShell自動化** - ワンコマンドで全自動ビルド✅ **PowerShell自動化** - ワンコマンドで全自動ビルド



## 前提条件## 前提条件



### 必須### 必須



- **Windows 10/11** (64bit)- **Windows 10/11** (64bit)

- **Visual Studio 2022** - C++デスクトップ開発ツールを含む- **Visual Studio 2022** - C++デスクトップ開発ツールを含む

- **MSYS2** - FFmpegのconfigure/makeツール用（ビルドツールのみ使用）- **MSYS2** - FFmpegのconfigure/makeツール用（ビルドツールのみ使用）

- **Git** - ソースコードの取得用- **Git** - ソースコードの取得用

- 空きディスク容量: 15GB以上- 空きディスク容量: 15GB以上

- 所要時間: 2-3時間- 所要時間: 2-3時間



### インストール手順### インストール手順



#### 1. Visual Studio 2022または、個別にビルド:



1. [Visual Studio 2022](https://visualstudio.microsoft.com/ja/downloads/)をダウンロード#### 1. Visual Studio 2022

2. インストール時に**「C++によるデスクトップ開発」**を選択

3. CMakeコンポーネントも含める```bash



#### 2. MSYS21. [Visual Studio 2022](https://visualstudio.microsoft.com/ja/downloads/)をダウンロードbash build-scripts/01-setup-msys2.sh



1. https://www.msys2.org/ からMSYS2をダウンロード2. インストール時に**「C++によるデスクトップ開発」**を選択bash build-scripts/02-install-dependencies.sh

2. インストーラーを実行（デフォルト: `C:\msys64`）

3. インストール完了（次のステップで自動セットアップします）3. CMakeコンポーネントも含めるbash build-scripts/03-build-fdk-aac.sh



## ビルド手順（PowerShell）bash build-scripts/04-build-ffmpeg.sh



### 手順1: MSYS2の準備#### 2. MSYS2bash build-scripts/05-build-obs.sh       # OBS Studio（Visual Studio 2022が無い場合はNinjaで自動ビルド）



PowerShellを起動し、プロジェクトディレクトリに移動：bash build-scripts/99-create-package.sh  # FFmpeg配布パッケージ作成



```powershell1. https://www.msys2.org/ からMSYS2をダウンロード```

cd c:\dev\ffmpeg-build-script

```2. インストーラーを実行（デフォルト: `C:\msys64`）



MSYS2に必要なツールをインストール：3. インストール後、必要なツールをセットアップ### 2-B. MSVC + vcpkg で FFmpeg/fdk-aac をビルドし、OBS を Visual Studio でビルド



```powershell

.\build-scripts\00-setup-msys2-for-msvc.ps1

```## ビルド手順1) vcpkg をセットアップして MSVC 用の FFmpeg と fdk-aac を用意



このスクリプトは以下をMSYS2にインストールします：

- make

- diffutils### 手順1: MSYS2の準備```bash

- pkg-config

- yasmbash build-scripts/02a-setup-vcpkg-msvc.sh

- nasm

PowerShellを**管理者権限**で起動し、以下を実行：```

### 手順2: すべてをビルド（推奨）



PowerShellで以下のコマンドを実行するだけで、すべてが自動ビルドされます：

```powershell2) OBS のビルド（Visual Studio が見つかれば自動で VS ジェネレーターを使用します。vcpkg は自動検出）

```powershell

.\build-scripts\00-build-all-msvc.ps1cd c:\dev\ffmpeg-build-script

```

.\build-scripts\00-setup-msys2-for-msvc.ps1```bash

**カスタマイズオプション：**

```bash build-scripts/05-build-obs.sh

```powershell

.\build-scripts\00-build-all-msvc.ps1 ````

    -WorkDir "C:\temp" `

    -InstallPrefix "C:\obs-build-deps" `このスクリプトは以下をインストールします：

    -FFmpegBranch "n7.1"

```- make> メモ: vcpkg のインストール先は既定で `C:\vcpkg`（`/c/vcpkg`）を想定しています。変更している場合は `VCPKG_ROOT` を環境変数で指定してください。



パラメータ説明：- diffutils

- `WorkDir`: 作業ディレクトリ（デフォルト: `C:\temp`）

- `InstallPrefix`: 依存ライブラリのインストール先（デフォルト: `C:\obs-build-deps`）- pkg-config### 3. ビルド内容

- `FFmpegBranch`: FFmpegのブランチ/タグ（デフォルト: `n7.1`）

- yasm

### ビルドプロセスの詳細

- nasm各スクリプトの役割:

スクリプトは以下の順序で自動実行します：



#### STEP 1: FDK-AACのビルド

### 手順2: すべてをビルド- **01-setup-msys2.sh**: MSYS2環境のセットアップとビルドツールのインストール

- GitHubからクローン: `mstorsjo/fdk-aac`

- CMakeでビルド（静的ライブラリ）- **02-install-dependencies.sh**: FFmpeg用の依存ライブラリのインストール（x264, x265, fontconfig等）

- インストール先: `C:\obs-build-deps\lib\fdk-aac.lib`

PowerShellで以下を実行：- **03-build-fdk-aac.sh**: FDK-AACのソースからビルド（静的ライブラリ）

#### STEP 2: x264のビルド

- **04-build-ffmpeg.sh**: FFmpegのビルド（FDK-AAC、fontconfig内包）

- GitHubからクローン: `videolan/x264`

- MSVC + MSYS2 configureでビルド```powershell- **05-build-obs.sh**: OBS StudioのCMake設定（ビルドはVisual Studioで実行）

- 静的ライブラリとして生成

.\build-scripts\00-build-all-msvc.ps1- **99-create-package.sh**: FFmpeg配布パッケージの作成（ZIP）

#### STEP 3: FFmpegのビルド

```

- FFmpeg公式リポジトリからクローン（指定ブランチ）

- `--toolchain=msvc` でビルド（MSVCのcl/linkを使用）## 出力先

- **共有ライブラリ（.dll）**として生成

- FDK-AACとx264を有効化**オプションパラメータ：**

- インストール先: `C:\temp\ffmpeg-install\`

### FFmpegビルド成果物

生成されるDLL：

- `avcodec-*.dll````powershell

- `avformat-*.dll`

- `avutil-*.dll`.\build-scripts\00-build-all-msvc.ps1 `- **ビルドディレクトリ**: `~/ffmpeg_build/`

- `avdevice-*.dll`

- `avfilter-*.dll`    -WorkDir "C:\temp" `  - `bin/ffmpeg.exe`, `ffprobe.exe`, `ffplay.exe`

- `swresample-*.dll`

- `swscale-*.dll`    -InstallPrefix "C:\obs-build-deps" `  - `lib/*.a` (静的ライブラリ)



#### STEP 4: OBS Studioのビルド    -FFmpegBranch "n7.1"  - `include/` (ヘッダーファイル)



- OBS Studio 32.0.2をクローン```

- 自動パッチ適用：

  - ビットレート上限 320→576kbps- **配布パッケージ**: `~/ffmpeg-fdk-aac-windows-x64/`

  - `AACENC_BANDWIDTH=20000`（カットオフ20kHz）

- カスタムFFmpeg（STEP 3でビルドしたもの）を使用- `WorkDir`: 作業ディレクトリ（デフォルト: `C:\temp`）  - 実行ファイル + 必要なDLL + ライセンスファイル

- Visual Studio 2022でビルド

- ビルド先: `C:\temp\obs-studio\build_x64\`- `InstallPrefix`: 依存ライブラリのインストール先（デフォルト: `C:\obs-build-deps`）  - ZIP: `~/ffmpeg-fdk-aac-windows-x64.zip`



## 出力先- `FFmpegBranch`: FFmpegのブランチ/タグ（デフォルト: `n7.1`）



### FDK-AAC & x264### OBS Studio（オプション）



```### ビルドプロセスの詳細

C:\obs-build-deps\

├── bin\- **CMake設定**: `/c/temp/obs-studio/build_x64/`

├── lib\

│   ├── fdk-aac.libスクリプトは以下の順序で自動実行します：- **ビルド後の実行ファイル**: `/c/temp/obs-studio/build_x64/rundir/Release/bin/64bit/obs64.exe`

│   └── libx264.lib

└── include\

```

#### STEP 1: FDK-AACのビルド⚠️ **注意**:

### FFmpeg

- GitHubからクローン: `mstorsjo/fdk-aac`- Visual Studio 2022 がインストールされている場合でも、FFmpeg が MinGW でビルドされた静的ライブラリ（`.a`）の場合は、MSVC と混在リンクできないため自動的に Ninja/MinGW でビルドします。

```

C:\temp\ffmpeg-install\- CMakeでビルド（静的ライブラリ）- FFmpeg と fdk-aac を MSVC でビルドしたい場合は、上記「2-B」の vcpkg ルートを使用してください（`.lib`/`.dll` が生成され、OBS の VS ビルドと互換）。

├── bin\

│   ├── avcodec-62.dll- インストール先: `C:\obs-build-deps\lib\fdk-aac.lib`- VS が見つからない場合は自動で Ninja にフォールバックします。

│   ├── avcodec.lib

│   ├── avformat-62.dll

│   ├── avformat.lib

│   ├── avutil-60.dll#### STEP 2: x264のビルド## 動作確認

│   ├── avutil.lib

│   ├── (その他のDLL)- GitHubからクローン: `videolan/x264`

│   └── (インポートライブラリ)

├── lib\- MSVC + MSYS2 configureでビルド### FFmpegの確認

│   └── pkgconfig\

└── include\- 静的ライブラリとして生成

    ├── libavcodec\

    ├── libavformat\```bash

    └── (その他のヘッダー)

```#### STEP 3: FFmpegのビルドcd ~/ffmpeg_build/bin



### OBS Studio- FFmpeg公式リポジトリからクローン（指定ブランチ）



```- `--toolchain=msvc` でビルド（MSVCのcl/linkを使用）# バージョン確認

C:\temp\obs-studio\build_x64\

├── rundir\Release\bin\64bit\- **共有ライブラリ（.dll）**として生成./ffmpeg.exe -version

│   ├── obs64.exe          # OBS実行ファイル

│   ├── avcodec-62.dll     # カスタムFFmpeg DLL- FDK-AACとx264を有効化

│   ├── avformat-62.dll

│   └── (その他のDLL)- インストール先: `C:\temp\ffmpeg-install\`# FDK-AAC確認

└── obs-studio.sln         # Visual Studioソリューション

```./ffmpeg.exe -encoders | grep libfdk_aac



## 動作確認生成されるDLL：



### OBS Studioの起動- `avcodec-*.dll`# fontconfig確認



PowerShellで以下を実行：- `avformat-*.dll`./ffmpeg.exe -filters | grep drawtext



```powershell- `avutil-*.dll````

cd C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit

.\obs64.exe- `avdevice-*.dll`

```

- `avfilter-*.dll`### Windows CMD/PowerShellでの確認

### FDK-AAC設定

- `swresample-*.dll`

1. OBSを起動

2. **設定** → **出力** → **録画/配信**- `swscale-*.dll````cmd

3. **詳細**モードに切り替え

4. **音声エンコーダ**で **「libfdk AAC」** を選択cd C:\msys64\home\ユーザー名\ffmpeg-fdk-aac-windows-x64

5. **ビットレート**で **576kbps** が選択可能（パッチ適用済み）

#### STEP 4: OBS Studioのビルド

### FFmpegの確認

- OBS Studio 32.0.2をクローンffmpeg.exe -version

PowerShellで以下を実行：

- 自動パッチ適用：ffmpeg.exe -encoders | findstr fdk

```powershell

cd C:\temp\ffmpeg-install\bin  - ビットレート上限 320→576kbps```

.\ffmpeg.exe -version

.\ffmpeg.exe -encoders | Select-String "fdk"  - `AACENC_BANDWIDTH=20000`（カットオフ20kHz）

```

- カスタムFFmpeg（STEP 3でビルドしたもの）を使用## 有効な機能

期待される出力：

- Visual Studio 2022でビルド

```

A..... libfdk_aac           Fraunhofer FDK AAC (codec aac)- ビルド先: `C:\temp\obs-studio\build_x64\`このビルドで有効になっている主な機能:

```



## 有効な機能

## 出力先### ビデオコーデック

### ビデオコーデック

- ✅ **libx264** (H.264/AVC)

- ✅ **libx264** (H.264/AVC) - MSVC静的ライブラリ

### FDK-AAC & x264- ✅ **libx265** (H.265/HEVC)

### オーディオコーデック

- ✅ **libaom** (AV1)

- ✅ **libfdk_aac** (FDK-AAC) - 高品質AAC、576kbps対応

```- ✅ **libsvtav1** (AV1高速版)

### FFmpeg構成オプション

C:\obs-build-deps\- ✅ **libvpx** (VP9)

```

--target-os=win64├── bin\- ✅ **nvenc** (NVIDIA GPUエンコーダー)

--toolchain=msvc

--arch=x86_64├── lib\

--enable-gpl

--enable-nonfree│   ├── fdk-aac.lib### オーディオコーデック

--enable-shared

--enable-libfdk-aac│   └── libx264.lib- ✅ **libfdk_aac** (FDK-AAC - 高品質AAC)

--enable-libx264

```└── include\- ✅ **libmp3lame** (MP3)



## ライセンス```- ✅ **libopus** (Opus)



⚠️ **重要な注意事項**- ✅ **libvorbis** (Vorbis)



- **libfdk-aac**: Fraunhofer FDK AAC License（非自由ライセンス）### FFmpeg

- **FFmpeg**: GPL v2 + nonfree（FDK-AAC統合のため）

- **OBS Studio**: GPL v2### その他の機能

- **x264**: GPL v2

```- ✅ **fontconfig** (字幕・テキスト描画)

### 配布制限

C:\temp\ffmpeg-install\- ✅ **libass** (ASS/SSA字幕)

このビルドは `--enable-nonfree` オプションでビルドされています：

├── bin\- ✅ **OpenSSL** (HTTPS対応)

❌ **libfdk-aacは商用配布に制限があります**  

❌ **外部への再配布は禁止**  │   ├── avcodec-62.dll- ✅ **RTMP** (ライブストリーミング)

✅ **個人利用・グループ内使用のみ**

│   ├── avcodec.lib

詳細はFraunhofer FDK AAC Licenseを参照してください。

│   ├── avformat-62.dll## ライセンス

## トラブルシューティング

│   ├── avformat.lib

### Q1: "Visual Studio 2022が見つかりません"

│   ├── avutil-60.dll- **libfdk-aac**: Fraunhofer FDK AAC License（非自由ライセンス）

**A**: Visual Studio Installerで「C++によるデスクトップ開発」がインストールされているか確認してください。

│   ├── avutil.lib- **FFmpeg**: GPL v2/LGPL v2.1/nonfree

### Q2: "CMakeが見つかりません"

│   ├── (その他のDLL)- **OBS Studio**: GPLライセンス

**A**: Visual Studio InstallerでCMakeコンポーネントを追加するか、[cmake.org](https://cmake.org/)から単体でインストールしてください。

│   └── (インポートライブラリ)

### Q3: "MSYS2が見つかりません"

├── lib\⚠️ **重要な注意事項**:

**A**: MSYS2を `C:\msys64` にインストールしてください。別の場所にインストールした場合は、スクリプト内の `$msys2Bash` パスを修正してください。

│   └── pkgconfig\- このビルドは `--enable-nonfree` オプションでビルドされています

### Q4: FFmpegのビルドが失敗する

└── include\- **libfdk-aacは商用配布に制限があります**

**A**: 

- MSYS2で必要なツール（nasm, yasm）がインストールされているか確認    ├── libavcodec\- **グループ内使用限定、外部への再配布は禁止**

- `00-setup-msys2-for-msvc.ps1` を再実行

- Visual Studio環境変数が正しく設定されているか確認    ├── libavformat\- 詳細は配布パッケージ内の `LICENSE-FFmpeg.md` と `NOTICE-FDK-AAC.txt` を参照してください



### Q5: OBSでlibfdk_aacが表示されない    └── (その他のヘッダー)



**A**: ```## トラブルシューティング

- OBSのビルドログで「Libfdk found」を確認

- `C:\temp\obs-studio\build_x64\CMakeCache.txt` で `Libfdk_LIBRARY` の値を確認

- FFmpegのDLLが正しくコピーされているか確認（`rundir\Release\bin\64bit\` 内）

### OBS Studio### Q1: "pacman: command not found"

### Q6: 576kbpsが選択できない



**A**: ビルドログで「パッチ適用」メッセージを確認してください。OBSソースの該当ファイルが見つからなかった可能性があります。

```**A**: MSYS2 MSYSではなく、**MSYS2 MINGW64**を起動してください。

### Q7: x264のビルドが失敗する

C:\temp\obs-studio\build_x64\

**A**:

- MSYS2にnasmがインストールされているか確認: `pacman -S nasm`├── rundir\Release\bin\64bit\### Q2: "configure: error: fontconfig not found"

- Visual Studio環境変数が正しく読み込まれているか確認

- x264は64bit明示でビルドされます（`-f win64`, `/MACHINE:X64`）│   ├── obs64.exe          # OBS実行ファイル



### Q8: PowerShellのエラー: "スクリプトの実行が無効になっています"│   ├── avcodec-62.dll     # カスタムFFmpeg DLL**A**: 手順書の `--extra-libs` オプションに完全な依存ライブラリリストが含まれています。`04-build-ffmpeg.sh` の内容を確認してください。



**A**: PowerShellの実行ポリシーを変更してください：│   ├── avformat-62.dll



```powershell│   └── (その他のDLL)### Q3: ビルド中にメモリ不足エラー

# 管理者権限のPowerShellで実行

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser└── obs-studio.sln         # Visual Studioソリューション

```

```**A**: 並列ビルド数を減らしてください:

または、一時的に実行する場合：

```bash

```powershell

PowerShell -ExecutionPolicy Bypass -File .\build-scripts\00-build-all-msvc.ps1## 動作確認# 04-build-ffmpeg.sh 内の make コマンドを変更

```

make -j2  # または make -j1

## 技術詳細

### OBS Studioの起動```

### MSVCツールチェーンについて



このプロジェクトでは、FFmpegとOBS Studioの互換性を確保するため、以下の方針でビルドします：

```powershell### Q4: DLLエラー（Windows実行時）

1. **FDK-AAC**: CMake + MSVC（静的ライブラリ）

2. **x264**: configure + MSVC（MSYS2環境でconfigure実行、コンパイラはMSVC）cd C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit

3. **FFmpeg**: `--toolchain=msvc` + 共有ライブラリ（.dll形式）

4. **OBS Studio**: Visual Studio 2022 + カスタムFFmpeg.\obs64.exe**A**: `libgcc_s_seh-1.dll` と `libwinpthread-1.dll` が `ffmpeg.exe` と同じフォルダにあることを確認してください。



### なぜMSVCツールチェーンなのか```



- **ABI互換性**: すべてMSVCでビルドすることで、ランタイムライブラリの不一致を回避## 詳細ドキュメント

- **OBS Studio統合**: OBS StudioはVisual Studioでビルドされるため、FFmpegもMSVCでビルドすることで問題を最小化

- **共有ライブラリ**: FFmpegを.dll形式でビルドすることで、OBSとの動的リンクを実現### FDK-AAC設定



### MSYS2の役割より詳細な情報は以下を参照してください:



MSYS2はコンパイラとしては使用せず、以下の目的でのみ使用します：1. OBSを起動



- FFmpeg/x264の`configure`スクリプト実行2. **設定** → **出力** → **録画/配信**- **手順書 (1).md**: FFmpegの完全ビルド手順（静的リンク、DLL同梱方式）

- `make`によるビルドプロセス制御

- Unix系ツール（sed, grep等）の提供3. **詳細**モードに切り替え- **DOC.md**: OBS StudioへのカスタムFFmpeg統合手順



実際のコンパイルはすべてMSVCの`cl.exe`と`link.exe`で行われます。4. **音声エンコーダ**で **「libfdk AAC」** を選択- **BUILD_GUIDE.md**: ビルドガイド（docs/）



### PowerShellスクリプトの構成5. **ビットレート**で **576kbps** が選択可能（パッチ適用済み）- **TROUBLESHOOTING.md**: トラブルシューティング（docs/）



```- **LICENSE_INFO.md**: ライセンス情報（docs/）

build-scripts/

├── 00-setup-msys2-for-msvc.ps1  # MSYS2の初期セットアップ### FFmpegの確認

└── 00-build-all-msvc.ps1         # すべての自動ビルド

    ├── FDK-AACビルド## サポート

    ├── x264ビルド

    ├── FFmpegビルド```powershell

    └── OBS Studioビルド

```cd C:\temp\ffmpeg-install\bin質問や問題がある場合は、まずトラブルシューティングセクションを確認してください。



## 参考情報.\ffmpeg.exe -version```



- [FFmpeg公式](https://ffmpeg.org/).\ffmpeg.exe -encoders | Select-String "fdk"```

- [OBS Studio公式](https://obsproject.com/)

- [FDK-AAC (mstorsjo)](https://github.com/mstorsjo/fdk-aac)```

- [x264公式](https://www.videolan.org/developers/x264.html)

- [Visual Studio 2022](https://visualstudio.microsoft.com/ja/vs/)## 出力先

- [MSYS2公式](https://www.msys2.org/)

- [PowerShell ドキュメント](https://docs.microsoft.com/ja-jp/powershell/)期待される出力：



## サポート```- FFmpeg: `output/ffmpeg-dist/`



質問や問題がある場合は、まずトラブルシューティングセクションを確認してください。A..... libfdk_aac           Fraunhofer FDK AAC (codec aac)- OBS Studio: `output/obs-dist/`


```

## ライセンス

## 有効な機能

- libfdk-aac: Fraunhofer FDK AAC License (非自由ライセンス)

### ビデオコーデック- FFmpeg: GPL/LGPLライセンス

- ✅ **libx264** (H.264/AVC) - MSVC静的ライブラリ- OBS Studio: GPLライセンス



### オーディオコーデック**注意**: libfdk-aacは商用利用に制限があります。詳細は [docs/LICENSE_INFO.md](docs/LICENSE_INFO.md) を参照してください。

- ✅ **libfdk_aac** (FDK-AAC) - 高品質AAC、576kbps対応

## トラブルシューティング

### FFmpeg構成オプション

ビルドエラーが発生した場合は [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) を参照してください。
```
--target-os=win64
--toolchain=msvc
--arch=x86_64
--enable-gpl
--enable-nonfree
--enable-shared
--enable-libfdk-aac
--enable-libx264
```

## ライセンス

⚠️ **重要な注意事項**

- **libfdk-aac**: Fraunhofer FDK AAC License（非自由ライセンス）
- **FFmpeg**: GPL v2 + nonfree（FDK-AAC統合のため）
- **OBS Studio**: GPL v2
- **x264**: GPL v2

### 配布制限

このビルドは `--enable-nonfree` オプションでビルドされています：

❌ **libfdk-aacは商用配布に制限があります**  
❌ **外部への再配布は禁止**  
✅ **個人利用・グループ内使用のみ**

詳細はFraunhofer FDK AAC Licenseを参照してください。

## トラブルシューティング

### Q1: "Visual Studio 2022が見つかりません"

**A**: Visual Studio Installerで「C++によるデスクトップ開発」がインストールされているか確認してください。

### Q2: "CMakeが見つかりません"

**A**: Visual Studio InstallerでCMakeコンポーネントを追加するか、[cmake.org](https://cmake.org/)から単体でインストールしてください。

### Q3: "MSYS2が見つかりません"

**A**: MSYS2を `C:\msys64` にインストールしてください。別の場所にインストールした場合は、スクリプト内の `$msys2Bash` パスを修正してください。

### Q4: FFmpegのビルドが失敗する

**A**: 
- MSYS2で必要なツール（nasm, yasm）がインストールされているか確認
- `00-setup-msys2-for-msvc.ps1` を再実行
- Visual Studio環境変数が正しく設定されているか確認

### Q5: OBSでlibfdk_aacが表示されない

**A**: 
- OBSのビルドログで「Libfdk found」を確認
- `C:\temp\obs-studio\build_x64\CMakeCache.txt` で `Libfdk_LIBRARY` の値を確認
- FFmpegのDLLが正しくコピーされているか確認（`rundir\Release\bin\64bit\` 内）

### Q6: 576kbpsが選択できない

**A**: ビルドログで「パッチ適用」メッセージを確認してください。OBSソースの該当ファイルが見つからなかった可能性があります。

### Q7: x264のビルドが失敗する

**A**:
- MSYS2にnasmがインストールされているか確認: `pacman -S nasm`
- Visual Studio環境変数が正しく読み込まれているか確認
- x264は64bit明示でビルドされます（`-f win64`, `/MACHINE:X64`）

## 技術詳細

### MSVCツールチェーンについて

このプロジェクトでは、FFmpegとOBS Studioの互換性を確保するため、以下の方針でビルドします：

1. **FDK-AAC**: CMake + MSVC（静的ライブラリ）
2. **x264**: configure + MSVC（MSYS2環境でconfigure実行、コンパイラはMSVC）
3. **FFmpeg**: `--toolchain=msvc` + 共有ライブラリ（.dll形式）
4. **OBS Studio**: Visual Studio 2022 + カスタムFFmpeg

### なぜMSVCツールチェーンなのか

- **ABI互換性**: すべてMSVCでビルドすることで、ランタイムライブラリの不一致を回避
- **OBS Studio統合**: OBS StudioはVisual Studioでビルドされるため、FFmpegもMSVCでビルドすることで問題を最小化
- **共有ライブラリ**: FFmpegを.dll形式でビルドすることで、OBSとの動的リンクを実現

### MSYS2の役割

MSYS2はコンパイラとしては使用せず、以下の目的でのみ使用します：

- FFmpeg/x264の`configure`スクリプト実行
- `make`によるビルドプロセス制御
- Unix系ツール（sed, grep等）の提供

実際のコンパイルはすべてMSVCの`cl.exe`と`link.exe`で行われます。

## 参考情報

- [FFmpeg公式](https://ffmpeg.org/)
- [OBS Studio公式](https://obsproject.com/)
- [FDK-AAC (mstorsjo)](https://github.com/mstorsjo/fdk-aac)
- [x264公式](https://www.videolan.org/developers/x264.html)
- [Visual Studio 2022](https://visualstudio.microsoft.com/ja/vs/)
- [MSYS2公式](https://www.msys2.org/)

## サポート

質問や問題がある場合は、まずトラブルシューティングセクションを確認してください。
