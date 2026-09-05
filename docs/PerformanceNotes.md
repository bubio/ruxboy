# パフォーマンス調査メモ (2026-09-02〜03)

Instruments によるプロファイリングをきっかけに行った、CPU/PPU 周りの速度調査の
記録。**結論としては「Rux コンパイラの最適化パイプラインが未成熟であること」が
根本原因であり、コンパイラ側の改善を待つほうが筋が良いと判断し、これ以上の
ソースコード側の対策は現時点で行わない**（詳細は末尾「今後の方針」）。ただし
6章のレジスタペアunion化は、この方針の例外として言語制約内で実施した
軽微な対策。

## 背景

`Tests/Packages/Core/CpuPerf` のベンチマーク・Instruments の Time Profiler
トレース(`timeprofile.xml`)・逆アセンブル(`ruxboy_disasm.txt`)を突き合わせて
調査した。

## 1. `PpuTick` の最適化(実施済み)

### 問題

`PpuTick`(`Packages/Core/Src/Ppu.rux`)は1 T-cycleごと(1ラインにつき456回)
呼ばれる最も熱いループの一つ。ループ内で `bus.ppu.dot` / `bus.ppu.ly` /
`bus.ppu.mode` を直接読み書きしていた。

まともな最適化コンパイラ(C/C++ -O2、Rust release など)であれば、これは
`mem2reg`(スタック/構造体メモリ上の変数をレジスタへ昇格する処理)・
LICM(ループ不変式の巻き上げ)・冗長 load 除去によって自動的に1レジスタへ
昇格され、無駄なメモリアクセスは消える。

しかし Rux の Release パイプラインは
(`external/Rux/Docs/Architecture.md` に明記の通り)
**定数畳み込み・コピー伝播・DCE・CFG整理のみ**で、`mem2reg` 相当の処理も
LICM も持たない。そのため、同じフィールドに複数回触れるだけのコードが
「毎回メモリを読み直し・書き直す」機械語へそのまま直訳されていた
(逆アセンブルで確認)。

### 対策

`dot` / `ly` / `mode` / `windowLine` をループの外で一度だけローカル変数へ
読み出し、ループ内はローカル変数だけで計算するよう書き換えた。
`PpuRenderScanline` / `PpuUpdateLycEqual` / `PpuUpdateStatIrq` は
`bus.ppu` のこれらのフィールドを読み書きするため、呼び出し直前直後だけ
ローカル変数と `bus.ppu` を同期する。`HdmaOnHblank` は `bus.ppu` に触れない
ため同期不要(確認済み)。

元のループはコメントとして残し、理由も併記してある
(`Packages/Core/Src/Ppu.rux` の `PpuTick` 参照)。

### 検証

- `rux check` 通過
- dmg-acid2 / cgb-acid2 フレームバッファハッシュ一致(ピクセル完全一致)
- Mooneye テスト全通過(既知の3件の EXPECTED FAIL のみ、退行なし)
- CpuPerf ベンチ: PASS(226% realtime、修正前後で退行なし)

同じ問題は `Bus.rux` の `TimerTick`、`Ppu.rux` の `TilePixelColorNumber`
(VRAM読み出しのインライン化)でも既に同じ方針で対策済み。

## 2. `CpuExecute` 調査 — 最初の推測は誤りだった

### 最初の仮説(誤り)

Instruments のトレースはシンボリケートされておらず(後述)、逆アセンブルとの
アドレス突き合わせで「ホットな命令列が広い範囲に散らばっている」ことまでは
分かったが、名前は特定できなかった。

`--emit asm`(x86-64ターゲット限定、後述)で実名付きアセンブリを出力し、
関数サイズを比較したところ `CpuExecute`(`Packages/Core/Src/Cpu.rux:520`、
opcode 実行本体)が 6910 行と全関数中で突出して大きく、かつ224個の
`else if opcode == 0xNN` という逐次比較チェーン(ジャンプテーブル化されて
いない)であることを確認した。この時点で「`CpuExecute` が確定的なホット
スポットである」とユーザーへ報告したが、**これは関数サイズからの推測に
過ぎず、誤りだった**。

### 実測による訂正

`CpuExecute` の分岐チェーンは、コード中のコメントにもある通り
「実ゲームで最頻出の命令群(LD r,r'・ALU・INC/DEC・JR)を先頭で判定する」
よう**既に手動でチューニング済み**であり、224分岐の大半は滅多に通らない
末尾だった。そこで実測で切り分けた:

**実測1: 分岐チェーン内の位置の影響**

CpuPerf ベンチ(`NOP; JP 0x0100` ループ)が使う `0xC3`(JP a16、通常は
チェーンの40個以上先)を一時的に2番目の分岐へ移動して比較(3回ずつ計測)。

| 状態 | t-cycles/sec |
|---|---|
| 元の並び | 約 9.46M |
| `0xC3` を先頭近くへ | 約 10.0M |

**約 +5.5%**、両条件のばらつきに重なりなし。再現性のある実効果ではあるが、
このベンチは `NOP`/`JP` しか実行しない極端なケースであり、実ゲームでは
既に高頻度命令が先頭に寄せてあるため、実際の恩恵はこれより小さいと見込まれる。

**実測2: ホット命令の分布**

トレース中の RuxBoy 自身のリーフアドレスを 4KB 単位でバケット化すると、
**37個の 4KB 領域に分散**しており、最大のバケットでも全体の 12.8%、
上位6個を足してようやく半分だった。1つの巨大関数が突出して重い、という
形にはなっていない。

### 解釈

Rux Release は**関数インライン化を一切行わない**(`TimerTick` /
`TilePixelColorNumber` の最適化コメント参照)。そのため

```
CpuStep → CpuExecute → R8Get/R8Set/ReadImm8/ReadImm16
        → CpuRead8/CpuWrite8 → BusTick → PpuTick/TimerTick/ApuTick/BusRead
```

という多層の呼び出し連鎖そのもの(=関数呼び出しオーバーヘッドの積み重ね)
が、実測2の「広く薄く分散した」プロファイル形状と整合する。`CpuExecute`
単体の書き換えは軽微な改善(実測1で確認した程度)にとどまり、根本原因は
呼び出し連鎖全体に薄く広がっている可能性が高い。

## 3. Rux ツールチェインの制約(副次的な発見)

調査の過程で判明した、パフォーマンス解析そのものを妨げる Rux 側の制約:

- **AArch64 バイナリはローカルシンボルを一切保持しない**。Debug/Release
  いずれも `nm` で定義済み関数が1つも出ない(`LC_SYMTAB` の
  `nlocalsym=0`)。DWARF 情報もなし(`dwarfdump --debug-info` が空)、
  dSYM も生成されない。`rux build --help` は `--debug` を
  「Build with debug symbols」と説明しているが、実際には
  `nm`/`atos`/`dwarfdump`/Instruments いずれでも関数名を解決できない。
- **`--emit asm`(実名付きアセンブリ出力)は x86-64 ターゲット限定**。
  AArch64 では `"textual assembly inspection is currently supported
  only for x86-64 targets"` という警告で無効になる。
- 上記のため、AArch64(実際にプロファイルする対象)上で関数名を確認する
  唯一の実用的な手段は、x86-64 ターゲットへクロスビルドして
  `Temp/Asm/out.asm` を読む、という間接的な方法だけだった。
- **関数ポインタ・第一級関数値が(ドキュメント上)存在しない**。
  `Docs/Language.md` に該当する型構文の記載なし。
- **整数値に対する `match`(switch 相当)が存在しない**。`match` は
  enum/variant 専用(`Docs/Language.md` 参照、標準ライブラリ内の
  使用例もすべて enum/variant)。ジャンプテーブルへ最適化される
  余地のある構文が言語側にそもそも無い。

これらは今回の調査を通じて実際に踏んだ制約であり、将来 Instruments で
直接シンボリケートしたい場合や、ディスパッチをジャンプテーブル化したい
場合に効いてくる。

## 4. `external/Rux/Packages/` に有効なものは無いか(調査済み)

念のため、標準ライブラリ側にこのボトルネックへ効きそうなものが無いか
確認した。**直接効くものは無い**という結論。

- **`Simd`**(`Float32x4`/`Float64x2`/`Int32x4`/`Uint32x4`、Add/Sub/Mul/Div/
  Dot/Sum/Min/Max): 数値演算(物理演算・グラフィックス変換向け)の
  ベクトル化が主目的で、シフト/マスク/ギャザーのようなビット操作は
  無い。今回のボトルネックは opcode ディスパッチや1バイト単位の VRAM
  読み出しといった**本質的にスカラーな分岐処理**であり、SIMD化できる
  箇所がそもそも無い。強いて言えば `PpuRenderScanline` の LCDC bit0=0
  時(160ピクセルを同じ値で塗りつぶす箇所)なら4ピクセル同時書き込みに
  使える余地はあるが、影響は軽微。
- **`Benchmark`**(統計的タイミング計測・`BlackBox`・スループット計測):
  実行速度そのものは改善しないが、今の `CpuPerf`(`gettimeofday` の素朴な
  差分)より計測の質を上げられる可能性はある。ただし2章で書いた
  「`rux build` で `Core` 以外を使うには推移的依存を全部 Path 依存として
  列挙し、かつ実際に `import` する」という制約(`docs/dev/PLAN.md` 6節
  参照)と、`Rux/Toml` で踏んだ「別パッケージが同名ジェネリックを重複
  定義するとリンクで失敗する」というコンパイラ不具合のリスクは、これを
  導入する場合も同様に付きまとう。
- **`Thread`/`Sync`**: PPU描画やAPUミキシングを別スレッドへ逃がす、という
  方向性の改善は理論上あり得るが、これは「ディスパッチを速くする」のでは
  なく「並列化する」という別種の変更で、現在のオーディオ駆動ペーシング
  設計(壁時計不使用)を含む大掛かりなアーキテクチャ変更になる。今回の
  調査結果(呼び出し連鎖のオーバーヘッド)への直接対処ではないため、
  今回の検討範囲には含めていない。
- **`Algorithms`/`Collections`/`Hash`/`Memory`/`Allocator` 等**: ホット
  パスに動的確保や汎用データ構造は無い(すべて固定長構造体)ため、
  そもそも出番がない。

## 今後の方針

**根本原因は Rux コンパイラの未成熟さ(`mem2reg`/LICM/インライン化/
ジャンプテーブル化のいずれも持たない)であると解釈し、現時点ではこれ以上
ソースコード側の対策は行わない。** `PpuTick` のような「呼び出しをまたがず
同じフィールドに繰り返し触れるホットループ」は今回の対策で潰したが、
`CpuExecute` の分岐チェーン再構成(256要素の `opcode → groupId` 配列 +
短い if 連鎖、という言語制約内で可能な形)や、呼び出し連鎖全体の手動
インライン化は、効果(実測 +5.5% 程度)に対してコードの見通しを損なう
コストが大きいと判断し、見送る。

もし将来再検討する場合の参考:

- Rux には関数ポインタも整数 `match` も無いため、真のジャンプテーブルは
  組めない。現実的な形は「256要素の `uint8` 配列で opcode → 小さな
  グループ番号へ変換 → グループ番号に対する短い if 連鎖」程度。
- `CpuExecute` 単体より、呼び出し連鎖全体(`CpuRead8`/`CpuWrite8` 経由で
  毎回 `PpuTick`/`TimerTick`/`ApuTick` を呼ぶ構造)を手動インライン化する
  方が効果が大きい可能性があるが、影響範囲が広く可読性とのトレードオフが
  大きい。
- Rux コンパイラ側(`external/Rux`, d01b8c9 固定)が `mem2reg`/LICM/
  関数インライン化/switch のジャンプテーブル化を実装すれば、これらの
  手動対策の大半は不要になる。コンパイラのアップデートを待つのが
  最も筋が良い解決策。

## 5. 移植元(BubiBoy Lite, Odin)との比較(2026-09-03、追加の裏付け)

フェーズ9(Windows対応)の過程で「Windows実機で音がぶつぶつ途切れる」
という報告を調査した際、ユーザーからmacOS実機での比較データが得られた:

- **RuxBoy(実ゲーム実行中): CPU使用率がほぼ100%**(1コア分を使い切っている)。
- **移植元のBubiBoy Lite(Odin言語、同一ロジック): 他のエミュレーターと
  同程度の約30%**。

GBC相当のエミュレーションはPowerPC Mac(現行Apple Siliconよりはるかに
非力なCPU)でも動いていた程度の軽量な処理であり、単純な処理量の問題では
あり得ない。同じロジックをOdinへ移植したBubiBoy Liteが約30%で動いている
以上、Rux言語そのものの実行速度の限界ではなく、**1章で述べた「Rux Release
パイプラインの未成熟さ(`mem2reg`/LICM/関数インライン化/ジャンプテーブル化
のいずれも持たない)」という結論を補強する実測**と判断した。

また、Windows実機の調査(`docs/dev/phases/phase-09-cicd.md`参照)では
`CpuPerf`ベンチマークが57%(realtime未達)だったのに対し、macOSでは
(ほぼ100%のCPU使用率と引き換えに)辛うじてrealtimeを維持できている。
macOSで既に限界に近い状態のため、Windows実機のシングルコア性能差や
Windows向けコード生成の差が乗ると赤字(realtime未達)に転落しやすい、
という説明とも整合する。

**結論は変わらず**: ソースコード側でこれ以上の対策は行わず、Rux
コンパイラの最適化パイプライン改善を待つ方針を維持する。Windows実機での
音切れ調査はこの結論を受けて一旦打ち切る。

### 追加の裏付け: 同一PCでのUbuntu 24.04比較(2026-09-03)

上記のWindows実機と**同一のPC**でUbuntu 24.04を起動し、移植元のBubiBoy
Liteを試したところ、**CPU使用率30%程度で問題なく動作した**(ユーザー報告)。

これにより「Windows実機のハードウェア性能自体が低い」という可能性が
切り分けられ、Windowsでの不振がハードウェア要因ではなく、Rux言語
(コンパイラのRelease最適化パイプラインおよび/またはWindows向けコード
生成)に起因することの裏付けがさらに強まった。上記のmacOSでの比較
(同一ロジックのBubiBoy Liteが約30%、RuxBoyがほぼ100%)と合わせて、
結論(1章で述べたRux Releaseパイプラインの未成熟さ)は変わらない。

## 6. SameBoy(移植元と同じロジックのC実装)との設計比較、レジスタペアのunion化(2026-09-03)

5章の裏付けを受け、移植元の移植元にあたる**SameBoy**(`Core/sm83_cpu.c`、
高速な実装で知られるC言語製GBCエミュレーター)のCPU実装とRuxBoyの
`Cpu.rux`を比較し、言語制約内で真似できる設計上の相違点を探した。

### 見つかった相違点

1. **opcodeディスパッチ**: SameBoyは関数ポインタのジャンプテーブル
   (`sm83_cpu.c:1570-1605, 1715`)。RuxBoyは3章で述べた通り関数ポインタも
   整数`match`も言語に無いため、この差は埋められない。
2. **レジスタ表現**: SameBoyは16bit/8bitレジスタを`union`でメモリ
   オーバーレイしており(`gb.h:71, 315-370`)、シフト/マスク命令が不要。
   RuxBoyは`a`〜`l`を独立フィールドとして持ち、16bitペアの取得・設定の
   たびに関数呼び出し+シフト+マスクが発生していた(`CpuAf`等、
   `CpuExecute`内で44箇所呼ばれる)。Releaseがインライン化しないため、
   このオーバーヘッドはBus呼び出し連鎖(2章)と同種の、もう一つの具体的な
   発生源だった。

Ruxが`union`(明示的なオーバーラップストレージ型、
`external/Rux/Docs/Language.md`110-112行)をサポートしていることを確認し、
`Tests/Language/Union`の実例(`int32`/`float32`/`uint8[4]`の重ね合わせ)に
倣った最小プローブで「構造体フィールドの宣言順=メモリオフセット昇順、
リトルエンディアン」をDebug/Release両方の実行で確認した上で、`Cpu`構造体を
以下の形へ書き換えた:

```rux
pub struct RegPairBytes {
    pub lo: uint8;
    pub hi: uint8;
}

pub union RegPair {
    pub word: uint16,
    pub bytes: RegPairBytes
}

pub struct Cpu {
    pub af: RegPair;
    pub bc: RegPair;
    pub de: RegPair;
    pub hl: RegPair;
    // ...
}
```

`CpuAf`/`CpuSetAf`/`CpuBc`/`CpuSetBc`/`CpuDe`/`CpuSetDe`/`CpuHl`/`CpuSetHl`
の8関数は全廃し、呼び出し側を`cpu.af.word`等の直接アクセスへ置き換えた
(AF書き込み時のFレジスタ下位4bitマスクは書き込み箇所に残した)。8bit単体
アクセス(`cpu.a`→`cpu.af.bytes.hi`等、命令の大半を占めるLD r,r'/ALU系が使う)
は固定オフセットへの単純load/storeのままで追加コストなし。

### 検証

- `rux check`(`Packages/Core`)通過
- Cpu/CpuInstrs/Mooneye(既知3件のEXPECTED FAILのみ)/Mbc/Blargg/DmgSound/
  Acid2(dmg-acid2・cgb-acid2フレームバッファハッシュ一致)/SaveState、
  全ユニットテスト・統合テストPASS(退行なし)
- CpuPerfベンチ: 226%→**235%** realtime(このベンチ自体はNOP/JPループで
  レジスタペア操作が少なく、恩恵は小さいが退行はない)

### 結論

Bus呼び出し連鎖(2章)ほど大きな効果ではないが、言語制約の範囲内で適用できる
実効性のある対策だったため採用した。**それ以外(ジャンプテーブル化、
関数インライン化)は依然としてコンパイラ側の制約であり、5章までの
「コンパイラの改善待ち」という基本方針は変わらない。**

## 7. HareGirl(同一移植元の姉妹プロジェクト)の高速化との突き合わせ(2026-09-05)

`~/dev/_Emu/haregirl`(同じ BubiBoy Lite を Hare 言語へ移植したプロジェクト)が
2026-09-04 に2件の `perf:` コミット(`17856de`・`c0c2452`)と1件の音声関連
`fix:`(`5d4811b`、APUのdotループをO(1)の閉じた式へ書き換え)を行った。
「HareGirl 側で採れた高速化を RuxBoy にも可能な限り取り込む」という依頼を
受け、該当コミットを1件ずつ RuxBoy の現状と突き合わせた監査の記録。

### 7.1 取り込んだもの

**MBC バンク切替の剰余演算→ビットマスク化**(HareGirl `17856de` に相当、
`Packages/Core/Src/Mbc.rux` の `NormalizedRomBank`/`NormalizedRamBank`)。

`romBanks`(ROMサイズコードから`2 << code`で算出、`RomSizeFromCode`参照)・
RAMバンク数(`ramLength / 8192`、`RamSizeFromCode`が返しうる値は
{0,1,4,8,16}のみ)はいずれも仕様上常に2の冪であるにもかかわらず、
`bank % count` という剰余演算で折り返していた。`ReadRomBank`はCPUの
オペコードフェッチを含むROM全バイトアクセスのたびに呼ばれる最も熱い
パスの一つのため、`bank & (count - 1)` へ置き換えた。

この最適化は「コンパイラが本来自動でやるべき最適化(mem2reg/インライン化)
の手動肩代わり」という1〜6章の対策群とは性質が異なり、**除算命令を
除去するアルゴリズムレベルの変更**であるため、6章末の「これ以上
ソースコード側の対策は行わない」という方針の例外として妥当と判断し採用した
(HareGirl側もコンパイラ最適化の巧拙に関係なく効く変更として導入している)。

正確性の検証: `scripts/test.sh --release` 全PASS(既知の3件の
expected-failのみ、差分なし。mooneyeのmbc1/mbc5系ROMはいずれもバンク数が
2の冪のROMのため、`bank % n`と`bank & (n-1)`が同じ結果になり退行を
検出できない点に注意)。挙動が変わりうるのは「ヘッダの`romBanks`と実際の
ROM長が食い違い、かつ範囲外バンクを指定する」ケースだが、`CartridgeInit`
(`CartridgeParseHeader`)は`rom.length < romBytes`を`RomSmallerThanHeader`
エラーとして弾くため、`romBanks * RomBankSize <= rom.length`が常に成立し、
`bank`を`[0, romBanks)`へ折り返す限りどちらの式でも範囲外アクセスにはならない
(`Tests/Packages/Core/Mbc`も`BusLoadRom`経由でこの検証を通るため、この
分岐は現状のコードパス上そもそも到達不能)。以上より計算結果の同値性は
コードの検査で確認済み。

性能の検証: `CpuPerf`ベンチ(NOP/JPループ、ROMバンク切替を経由しない)は
修正前後とも221-227%realtimeで測定誤差の範囲内(想定通り無風 — この
ベンチ自体がバンク切替を行わないため)。バンク切替を伴う実ゲーム
(MBC1/MBC5等)での定量的な改善幅は、それを継続的に測る専用ベンチマークが
現状無いため**未計測**(除算1回をビットAND1回に置き換える変更なので
悪化はしないと考えられるが、これは推測であり実測ではない)。

### 7.2 既に対策済みだったもの(HareGirlの後追いではなく独立に先行実装済み)

- **PPU: BG/ウィンドウ描画のタイル単位VRAM読み出しキャッシュ**
  (HareGirl `c0c2452`相当)。RuxBoy は `PpuRenderScanline`
  (`Packages/Core/Src/Ppu.rux`)で2026-09-02〜03の調査時点(1章参照)から
  同じ設計(タイル列が変わったときだけVRAMを再フェッチ)を実装済み。
- **PPU: STAT割り込み判定をモード/LY境界でのみ実行**(HareGirl `17856de`の
  PPU部分に相当)。RuxBoy の `PpuTick` は境界(ライン送り・モード遷移)の
  ときだけ `PpuUpdateStatIrq` を呼ぶ設計を1章の対策時点から実装済み。

### 7.3 対象外と判断したもの

- **APU: チャンネル周期タイマーの閉じた式(O(1))化**(HareGirl `5d4811b`)。
  **実装して実測した上で、退行を確認して差し戻した。** 経緯:

  1. まず ch1/ch2(矩形波)のみを対象に試作した。wave/noiseは1 T-cycle
     ごとの出力値を区間平均(`sampleArea`)へ蓄積する必要があり
     HareGirlには無い正確性リスクを抱えるため最初から対象外とし、
     ch1/ch2(瞬時値のみ、区間平均なし)に絞った。`timer`は常に
     `[1, period]`に収まる不変条件(トリガー時・リロード時に成立)を
     利用し、`apu_periodic_wraps`(HareGirl)と同じ閉じた式(除算+剰余)
     で経過ラップ数と最終timer値を一発で求める関数を実装。ただし
     `PulseOutputUnits`は48kHzサンプル生成の瞬間にしか読まれないため、
     `BusTick`呼び出し(4/8 T-cycle)の途中でサンプル境界をまたぐ場合に
     `dutyStep`が本来より早く進んだ状態を読んでしまわないよう、
     サンプル境界までの分だけ前進させてから`MixSample`を呼び、残りは
     次の境界まで`pulsePending`ローカル変数で持ち越す設計にした
     (HareGirlが同コミットで「一括で進めると状態が凍結する」と書いている
     問題への対処と同じ理由)。
  2. `scripts/test.sh --release` は全PASS(dmg_sound の "03-trigger"・
     "04-sweep"・"06-overflow on trigger"・"10-wave trigger while on"
     などトリガー/タイミングに敏感なテストを含め、既存の3件の
     expected-fail以外は差分なし)で、**正確性の面では問題が無かった**。
  3. しかし `CpuPerf`ベンチ(`--release`、3回×2セット計測)は
     **221-227%realtime(適用前) → 216-221%realtime(適用後)**と、
     むしろ2-5%ポイントの退行だった。原因は、`BusTick`が渡す tCycles が
     常に4または8(7.3節で確認済み)と小さく、除算を伴う閉じた式1回の
     コストが「1 T-cycleごとの減算+比較+分岐を最大8回繰り返す」コストを
     Release最適化なしのRux上では下回らなかったため、かつ関数呼び出し
     (`ApuAdvancePulse`)自体のオーバーヘッドが元のインライン展開済み
     コードより増えたためと考えられる(いずれも未検証の推測だが、
     測定結果自体は再現性あり)。
  4. `Packages/Core/Src/Apu.rux` の変更は `git checkout` で差し戻し、
     元のT-cycleごとのインラインループへ戻した。

  結論: HareGirlでこの最適化が効いたのは、CPUのHALT/STOP待ちで
  `apu_tick` に大きなT-cycle数を一括で渡す(バッチする)設計だから
  であり、RuxBoyのように1命令(4/8 T-cycle)ごとにしか`BusTick`を
  呼ばない設計では、同じ変更が逆効果になることを実測で確認した。
  将来 RuxBoy 側で HALT 中の T-cycle をまとめて進める設計に変更する
  場合は再検討の価値がある。
- **APU: i16ミキサーのオーバーフロー修正**(HareGirl `1ec5d10`)。RuxBoy の
  `MixSample`(`Packages/Core/Src/Apu.rux`)は元から `int64` で
  `(mix * volBits * 32767) / 480` と最後に一度だけ除算する設計のため、
  HareGirlが踏んだ「`*128`の中間計算がi16レンジを超えてラップする」
  という不具合が構造的に発生しない。対応不要。
- **APU: ノイズチャンネル周期のu16オーバーフロー**(HareGirl `5d4811b`が
  ついでに直したガード)。RuxBoy はタイマーを`int32`で持つ設計
  (Apu.rux冒頭のコメント参照)のため、`u16`への丸め込みによる
  ゼロ除算相当のバグはそもそも存在しない。対応不要。
- **CPU: ブレークポイント検出用オペコードの二重フェッチ回避**
  (HareGirl `17856de`)。RuxBoy の `App` 層にHareGirlの
  `rom_runner_step`のようなブレークポイント検出機構自体が無い
  (`grep -rn "breakpoint" Packages/App/Src/*.rux` 該当なし)ため対象外。
- **APU: 電源投入時のNRx4トリガービット誤書き込み**(HareGirl `1a8847a`)。
  RuxBoy の `ApuPowerOn`(Apu.rux)はNRx4レジスタへの書き込みや
  `TriggerPulse`等の呼び出しを行わず、`poweredOn`/`nr50`/`nr51`/
  `noise.lfsr`のみを直接セットする設計のため、この不具合はそもそも
  発生しない。対応不要。
- **App層: ウィンドウ終了時の音声デバイスポーズ / 音量設定の反映漏れ /
  フレームペーシング**(HareGirl `1a8847a`・`00362b8`・`17c5b90`)。
  いずれもApp/SDL層のバグ修正であり「コア(移植主対象)の軽量化」という
  今回の依頼の対象外と判断。RuxBoyのApp層は最初から音声駆動ペーシング
  (バッファ残量に応じてスロットリング、5章のBubiBoy Lite比較参照)を
  採用しており、HareGirlが`17c5b90`で後追いした固定`delay`方式の問題は
  そもそも発生しない設計。

