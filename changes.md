# Changes

## 0. マイルストーンと実装状況

- ✅ ShapeInfoクラス: 完成
- ✅ パターン抽出: angle/scale/group_key保存済み
- ⚠️ grouped_pca_results: 部分実装（kd_tree/threshold未実装）
- ❌ common_basis: 未実装
- ⚠️ find_valid_tile_configuration: 部分実装（3段階検証未統合）
- ❌ CSV出力: 8カラムのまま

- ❌ A. パターン抽出時のメタデータ保存（行574-588）
    * rows_by_shape構築時にangle/scaleも保存

- ❌ B. ShapeInfo.new呼び出しの更新
    * 行732: パターンマッチング時
    * 行793: 初期形状構築時

- ❌ C. find_valid_tile_configurationの3段階検証（行693-767）
    * 共通基底→PCA→KNNの順で検証

- ❌ D. CSV出力形式の更新（行895-915）
    * 10カラム形式に変更

- ❌ E. デバッグ統計の拡充
    * グループ別統計、効率分析を追加

### 主な変更点

1. ✅ **初期形状**: CSVの最初の14行から構築
2. ✅ **メモリ効率**: 40万行のデータを参照で扱う
3. ✅ **コマンドライン引数**: 探索範囲を柔軟に指定
4. ✅ **探索範囲**: 初期形状からの相対座標で設定
5. ✅ **グループ不在警告**: 詳細な変数値と警告メッセージ
6. ✅ **CSV逐次出力**: tailで監視可能
7. ✅ **stderr出力**: 全デバッグ情報をstderrに分離

### 実装時の注意点

- `puts` → `STDERR.puts` に全て変更
- CSV出力は探索ループ内で逐次実行
- グループ不在時は警告を出すが処理は継続
- メモリ効率のため、CSVデータのコピーを作らない

---

## 1. Rubyファイル機能概要

### my_spectre_coordinateAnalyzer_hybrid_v2.rb
**機能概要**:
図形形状ベースと点ベースのアプローチを統合したハイブリッド方式のSpectreタイル座標解析スクリプトの最新版。
**主な特徴**:
- 14頂点の完全な形状パターンを抽出・利用（angle/scaleメタデータ付き）。
- データをangle×scaleでグループ化し、グループごとにPCA（主成分分析）と凸包境界を計算。
- 全データから共通基底を算出し、大域的なフィルタリングに利用。
- 3段階の検証プロセス（共通基底 → グループ別PCA → KNN密度推定）により、高速かつ高精度な探索を実現。
- 分岐検出機能によりトポロジー違反を記録。
**データソース**:
`my_spectre_generator_symbolic.rb` が出力するCSVファイル（`root_tile.for_each_tile` ループ内で生成される全頂点データ）を入力として使用。

### my_spectre_coordinateAnalyzer_hybrid.rb
**機能概要**:
ハイブリッド方式の初期実装版。
**主な特徴**:
- 図形形状ベースの探索ロジックに、点ベースのPCA分析手法を組み込み始めた段階のコード。
- 基本的なグループ化とPCAの実装が含まれているが、3段階検証などの最適化は未完成。
**データソース**:
`my_spectre_generator_symbolic.rb` が出力するCSVファイルを入力として使用。

### my_spectre_coordinateAnalyzer_keyed.rb
**機能概要**:
点（4D座標）単位で探索を行う「点ベース」のアプローチの実装。
**主な特徴**:
- データを「label-angle-vertex_index」のキーで詳細にグループ化。
- 各キーに対して個別にPCAを行い、局所的な凸包境界を定義。
- 先読み（Look-ahead）探索により、行き止まりを回避しつつ効率的に座標を生成。
- 柔軟性は高いが、幾何学的な整合性（14頂点のセット）の保証が弱い。
**データソース**:
`my_spectre_generator_symbolic.rb` が出力するCSVファイルを入力として使用。

### my_spectre_coordinateAnalyzer.rb
**機能概要**:
14頂点の形状単位で探索を行う「図形形状ベース」のアプローチの実装。
**主な特徴**:
- 教師データから抽出した14頂点の相対座標パターンを使用。
- 候補形状の全頂点に対してKD木を用いたKNN（k近傍法）検証を行い、データの密度に基づいてノイズを除去。
- 幾何学的な整合性は高いが、計算コストが高い。
**データソース**:
`my_spectre_generator_symbolic.rb` が出力するCSVファイルを入力として使用。

### my_spectre_substitution_analyzer.rb
**機能概要**:
Spectreタイルの置換規則（Substitution Rule）を解析し、アフィン変換行列を導出するスクリプト。
**主な特徴**:
- 親タイルと子タイルの座標関係から、4x5のアフィン変換行列（線形変換4x4 + 平行移動4x1）を最小二乗法で算出。
- 算出された行列の検証機能。
**データソース**:
`SpectreTilingGenerator` クラスの `generator.generate` メソッドのコールバック関数（`tilesHash`）および `tile.for_each_tile` メソッドのコールバック関数から取得できる値を直接使用。

---
### my_spectre_Xsub__analyzer.rb
**機能概要**:
Spectreタイルの置換規則に関連する24種類の行列（X_sub）の幾何学的性質を解析するスクリプト。
**主な特徴**:
- 行列の固有値・固有ベクトルを計算。
- 行列がユークリッド合同変換（回転・反転）であるか、体積を保存するか（det = ±1）を検証。
- 行列の総和やグラム行列（A^T A）の解析を通じて、タイリングの支配的な基底パターンを抽出。
**データソース**:
**データソース**:
スクリプト内でハードコードされた24種類の `X_sub` 行列定義（`ROTATIONS_4X4` および `FLAT_X_SUB_LISTS_24`）を使用。

**データソース詳細分析**:
1.  **`CyclotomicTransform.@@trot_memo` との関連**:
    `my_cyclotomic_strategy.rb` の `@@trot_memo` は、4次元整数座標系（円分体 $\mathbb{Q}(\zeta_{12})$ に関連する格子）上の回転群作用を定義する行列群である。`my_spectre_Xsub__analyzer.rb` の `ROTATIONS_4X4` はこれと数学的に同等（基底の取り方による符号や転置の差異はあるが、同じ60度回転群の整数表現）である。
2.  **自動生成の試みと断念**:
    `my_spectre_Xsub__analyzer.rb` の実装コード（行28-48）には、基本回転行列 `ROTATIONS_4X4` から物理空間の反転（`F_flip`）や符号反転（スケール-1）を組み合わせて24個の行列を自動生成するロジックが存在する。
3.  **ハードコード値の採用**:
    しかし、上記で生成されたリストは直後の行（行50-76）でハードコードされた配列によって上書きされている。これは、単純な対称操作の生成ロジックでは、実際のSpectre置換ルール（合計が厳密にゼロになり、かつ特定の順序を持つ24行列）を完全には再現できなかったため、ユーザー提供の「正解データ」（`FLAT_X_SUB_LISTS_24` と同等の値）を直接使用する方針に切り替えたことを示している。


### verify_spectre_projection.rb
**機能概要**:
Spectreタイルの高次元座標を補空間（Perpendicular Space）に射影し、その分布（Window/Acceptance Domain）の性質を検証・可視化するスクリプト。

**主な特徴**:
- 4次元頂点データからPCA（主成分分析）を用いて補空間の基底を再計算。
- 置換行列 `X_sub` が補空間において縮小写像（Contraction Mapping）として作用するかを特異値分解（SVD）で検証。
- 射影された点群をSVGとしてプロットし、Windowの形状を可視化。
- 凸包（Convex Hull）内部の空隙率（Void Ratio）を計算し、形状のフラクタル性（非凸性）を評価。

**データソース**:
- **入力ファイル**: `spectre-Cyclotomic_MonoChrome_Tile-5.3-14.6-4-4401tiles.svg_full_vertex.csv`（`my_spectre_generator_symbolic.rb` 等が出力した全頂点データ）。
- **内部定義**: `FLAT_X_SUB_LISTS_24`（置換行列）をハードコードで保持。

**データソース詳細分析と成果**:
1.  **基底定義の整合性（あるべき姿）**:
    -   **現状**: 入力されたCSVデータの分布からPCAを行い、補空間の基底（`p_perp_basis`）をその場で再構築している。
    -   **あるべき姿**: 本来は、座標生成に使用されたメインの解析スクリプト（`my_spectre_coordinateAnalyzer.rb`）が定義した「正解の基底」を直接インポートまたはメタデータとして読み込むべきであった。データセット（CSV）に依存して基底を再計算すると、データの偏りによって射影面が微妙にずれ、厳密な検証ができなくなるリスクがある。
2.  **置換ルールの共有**:
    -   `X_sub` 行列がここでもハードコードされている。`my_spectre_Xsub__analyzer.rb` と共通の定義ファイルを参照する設計が望ましかった。
3.  **検証によって得られた成果**:
    -   **縮小写像の確認**: 補空間に射影された `X_sub` 行列の最大特異値が 1.0 未満であることを確認。これにより、補空間において反復関数系（IFS）が収束し、フラクタルなアトラクタ（Window）が存在することが数学的に裏付けられた。
    -   **フラクタル性の示唆**: 射影された点群の凸包内部に有意な空隙（Void）が検出された。これは、Acceptance Domain が単純な凸多角形ではなく、複雑な（おそらくフラクタルな）境界を持つことを示唆しており、単純な凸包判定だけではフィルタリングとして不十分である可能性を浮き彫りにした。

---

### my3d_spectre_fit3.rb
**機能概要**:
Spectreタイルの高次元座標を3次元空間にフィッティングさせるためのスクリプト。
**主な特徴**:
- 8次元の射影係数を用いて、正20面体の頂点座標などへの適合度を評価。
- 半径偏差や最近接距離偏差を最小化するパラメータを探索。
**データソース**:
スクリプト内で生成される基底候補（`generate_base_candidates`）およびハードコードされた正20面体の頂点座標（`ICOSAHEDRON_VERTICES`）を使用。

### my_spectre_generator_for_count.rb
**機能概要**:
Spectreタイルの置換生成をシミュレーションし、各世代におけるタイル種別ごとの個数をカウントするスクリプト。
**主な特徴**:
- `GeometryStrategy` インターフェースを実装した `CountStrategy` クラスを使用。
- `CountStrategy` は幾何学計算（座標変換など）を全てダミー処理（何もしない）でオーバーライドしており、純粋にタイルの親子関係と個数の推移のみを高速に追跡する。
- 幾何計算のオーバーヘッドを排除することで、多数の世代（例: 8世代以上）のカウントを効率的に行うことが可能。
**データソース**:
`SpectreTilingGenerator` クラスの `generator.generate` メソッドのコールバック関数から取得できるタイル数情報を使用。

---

## 2. GeometryStrategyインターフェースの活用

`my_geometryStrategy_interface.rb` で定義されている `GeometryStrategy` モジュールは、`SpectreTilingGenerator` が具体的な幾何学計算の実装（座標系や変換行列の内部表現）に依存せずに動作するための抽象化層（インターフェース）を提供しています。

**主な定義メソッド**:
- `define_spectre_points`: タイルの頂点座標生成。
- `identity_transform`, `rotation_transform`, `transform_point`: アフィン変換の生成と適用。
- `compose_transforms`: 変換の合成。

**実装による使い分け**:
本プロジェクトでは、このインターフェースを通じて、目的に応じた異なる計算戦略を切り替えて使用しています。

1.  **解析用 (`CyclotomicStrategy` 等)**:
    -   `my_spectre_substitution_analyzer.rb` などで使用。
    -   円分体や高精度な数値計算を用いて、正確な座標変換や行列導出を行う。
2.  **カウント用 (`CountStrategy`)**:
    -   `my_spectre_generator_for_count.rb` で使用。
    -   全ての幾何学メソッドがダミーの点や変換を返すように実装されている。
    -   これにより、座標計算のコストをゼロにし、置換ルールの論理的な構造（親子関係）のみを高速に処理することを実現している。

---

## 3. アルゴリズムの比較検討と実装の変遷

本セクションでは、Spectreタイル座標解析アルゴリズムが「図形形状ベース」と「点ベース」の比較を経て、それらを統合した「ハイブリッド方式」へと進化した過程を記述します。

### 3.1 基本アプローチの比較検討 (`algorithm_comparison_summary.md`)

初期段階では、以下の2つの異なるアプローチが検討・実装されました。

#### A. 点ベース (`my_spectre_coordinateAnalyzer_keyed.rb`)
*   **基本思想**: 4次元空間上の個々の「点」を最小単位として扱う。
*   **メリット**: 探索の柔軟性が高く、{１辺=隣接１点}や{２辺=隣接２点まで}の先読みアルゴリズムにより効率的に座標を生成できる。
*   **デメリット**: 14頂点のセットとしての整合性チェックが弱く、ノイズが含まれる可能性がある。
*   **検証手法**: 詳細なキー（label-angle-vertex_index）ごとのPCAと凸包境界判定。

#### B. 図形形状ベース (`my_spectre_coordinateAnalyzer.rb`)
*   **基本思想**: 14頂点からなるSpectreタイルの「図形形状」を最小単位として扱う。
*   **メリット**: 幾何学的な整合性が保証され、部分的なノイズ（偽陽性）を排除できる。
*   **デメリット**: パターンマッチングと全頂点の検証が必要なため、計算コストが高い。
*   **検証手法**: 全データを用いたKD木によるKNN密度推定。

**比較結論**:
　「点ベース」での探索に、局所的に工夫を凝らしたコードよりも、「図形形状ベース」での探索の方が、効果的であることが解ったので、効率的で局所最適化に優れたのそれぞれの長所を組み合わせることで、より高性能なアルゴリズムが実現できると結論付けられました。
さらに、一つのspectre図形形状ベース単位の探索よりも、置換規則において動的に８個または７個のspectre図形または子クラスターによって構成される置換規則を動的に探索する方が、より効率的であるので、モジュール間インタフェースの再設計も伴って、リファクタリングする。

### 3.2 ハイブリッドアルゴリズムの仕様策定 (`hybrid_algorithm_specification.md`)

両者の長所を統合するための仕様が策定されました。

*   **統合の方針**:
    *   探索の基本単位は「形状」（図形形状ベースの長所）。
    *   検証プロセスに「グループ別PCA」と「共通基底」を導入（点ベースの長所）。
*   **主要機能**:
    1.  **メタデータ付きパターン抽出**: 14頂点パターンに `angle` と `scale` の情報を付加。
    2.  **グループ化**: データを `angle-scale` でグループ化し、グループ数を削減（約5000 → 24）。
    3.  **3段階検証プロセス**:
        1.  **共通基底検証**: 全データから導出した基底で大域的にフィルタリング（高速）。
        2.  **グループPCA検証**: グループ固有の基底と凸包で局所的に検証。
        3.  **KNN検証**: 最終的な密度チェック（高精度）。

### 3.3 追加要件とデータ構造の整備 (`hybrid_additional_requirements.md`, `hybrid_data_structures.md`)

実装に向けて、より具体的な要件とデータ構造が定義されました。

*   **追加要件**:
    *   初期形状をCSVの先頭データから動的に構築。
    *   メモリ効率を考慮し、大量のCSVデータを参照で扱う構造。
    *   コマンドライン引数による探索範囲の柔軟な指定。
    *   進捗の可視化（CSV逐次出力、stderrへのデバッグ情報出力）。
*   **データ構造**:
    *   `VALID_SPECTRE_PATTERNS`: パターン座標に加え、メタデータ（angle, scale, group_key）を保持。
    *   `grouped_pca_results`: グループごとの基底、凸包、KD木、閾値を保持。
    *   `ShapeInfo`: 形状の幾何学情報と、トポロジー違反（分岐）の記録用フィールドを追加。

### 3.4 実装の進捗と改善 (`implementation_status.md`, `hybrid_continuation.txt`)

仕様に基づき、`my_spectre_coordinateAnalyzer_hybrid_v2.rb` への実装が進められました。

*   **実装済み**:
    *   `ShapeInfo` クラスの拡張。
    *   メタデータ付きのパターン抽出ロジック。
    *   `rows_by_shape` によるメモリ効率の良いデータ管理。
*   **改善・修正**:
    *   **共通基底の計算**: 全グループの共分散行列を統合して算出するロジックを追加。
    *   **3段階検証の統合**: `find_valid_tile_configuration` 関数内で、コストの低い検証から順に適用するように最適化。
    *   **適応的閾値**: KNN検証において、データ密度に基づいた動的な閾値設定を導入。

### 3.5 ハイブリッドアルゴリズムの選定結果
現在の `my_spectre_coordinateAnalyzer_hybrid_v2.rb` は、図形形状ベースの幾何学的整合性と、点ベースの統計的検証手法を融合させ、計算効率と精度の両立を目指した完成形に近い実装となっています。

--- 
### my_spectre_coordinateAnalyzer_base_interface.rb
**機能概要**:
実験的なコード群（`hybrid`, `keyed` 等）から抽出された共通機能と、最も洗練された実装を集約・再設計したインターフェース定義ファイル。今後の開発のベースとなるコアライブラリ。

**再実装された機能（他ファイルとの対応）**:
1.  **コア計算ロジック (`SpectreMath`, `SpectreGeometry`, `KDTree`)**:
    *   `hybrid_v2.rb` や `keyed.rb` で個別に実装されていたベクトル演算、PCA、凸包、KNN探索（KD木）を共通モジュールとして統合。
2.  **形状表現 (`ShapeInfo`)**:
    *   `hybrid_v2.rb` の `ShapeInfo` をベースに、隣接判定（`adjacent_to?`）やパターンマッチングによる候補生成（`near_shapes_candidates`）をメソッドとしてカプセル化。
3.  **統計的検証 (`GroupStatistics`, `PCAGroupStatistics`)**:
    *   `hybrid_v2.rb` の「グループ別PCA検証」と「KNN密度検証」のロジックをクラス化。
    *   `StatisticsManager` により、形状のグループキー（angle-scale）に応じた適切な検証ルールを動的に適用可能。
4.  **データロード抽象化 (`SpectreDataLoader`)**:
    *   `hybrid_v2.rb` のCSV読み込み処理と、`substitution_analyzer.rb` のGenerator連携処理を統一的なインターフェースで扱えるように設計。

**データソースの選び方**:
`SpectreDataEnumerators` モジュールがファクトリとして機能します。
*   **既存の解析結果を利用する場合**: `SpectreDataEnumerators.from_csv(filename)` を使用。`hybrid_v2` 形式のフル頂点CSVに対応。
*   **新規に生成して解析する場合**: `SpectreDataEnumerators.from_generator(generator, generations)` を使用。`SpectreTilingGenerator` インスタンスから直接データを取得。

**Caller（呼び出し元）の実装ガイド**:
このモジュールを使用する場合、`if __FILE__ == $0` ブロックが実装のテンプレートとなります。以下の手順で Caller を実装してください。

1.  **データの準備**:
    ```ruby
    loader = SpectreDataLoader.new
    # CSVからロードする場合
    loader.load(SpectreDataEnumerators.from_csv("input.csv"))
    # または Generatorからロードする場合
    # loader.load(SpectreDataEnumerators.from_generator(generator, 4))
    ```
2.  **分析とセットアップ**:
    ```ruby
    # パターン抽出と統計情報の構築（PCA計算など）を一括実行
    loader.analyze!
    # これにより ShapeInfo.valid_patterns と ShapesUnitInfo.statistics_manager が自動的に設定されます
    ```
3.  **探索の実行**:
    ```ruby
    # 初期形状の設定
    initial_shapes = [...] 
    # 汎用探索関数の呼び出し
    SpectreRules.run_search_generic(initial_shapes, max_points, search_range)
    ```

---
