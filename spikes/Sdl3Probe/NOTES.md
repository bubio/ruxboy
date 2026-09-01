# Sdl3Probe — Rux + SDL3 実現可能性の検証結果

RuxBoy の実装に入る前に、「Rux と SDL3 で GBC エミュレーターに必要なことが
できるか」を確かめるための最小プログラム。エミュレーションのコードは含まない。

- 検証日: 2026-09-01
- 環境: macOS (Darwin 25.6.0) / Apple Silicon、SDL3 3.4.14 (Homebrew)
- コンパイラ / 標準ライブラリ: submodule `external/Rux`（`rux-lang/Rux` を
  **d01b8c9 に固定**）をソースからビルドしたもの

## 結論

**移植は可能。** エミュレーターの実行に必要な要素はすべて Rux から使えた。
Debug / Release の両プロファイルで 23 項目すべて通過している。

## 実行方法

```sh
./run.sh              # Debug
./run.sh --release    # Release
```

約 2 秒間ウィンドウが開き、440Hz の矩形波が鳴り、23 項目のチェック結果を
標準出力に出して終了する。60 フレーム目の描画内容を `frame.bmp` に保存するので、
目視確認はそれで行う。**実行に環境変数は要らない**（後述）。

## 検証できたこと

| 項目 | 使用した API / 機能 | 結果 |
| --- | --- | --- |
| 符号なし整数のラップ | `uint8` 255+1 → 0、`uint16` 0-1 → 65535 | ok |
| 構造体の C レイアウト互換 | `sizeof(SdlEvent) == 128` | ok |
| コンパイル時のプラットフォーム分岐 | `when #target.os == .macOS` | ok |
| C の可変長引数呼び出し | `snprintf(buf, n, "%d/%d", 160, 144)` | ok |
| ウィンドウ / レンダラ生成 | `SDL_CreateWindow` / `SDL_CreateRenderer` | ok |
| フレームバッファ転送 | 160x144 streaming texture + `SDL_UpdateTexture` を毎フレーム | ok |
| 整数倍スケーリング | `SDL_SetRenderLogicalPresentation(INTEGER_SCALE)` | ok |
| nearest / smooth 切り替え | `SDL_SetTextureScaleMode` | ok |
| イベントの往復 | `SDL_PushEvent` した合成イベントを `SDL_PollEvent` で読み戻し | ok |
| ループ内のイベント処理 | ループ中に注入したキーイベントでハンドラが反応する | ok |
| 音声出力 | `SDL_OpenAudioDeviceStream` + `SDL_PutAudioStreamData` | ok |
| 時間計測 | `SDL_GetTicks` / `SDL_GetPerformanceCounter` | ok |
| 描画結果の読み戻し | `SDL_RenderReadPixels` + `SDL_SaveBMP` | ok |

音声はコールバックを使わない push 方式で足りたため、**C の関数ポインタを
コールバックとして渡す経路は未検証**。APU は push 方式で実装できる見込みだが、
必要になった時点で改めて確かめること。

## 言語側で確認した重要な性質

### エミュレーターコアにとって有利な点

- **符号なし整数は debug / release の両方でラップする。**トラップしない。
  GBC の CPU コアは `uint8` / `uint16` のラップアラウンドに全面的に依存するので、
  これは移植可否を左右する条件だった。ドキュメントの記述だけでなく、debug
  ビルドで実際にトラップしないことをプローブ内で実測している。`uint8` は
  `byte` という別名を持つ。
  一方 **符号付き整数は debug でオーバーフローすると致命的エラー**になり、
  release ではラップする。コアでは符号なし型を使うこと。
- **構造体は C とレイアウト互換。** フィールドは宣言順、自然アライメント、
  並べ替えなし。`sizeof(SdlEvent)` が C の `sizeof(SDL_Event)` と一致する
  （どちらも 128）ことを実測で確認した。さらに合成したキーイベントを
  `SDL_PushEvent` → `SDL_PollEvent` で往復させ、`scancode`（オフセット 24）と
  `down`（オフセット 36）が C 側と同じ位置で読み書きできることも確かめてある。
- **C の可変長引数関数を呼べる。** 宣言は `func snprintf(buf: *char8, size: uint,
  format: *char8, ...) -> int32;` のように末尾へ `...` を置く。Rux 独自の
  可変長引数（`T...`、スライスを受け取る）とは別物なので混同しないこと。
- **文字列リテラルは NUL 終端されている。** `.data` をそのまま C へ渡せる。
  型は `Core::Slice<char8>`。`.length` は終端を含まない。
- **コンパイル時の分岐が使える。** `when #target.os == .macOS { ... } else { ... }`。
  取られなかった枝は解析すらされないので、他プラットフォームにしか存在しない
  シンボルを書いてよい。`#config.Get("NAME")` で `--define NAME=値` を読める。
- 固定幅整数（`uint8`〜`uint512`）、ポインタ演算、`*T` / `*var T` の
  読み取り専用・書き込み可の区別、`*opaque`（C の `void*`）が揃っている。

### 制約になる点

- **モジュールスコープに可変変数を置けない。** `const` のみ。エミュレーターの
  状態はすべて構造体に入れてポインタで持ち回す設計になる（BubiBoy Lite の
  `Emulator` 構造体を渡す形と相性が良い）。
- **配列は `.data` を持たない。** `Slice<T>` だけが持つ。配列の先頭アドレスは
  `@array[0]` で取る。
- **`import` はパッケージ単位。** 同一パッケージ内の複数ファイルは自動的に
  同じスコープを共有するので、ファイル間の `import` は書かない。
- 文字リテラルは `c8'v'` のように幅の接頭辞を付ける。

## 標準ライブラリの入手方法

**レジストリ（api.rux-lang.dev）はまだ何も配信していない**（トップページから
404）。したがって `rux add Rux/Io` が書き込むレジストリ依存は解決できない。

代わりに **submodule `external/Rux` の `Packages/` へ相対パスで依存する**。
これは Rux リポジトリ自身が `Tests/Packages/` で採っている方法で、本プローブも
`Core` をこの形で使っている:

```toml
[Dependencies]
Core = { Path = "../../external/Rux/Packages/Core" }
```

submodule はコンパイラのソースでもあるので、**コンパイラと標準ライブラリの版が
必ず一致する**（`run.sh` は `external/Rux/Bin/rux` を使う）。

注意点:

- **パスは相対でなければならない**（絶対パスはマニフェスト検証で弾かれる）。
  submodule にしたことで、リポジトリ内で完結する安定した相対パスになった。
- **シンボリックリンクでは解決できない。** 親ディレクトリを symlink にしても、
  パッケージごとに symlink を張っても `no installed version of 'Rux/Core'` になる。
  実ディレクトリが要る。
- **推移的な依存も自分のマニフェストに書く。** 依存パッケージのマニフェストは
  レジストリ依存を宣言しているが、こちらがパス依存として同じ識別子を宣言すれば
  それが使われる。`Core` は依存ゼロなので 1 行で済むが、`Io` を使うなら
  `Allocator` / `Format` / `Memory` / `Text` / `macOS`（+ 他 OS 分）も要る。

なお本プローブは出力に標準ライブラリを使わず、libSystem の `write(2)` を
直接叩いている（`Src/Out.rux`）。標準ライブラリ抜きでも進められることの
確認を兼ねている。

## SDL3 の場所をどう解決するか（解決済み）

`#Link("...")` に渡した文字列は Mach-O のロードコマンドへそのまま入る。
素の名前 `libSDL3.dylib` だと、Apple Silicon の Homebrew（`/opt/homebrew/lib`）は
dyld の既定検索パスに含まれないため起動時に解決できない。

**採った方法**: ビルド時に `pkg-config --variable=prefix sdl3` で場所を調べ、
`--define SDL_PREFIX=<prefix>` で渡す。Rux 側は `when #config.Get("SDL_PREFIX")` で
既知の prefix を判定し、絶対パスの文字列リテラルを `#Link` に渡す
（`Src/Sdl3.rux` 冒頭）。**実行時に環境変数は不要**になる。

`#Link` は文字列リテラルかコンパイル時文字列定数しか受け付けないため、
`#Link(#config.Get("SDL_PREFIX"))` のように直接書くことはできず、
`const SdlLibrary: Slice<char8> = "..."` を `when` で選ぶ形になる。任意の
パスは扱えないが、Homebrew (arm64 / Intel)、MacPorts、既定の検索パスの
4 通りを網羅すれば実用上は足りる。

### 使えなかった方法

- **`install_name_tool` でビルド後に rpath を足す** — Rux が出力する Mach-O を
  Apple のツールが処理できない（`file not in an order that can be processed
  (symbol table out of place)`）。`#Link("@rpath/libSDL3.dylib")` と書けば
  ロードコマンドにはそのとおり入るが、`LC_RPATH` を後から足せないので無意味。
- **`DYLD_LIBRARY_PATH`** — 設定すると `SDL_PollEvent` の中で SIGBUS する:

  ```
  Thread 0 Crashed:
    0   ???        0x0bad4007
    1   AppKit     +[NSOpenGLContext currentContext]
    2   libSDL3    ScheduleContextUpdates
    3   libSDL3    -[SDL3View updateLayer]
  ```

  **これは Rux の問題ではない。** C で書いた同等のプログラムでも
  `DYLD_LIBRARY_PATH` を付けると同じ場所で落ちる。AppKit がソフトリンクして
  いる OpenGL の解決が巻き添えで壊れるため。検索順の最後にしか効かない
  `DYLD_FALLBACK_LIBRARY_PATH` なら問題ないが、配布物で環境変数を要求するのは
  避けたいので採用しなかった。

## ツールチェインの確認できた挙動

- `rux new <Name> --executable [--path <dir>]` — `Rux.toml` / `Src/Main.rux` /
  `.gitignore`（`Bin/` `Temp/`）を生成
- `rux build` / `run` / `check` / `test` / `fmt` / `lint` すべて動作
- 出力先は `Bin/<Profile>/<OS>/<Arch>/<Name>`（既定 Debug）
- `--define NAME=値` は `build` / `run` にはあるが **`lint` にはない**
- `rux fmt` / `rux fmt --check` が使える。ただし **`rux fmt` は `Rux.toml` の
  コメントを削除する**ので、マニフェストに説明を書いても残らない
- `Src/` 直下の複数ファイルは自動的に 1 パッケージとして扱われる
- `rux test` は `Tests/` を見る
- マニフェストは PascalCase の TOML サブセット。未知のキーはエラー

## 次にやるとよいこと

- C の関数ポインタをコールバックとして渡せるか
- release ビルドの実行速度の目安（GBC は 4.19MHz、1 フレーム 70224 サイクル）。
  Release でビルド・実行できることは確認済みだが、性能は測っていない
- Linux / Windows での `#Link` の解決（Linux は `libSDL3.so.0` を既定の
  検索パスで拾える見込み）

## 検証しないと決めたこと

窓システムが実際にイベントを送ってくるか（`SDL_PollEvent` が 0 件でなく返るか）は
実行環境しだいで、同じマシンでも回によって変わった。プローブは自分で合成
イベントを注入して処理経路を確かめる形にしてあり、この点は意図的に見ていない。
