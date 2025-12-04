# Spectre座標解析アルゴリズム比較分析

## I. 処理方式の違い

### my_spectre_coordinateAnalyzer.rb（形状ベース）
- **探索単位**: 14頂点の完全なSpectreタイル形状
- **データ構造**: `ShapeInfo`クラス（頂点、重心、エッジ）
- **検証方法**: パターンマッチング + KD木によるKNN検証

### my_spectre_coordinateAnalyzer_keyed.rb（点ベース）
- **探索単位**: 個別の4D座標点
- **データ構造**: キー（label-angle-vertex_index）でグループ化
- **検証方法**: キー固有の凸包判定 + 共通基底への射影

---

## II. アルゴリズムの主な違い

### A. PCA（主成分分析）の使用方法

**形状ベース**:
- 全データに対して1回だけPCAを実行
- PC3, PC4（小さい固有値）の基底を使用してKD木を構築
- KNN検証用の2D射影空間を作成

**点ベース**:
- キーごとに独立したPCAを実行（数百～数千回）
- 各キーに固有の2D部分空間を定義
- 凸包による境界を定義

### B. 探索戦略

**形状ベース**:
1. 初期形状（Shape#0-9）から開始
2. 各形状の14個のエッジに対して24パターン（12回転×2反転）をマッチング
3. 候補形状の全14頂点をKNN検証
4. 有効な形状をキューに追加

**点ベース**:
1. 開始ノード（0,0,0,0）からFIFOキュー探索
2. 共通基底への射影で大域フィルタリング
3. 全キーの凸包に対して内部判定
4. 12方向の隣接ノードを生成し、先読みで行き止まりを回避

---

## III. ノイズ除去の工夫

### 形状ベース

**1. KNN密度ベース検証**
```ruby
# 適応的閾値設定
sample_points = x_perp_pca_raw_data.sample(100)
mean_neighbor_dists = sample_points.map do |p|
  neighbors = kd_tree.nearest_k(p, KNN_K + 1)
  neighbors.shift
  Math.sqrt(neighbors.map { |d, _| d }.sum / KNN_K)
end
avg_density = mean_neighbor_dists.sum / mean_neighbor_dists.size
KNN_THRESHOLD_ADAPTIVE = avg_density * 2.5
```
- データ密度に基づく適応的フィルタリング
- 孤立点（ノイズ）を自動的に除外

**2. 14頂点完全性チェック**
- 候補形状の全14頂点が同時に検証される
- 部分的に有効な形状は拒否される

**3. 分岐検出**
- 1つのエッジに対して複数の有効な候補が見つかった場合を記録
- トポロジー違反を追跡（エラーで停止しない）

### 点ベース

**1. キー固有の凸包境界**
- キーごとに最適化された境界を定義
- 局所的な幾何学的特徴を捉える
- 複数キーマッチ時はRMSE最小を選択

**2. 先読みによる行き止まり回避**
```ruby
# 孫ノードの有効性チェック
grandchild_possible_steps.each do |grandchild_step_vec|
  grandchild_node = neighbor_node + grandchild_step_vec
  grandchild_perp = common_basis.map { |b| 
    grandchild_node.inner_product(Vector[*b]) 
  }
  grandchild_perp_sq = grandchild_perp.map { |x| x**2 }.sum
  
  if grandchild_perp_sq <= max_window_radius_sq
    is_not_dead_end = true
    break
  end
end
```
- 探索の早期枝刈り
- 無効な経路を事前に検出

**3. 多段階フィルタリング**
- 大域残差チェック（共通基底への射影）
- 局所凸包チェック（キー固有の境界）
- RMSE選択（複数マッチ時の曖昧性解消）

---

## IV. 性能比較

### 計算量

| アルゴリズム | 時間計算量 | 空間計算量 |
|------------|-----------|-----------|
| 形状ベース | O(N × 336 × log K) | O(N × 14 + K × 2) |
| 点ベース | O(N × 12 × K × H) | O(N + K × (V + B)) |

- N: 探索済み数（形状 or ノード）
- K: KD木サイズ or キー数
- H: 凸包判定コスト
- V: キーごとのデータ点数
- B: 凸包の頂点数

### 実測性能（推定）

**形状ベース**:
- 約13,500形状 → 189,000点（13,500 × 14頂点）
- 探索時間: 約0.53秒

**点ベース**:
- 10,000点出力
- 総キュー処理数: 約15,000
- 凸包判定回数: 約10,000,000回
- 先読みによる枝刈り: 約50%削減

---

## V. よりノイズ少なくspectre図形を探すための正確さ比較

### 提案するコード変更

#### 1. 統一された評価指標の追加

```ruby
# 評価指標クラス
class AccuracyMetrics
  attr_reader :total_candidates, :noise_count, :valid_count
  
  def initialize(ground_truth_points)
    @ground_truth = Set.new(ground_truth_points.map { |p| p[0..3] })
    @total_candidates = 0
    @noise_count = 0
    @valid_count = 0
  end
  
  def add_candidate(point_4d)
    @total_candidates += 1
    
    if @ground_truth.include?(point_4d)
      @valid_count += 1
    else
      @noise_count += 1
    end
  end
  
  def compute_metrics
    {
      total: @total_candidates,
      valid: @valid_count,
      noise: @noise_count,
      precision: (@valid_count.to_f / @total_candidates).round(4),
      recall: (@valid_count.to_f / @ground_truth.size).round(4),
      f1_score: (2.0 * @valid_count / (@total_candidates + @ground_truth.size)).round(4)
    }
  end
end
```

#### 2. 共通の検証データセット

```ruby
# ground_truth.csv を読み込み
def load_ground_truth(filename)
  CSV.read(filename, headers: true).map do |row|
    [row['a0'].to_i, row['a1'].to_i, row['b0'].to_i, row['b1'].to_i]
  end
end

# 両方のスクリプトで使用
ground_truth = load_ground_truth('spectre_ground_truth.csv')
metrics = AccuracyMetrics.new(ground_truth)

# 候補点を追加
candidates.each do |shape_or_point|
  point_4d = extract_4d_coords(shape_or_point)
  metrics.add_candidate(point_4d)
end

# 結果を出力
puts "\n📊 正確さ評価:"
result = metrics.compute_metrics
puts "  総候補数: #{result[:total]}"
puts "  有効点数: #{result[:valid]}"
puts "  ノイズ数: #{result[:noise]}"
puts "  精度 (Precision): #{result[:precision]}"
puts "  再現率 (Recall): #{result[:recall]}"
puts "  F1スコア: #{result[:f1_score]}"
```

#### 3. 詳細なログ出力

```ruby
# 探索ログ
class SearchLogger
  def initialize(filename)
    @log_file = File.open(filename, 'w')
    @log_file.puts "timestamp,node,action,reason,perp_sq,key"
  end
  
  def log_accept(node, reason, perp_sq, key = nil)
    @log_file.puts "#{Time.now.to_f},#{node.to_a.join(':')},ACCEPT,#{reason},#{perp_sq},#{key}"
  end
  
  def log_reject(node, reason, perp_sq = nil)
    @log_file.puts "#{Time.now.to_f},#{node.to_a.join(':')},REJECT,#{reason},#{perp_sq},"
  end
  
  def close
    @log_file.close
  end
end

# 使用例
logger = SearchLogger.new("search_log_#{algorithm_name}.csv")

# 採用時
logger.log_accept(current_node, "KNN_PASSED", perp_sq, key)

# 拒否時
logger.log_reject(neighbor_node, "GLOBAL_RESIDUAL_EXCEEDED", perp_sq)

logger.close
```

#### 4. 比較レポート生成

```ruby
def generate_comparison_report(metrics_shape, metrics_point, output_file)
  File.open(output_file, 'w') do |f|
    f.puts "# Spectre座標解析アルゴリズム比較レポート"
    f.puts ""
    f.puts "## 形状ベース (my_spectre_coordinateAnalyzer.rb)"
    f.puts "- 総候補数: #{metrics_shape[:total]}"
    f.puts "- 有効点数: #{metrics_shape[:valid]}"
    f.puts "- ノイズ数: #{metrics_shape[:noise]}"
    f.puts "- 精度: #{metrics_shape[:precision]}"
    f.puts "- 再現率: #{metrics_shape[:recall]}"
    f.puts "- F1スコア: #{metrics_shape[:f1_score]}"
    f.puts ""
    f.puts "## 点ベース (my_spectre_coordinateAnalyzer_keyed.rb)"
    f.puts "- 総候補数: #{metrics_point[:total]}"
    f.puts "- 有効点数: #{metrics_point[:valid]}"
    f.puts "- ノイズ数: #{metrics_point[:noise]}"
    f.puts "- 精度: #{metrics_point[:precision]}"
    f.puts "- 再現率: #{metrics_point[:recall]}"
    f.puts "- F1スコア: #{metrics_point[:f1_score]}"
    f.puts ""
    f.puts "## 比較"
    noise_reduction = ((1 - metrics_shape[:noise].to_f / metrics_point[:noise]) * 100).round(2)
    f.puts "- ノイズ削減率: #{noise_reduction}%"
    precision_diff = ((metrics_shape[:precision] - metrics_point[:precision]) * 100).round(2)
    f.puts "- 精度差: #{precision_diff}%"
    f.puts "- 推奨: #{metrics_shape[:f1_score] > metrics_point[:f1_score] ? '形状ベース' : '点ベース'}"
  end
end
```

---

## VI. 結論と推奨事項

### 処理方式の違いまとめ

| 観点 | 形状ベース | 点ベース |
|------|-----------|---------|
| **探索単位** | 14頂点の完全形状 | 個別の4D点 |
| **ノイズ除去** | 幾何学的整合性 + KNN密度 | 多段階フィルタリング + 先読み |
| **強み** | 高精度、部分的偽陽性を排除 | 柔軟、局所最適化 |
| **弱み** | パターン依存、計算コスト高 | キー品質依存、凸包の限界 |

### 推奨

1. **高精度が必要な場合**: 形状ベース
   - 幾何学的整合性が保証される
   - 14頂点同時検証により部分的偽陽性を排除

2. **柔軟性が必要な場合**: 点ベース
   - キーベースの分類が可能
   - 先読みによる効率的な探索

3. **最適解**: ハイブリッドアプローチ
   - 点ベースで粗探索 → 形状ベースで精密検証
   - キー固有の凸包 + KNN密度チェックの組み合わせ
