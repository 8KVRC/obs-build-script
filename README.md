# FFmpeg + OBS Studio ビルドスクリプト

Windows環境でFDK-AAC対応のFFmpegとOBS Studioをソースからビルドするためのスクリプト集です。

## 概要

このプロジェクトは、MSVC環境でゼロからFFmpeg（FDK-AAC有効化）とOBS Studioをビルドするための3つのPowerShellスクリプトを提供します。

### 主な特徴

- **FDK-AAC対応**: 高品質なAACエンコーディング（最大576kbps、カットオフ20kHz）
- **MSVC環境**: Visual Studio 2022のコンパイラを使用
- **obs-deps統合**: OBS公式の依存関係ビルドシステムを活用
- **完全自動化**: 環境チェックから依存関係のビルド、OBSのパッチ適用まで自動化

## 前提条件

### 必須ツール

1. **Visual Studio 2022**
   - C++デスクトップ開発ワークロード
   - CMakeコンポーネント
   - ダウンロード: https://visualstudio.microsoft.com/

2. **MSYS2**
   - FFmpegのビルドに必要
   - インストール: https://www.msys2.org/
   - デフォルトインストール先: `C:\msys64`

3. **Git**
   - ソースコードの取得に必要
   - ダウンロード: https://git-scm.com/download/win

4. **PowerShell 5.1以上**
   - Windows 10/11には標準搭載
   - PowerShell Core (pwsh) 7以降を推奨

### 推奨環境

- Windows 10/11 (64bit)
- メモリ: 16GB以上
- ディスク空き容量: 20GB以上
- CPU: マルチコア推奨（ビルドに30分～1時間程度）

## ビルド手順

### STEP 1: obs-depsのビルド（FFmpeg依存関係）

OBS公式のobs-depsリポジトリを使用して、FFmpegとその依存関係をビルドします。

```powershell
.\build-scripts\01-build-obs-deps.ps1
```

#### パラメータ（オプション）

```powershell
# デフォルト設定
.\build-scripts\01-build-obs-deps.ps1 -WorkDir "C:\temp" -Target x64 -Configuration Release

# クリーンビルド
.\build-scripts\01-build-obs-deps.ps1 -Clean

# ARM64向けビルド
.\build-scripts\01-build-obs-deps.ps1 -Target arm64
```

- `-WorkDir`: 作業ディレクトリ（デフォルト: `C:\temp`）
- `-Target`: ターゲットアーキテクチャ（`x64`, `arm64`）
- `-Configuration`: ビルド構成（`Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`）
- `-Clean`: クリーンビルドを実行

#### 主な処理内容

1. **obs-depsのクローン**
   - タグ `2025-08-23` をチェックアウト
   - LF改行コード設定（パッチ適用のため）

2. **libfdk-aacスクリプトの追加**
   - `deps.ffmpeg/35-libfdk-aac.ps1` を自動生成
   - FDK-AAC v2.0.3 をビルド

3. **FFmpegスクリプトの修正**
   - `deps.ffmpeg/99-ffmpeg.ps1` に以下を追加:
     - `--enable-nonfree`
     - `--enable-libfdk-aac`

4. **Build-Dependencies.ps1の修正**
   - libfdk-aacを削除対象から除外
   - 以下のファイルを保護:
     - `lib/fdk-aac.lib`
     - `lib/libfdk-aac.lib`
     - `lib/cmake/fdk-aac/`
     - `lib/pkgconfig/fdk-aac.pc`

5. **依存関係のビルド**
   - x264, opus, vpx, SVT-AV1などの動画/音声コーデック
   - libfdk-aac（高品質AACエンコーダー）
   - FFmpeg（上記すべてのコーデックを有効化）

#### ビルド成果物

- 出力先: `C:\temp\obs-deps\windows\obs-ffmpeg-{version}-{target}`
- 内容:
  - `bin/`: FFmpegのDLLファイル（avcodec, avformat, avutil等）
  - `lib/`: インポートライブラリ（.lib）
  - `include/`: ヘッダーファイル

#### 所要時間

- 初回ビルド: 30分～1時間
- 2回目以降: キャッシュ活用で短縮

### STEP 2: OBS Studioのビルド

obs-depsでビルドした依存関係を使用して、OBS Studioをビルドします。

```powershell
.\build-scripts\02-build-all-msvc.ps1
```

#### パラメータ（オプション）

```powershell
# デフォルト設定
.\build-scripts\02-build-all-msvc.ps1 -WorkDir "C:\temp" -InstallPrefix "C:\obs-build-deps"

# カスタムパス
.\build-scripts\02-build-all-msvc.ps1 -WorkDir "D:\build" -InstallPrefix "D:\obs-deps"
```

- `-WorkDir`: 作業ディレクトリ（デフォルト: `C:\temp`）
- `-InstallPrefix`: 依存関係のインストール先（デフォルト: `C:\obs-build-deps`）
- `-ObsDepsPath`: obs-depsのパス（自動検出されます）

#### 主な処理内容

1. **環境チェック**
   - Visual Studio 2022の検出
   - CMakeの検出（VS付属版を優先）
   - Ninjaビルドシステムの検出
   - Gitの確認
   - MSYS2の確認

2. **obs-deps依存関係の統合**
   - obs-depsのビルド成果物を検出
   - 必要なファイル（bin, lib, include）をコピー
   - libfdk-aacの存在を確認

3. **OBS Studioのクローン**
   - バージョン `32.0.2` をチェックアウト
   - サブモジュールを再帰的に更新

4. **ソースコードへのパッチ適用**
   
   **a) ビットレート上限の変更（320kbps → 576kbps）**
   - 対象ファイル:
     - `frontend/settings/OBSBasicSettings.cpp`
     - `UI/window-basic-settings.cpp`
   - FDK-AACの最大ビットレートを576kbpsに引き上げ

   **b) 帯域幅設定の追加（カットオフ20kHz）**
   - 対象ファイル: `plugins/obs-libfdk/obs-libfdk.c`
   - `AACENC_BANDWIDTH` パラメータを追加
   - 音質向上のため高周波数帯域を保持

5. **CMake設定**
   - Visual Studio 2022ジェネレーター使用
   - カスタムFFmpegパスを明示的に指定
   - FDK-AACを有効化（`-DENABLE_LIBFDK=ON`）
   - 以下のFFmpegライブラリを指定:
     - avcodec, avformat, avutil
     - avdevice, avfilter
     - swresample, swscale

6. **MSBuildでビルド**
   - Release構成でビルド
   - 並列ビルドを有効化（`-maxcpucount`）
   - カスタムFFmpegのDLLを実行ディレクトリにコピー

#### ビルド成果物

- 実行ファイル: `C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit\obs64.exe`
- プラグイン: 同じディレクトリ内
- FFmpeg DLL: カスタムビルドのFFmpegライブラリ（FDK-AAC有効化）

## 使用方法

### OBS Studioの起動

```powershell
C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit\obs64.exe
```

### FDK-AACの設定

1. OBS Studioを起動
2. **設定** → **出力** → **詳細**
3. **音声エンコーダ**タブで「**libfdk AAC**」を選択
4. **ビットレート**で「**576**」を選択（最大値）
5. 設定を保存

### 音質の違い

- **標準AAC（128kbps）**: 一般的な配信品質
- **FDK-AAC（320kbps）**: 高品質（標準設定）
- **FDK-AAC（576kbps）**: 最高品質（このビルドの最大値）
  - カットオフ周波数20kHz
  - 音楽配信やアーカイブに最適

## トラブルシューティング

### MSYS2が見つからない

```
エラー: MSYS2が見つかりません
```

**解決策:**
1. https://www.msys2.org/ からMSYS2をダウンロード
2. デフォルト設定（`C:\msys64`）でインストール
3. スクリプトを再実行

### Visual Studio 2022が見つからない

```
エラー: Visual Studio 2022が見つかりません
```

**解決策:**
1. Visual Studio Installerを起動
2. 「C++によるデスクトップ開発」ワークロードをインストール
3. 「CMake ツール」コンポーネントを追加
4. スクリプトを再実行

### obs-depsのビルドに失敗

```
エラー: obs-depsのビルドに失敗しました
```

**解決策:**
1. PowerShell Core (pwsh) 7以降を使用
   ```powershell
   winget install Microsoft.PowerShell
   ```
2. `-Clean` オプションでクリーンビルド
   ```powershell
   .\build-scripts\01-build-obs-deps.ps1 -Clean
   ```
3. ディスク容量を確認（20GB以上必要）

### CMakeの設定に失敗

```
エラー: CMake configuration failed
```

**解決策:**
1. 古いビルドディレクトリを削除
   ```powershell
   Remove-Item C:\temp\obs-studio\build_x64 -Recurse -Force
   ```
2. obs-depsが正しくビルドされているか確認
   ```powershell
   Test-Path C:\temp\obs-deps\windows\obs-ffmpeg-*\bin\avcodec*.dll
   ```
3. スクリプトを再実行

### FFmpeg DLLが見つからない

```
警告: FFmpeg の DLL が見つかりませんでした
```

**解決策:**
1. obs-depsを再ビルド
   ```powershell
   .\build-scripts\01-build-obs-deps.ps1 -Clean
   ```
2. ビルド成果物の場所を確認
   ```powershell
   Get-ChildItem C:\temp\obs-deps\windows\obs-ffmpeg-*\bin\av*.dll
   ```

### OBS起動時にDLLエラー

```
エラー: avcodec-XX.dll が見つかりません
```

**解決策:**
1. FFmpeg DLLが正しくコピーされているか確認
   ```powershell
   Get-ChildItem C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit\av*.dll
   ```
2. 不足している場合は手動でコピー
   ```powershell
   Copy-Item C:\temp\obs-deps\windows\obs-ffmpeg-*\bin\*.dll `
             C:\temp\obs-studio\build_x64\rundir\Release\bin\64bit\
   ```

## ディレクトリ構造

```
C:\temp\
├── obs-deps\                    # obs-depsリポジトリ
│   ├── deps.ffmpeg\             # FFmpeg依存関係スクリプト
│   │   ├── 35-libfdk-aac.ps1   # 追加されるスクリプト
│   │   └── 99-ffmpeg.ps1       # 修正されるスクリプト
│   └── windows\                 # ビルド成果物
│       └── obs-ffmpeg-*/        # FFmpeg DLL/lib/include
│
├── obs-studio\                  # OBS Studioリポジトリ
│   ├── build_x64\               # ビルドディレクトリ
│   │   └── rundir\Release\bin\64bit\  # 実行ファイル
│   └── plugins\obs-libfdk\      # FDK-AACプラグイン
│
└── vs-env.bat                   # Visual Studio環境設定

C:\obs-build-deps\               # 統合された依存関係
├── bin\                         # DLLファイル
├── lib\                         # インポートライブラリ
└── include\                     # ヘッダーファイル
```

## 技術詳細

### obs-depsの仕組み

obs-depsは、OBS Studioの依存関係を統一的にビルドするための公式ツールです。

**特徴:**
- 各依存関係ごとにPowerShellスクリプト（`XX-libname.ps1`）を用意
- CMakeベースのビルドシステム
- Windows, macOS, Linuxに対応
- バージョン管理が容易（Gitタグで固定）

**ビルドプロセス:**
1. `Build-Dependencies.ps1` を実行
2. 指定されたパッケージ（ffmpeg等）の依存関係を解決
3. 各スクリプトを順次実行（番号順）
4. ビルド成果物を `windows/` ディレクトリに出力

### libfdk-aacの追加

obs-depsにはデフォルトでlibfdk-aacが含まれていないため、スクリプトで追加します。

**`35-libfdk-aac.ps1` の内容:**
- リポジトリ: https://github.com/mstorsjo/fdk-aac
- バージョン: 2.0.3
- ビルド方法: CMake
- ターゲット: x64, arm64
- ビルドオプション:
  - `BUILD_SHARED_LIBS=OFF` (静的リンク)
  - `BUILD_PROGRAMS=OFF` (ツール不要)

**FFmpegとの統合:**
- `99-ffmpeg.ps1` に以下のフラグを追加:
  - `--enable-nonfree`: 非フリーコーデックを有効化
  - `--enable-libfdk-aac`: libfdk-aacを使用

### OBS Studioのパッチ

#### 1. ビットレート上限の変更

**対象コード（OBSBasicSettings.cpp）:**
```cpp
// 変更前
#define MAX_AUDIO_BITRATE 320

// 変更後
#define MAX_AUDIO_BITRATE 576
```

**効果:**
- UIで選択可能な最大ビットレートが576kbpsに
- FDK-AACの性能を最大限に活用

#### 2. 帯域幅設定の追加

**対象コード（obs-libfdk.c）:**
```c
// 追加されるコード
CHECK_LIBFDK(aacEncoder_SetParam(enc->fdkhandle, AACENC_AFTERBURNER, 1));
CHECK_LIBFDK(aacEncoder_SetParam(enc->fdkhandle, AACENC_BANDWIDTH, 20000)); // 追加
```

**効果:**
- カットオフ周波数を20kHz（20000Hz）に設定
- デフォルトより高い周波数帯域を保持
- 音楽配信での音質向上

### CMakeオプションの詳細

```powershell
-G "Visual Studio 17 2022"           # VS2022ジェネレーター
-A x64                               # 64bitビルド
-DCMAKE_BUILD_TYPE=Release           # Releaseビルド
-DCMAKE_PREFIX_PATH=$ffmpegInstall   # FFmpegの場所
-DENABLE_LIBFDK=ON                   # FDK-AACを有効化
-DLibfdk_INCLUDE_DIR=...             # FDK-AACヘッダー
-DLibfdk_LIBRARY=...                 # FDK-AACライブラリ
-DENABLE_BROWSER=OFF                 # ブラウザ機能は無効
-DENABLE_WEBSOCKET=ON                # WebSocket機能は有効
-DENABLE_VLC=OFF                     # VLC機能は無効
```

## ライセンスと注意事項

### FDK-AACについて

FDK-AACは**非フリー（non-free）ライセンス**です。

- **ライセンス**: Fraunhofer FDK AAC Codec License
- **制限事項**:
  - 商用利用には制限がある場合があります
  - 再配布する場合はライセンス条件を確認してください
  - 個人使用は問題ありません

### FFmpegのライセンス

このビルドでは `--enable-nonfree` を使用しているため:
- **GPLライセンス**: GPL v3以降
- **非フリーコンポーネント**: libfdk-aac
- **再配布**: 条件付きで可能（ライセンスファイル同梱必須）

### OBS Studioのライセンス

- **ライセンス**: GPL v2
- **プラグイン**: 各プラグインのライセンスに従う

## 参考リンク

### 公式リポジトリ

- [OBS Studio](https://github.com/obsproject/obs-studio)
- [obs-deps](https://github.com/obsproject/obs-deps)
- [FFmpeg](https://github.com/FFmpeg/FFmpeg)
- [FDK-AAC](https://github.com/mstorsjo/fdk-aac)

### ドキュメント

- [OBS Studio Build Instructions](https://github.com/obsproject/obs-studio/wiki/Build-Instructions-For-Windows)
- [obs-deps Wiki](https://github.com/obsproject/obs-deps/wiki)
- [FFmpeg Compilation Guide](https://trac.ffmpeg.org/wiki/CompilationGuide)

### ツール

- [Visual Studio 2022](https://visualstudio.microsoft.com/)
- [MSYS2](https://www.msys2.org/)
- [Git for Windows](https://git-scm.com/download/win)
- [CMake](https://cmake.org/)

## バージョン情報

- **OBS Studio**: 32.0.2
- **obs-deps tag**: 2025-08-23
- **FDK-AAC**: 2.0.3
- **FFmpeg**: obs-depsに含まれるバージョン（6.1以降）

## 貢献

バグ報告や改善提案は歓迎します。

## FAQ

### Q: ビルドにどれくらい時間がかかりますか？

**A:** 環境によりますが、以下が目安です:
- STEP 0（MSYS2セットアップ）: 5分
- STEP 1（obs-deps）: 30分～1時間
- STEP 2（OBS Studio）: 15分～30分

### Q: vcpkgは使用しますか？

**A:** いいえ、このスクリプトはvcpkgを使用せず、obs-depsですべての依存関係をビルドします。

### Q: 既存のOBSインストールに影響しますか？

**A:** いいえ、このビルドは独立したディレクトリに作成されます。既存のインストールには影響しません。

### Q: ARM64ビルドは可能ですか？

**A:** はい、`-Target arm64` オプションを指定することでARM64向けにビルドできます。

### Q: デバッグビルドは作成できますか？

**A:** はい、`-Configuration Debug` オプションを指定することでデバッグビルドを作成できます。

### Q: 他のバージョンのOBSをビルドできますか？

**A:** はい、`02-build-all-msvc.ps1` 内の `git checkout` コマンドを変更することで、任意のバージョンやタグをビルドできます。

### Q: ビルドしたOBSを配布できますか？

**A:** FDK-AACを含むため、ライセンス条件を確認してください。商用配布には制限がある場合があります。

---

**作成日**: 2025年11月5日
**スクリプトバージョン**: 1.0
