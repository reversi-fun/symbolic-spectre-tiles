# filename= my_spectre_coordinateAnalyzer.rb

#!/usr/bin/env ruby
# my_spectre_coordinateAnalyzer.rb

require 'csv'
require 'matrix'
require 'set'
# require 'convex_hull'

# --- ユーティリティ関数 ---
def mean_vector(data)
  cols = data.transpose
  cols.map { |col| col.sum / col.size }
end

def center_data(data)
  mean = mean_vector(data)
  data.map { |row| row.zip(mean).map { |x, m| x - m } }
end

def covariance_matrix(data)
  centered = center_data(data)
  m = Matrix[*centered]
  (m.transpose * m) / data.size.to_f
end

# --- PCA -----------------------------------------------------------

# 機能概要: 主成分分析を行い、共分散行列の小さい固有値に対応する2つの固有ベクトルを返す。
# Input: data (Array<Array<Numeric>>), n_components (Integer)
# Returns: basis (Array<Array<Float>>) - 4Dベクトルの配列 (PC3, PC4など)
def pca_components(data, n_components = 2,key = "")
  return [] if data.empty?

  m = data.size
  mean = Vector.elements(data.transpose.map { |col| col.sum / m.to_f })
  centered = data.map { |row| Vector.elements(row) - mean }
  cov = Matrix.zero(4)
  centered.each { |v| cov += outer_product(v, v) }
  cov /= m.to_f

  eig = cov.eigen

  # 小さい固有値に対応する固有ベクトルを抽出
  sorted = eig.eigenvalues.zip(eig.eigenvectors)
              .sort_by { |val, _| val.abs } # 小さい固有値からソート
  # puts "  [DEBUG PCA] Key(#{key}) Size: #{data.size}, Sorted Eigenvalues (Abs): \n\t#{sorted.map { |e,v| e.abs.round(6).to_s + ":" +v.map { |x| x.round(6) }.to_a.join(',') }.join("\n\t")}"
  return sorted.first(n_components).map { |_, vec| vec.to_a }
end

def normalize(v)
  mag = Math.sqrt(v.map { |x| x**2 }.sum)
  v.map { |x| x / mag }
end

def orthogonalize(v1, v2)
  dot = v1.zip(v2).map { |a, b| a * b }.sum
  scale = dot / v1.map { |x| x**2 }.sum
  v2.zip(v1).map { |b, a| b - scale * a }
end

def least_squares(x_data, y_data, max_iter = 3, tol = 1e-6, lambda = 1e-8)

  x = Matrix[*x_data]
  y = Vector[*y_data]
  xt = x.transpose

  beta = (xt * x).inverse * xt * y
  beta.to_a

  # identity = Matrix.identity(x.column_count)

  # best_rmse = Float::INFINITY
  # best_beta = nil

  # max_iter.times do
  #   begin
  #     beta = (xt * x + lambda * identity).inverse * xt * y
  #   rescue StandardError
  #     lambda *= 10
  #     next
  #   end

  #   # 推定値とRMSEを計算
  #   y_pred = x.map { |row| row.zip(beta.to_a).map { |a, b| a * b }.sum }
  #   error = y_pred.zip(y.to_a).map { |pred, actual| (pred - actual)**2 }
  #   rmse_val = Math.sqrt(error.sum / error.size)

  #   if rmse_val < best_rmse - tol
  #     best_rmse = rmse_val
  #     best_beta = beta
  #   else
  #     break
  #   end

  #   lambda *= 10
  # end

  # best_beta ? best_beta.to_a : Array.new(x.column_count, 0.0)
end

# Helper function for outer product
def outer_product(v1, v2)
  Matrix[*v1.to_a.map { |a| v2.to_a.map { |b| a * b } }]
end

def rmse(vectors)
  Math.sqrt(vectors.map { |v| v.map { |x| x**2 }.sum }.sum / vectors.size)
end

# --- 渦巻き境界の抽出（凸包） ---
def compute_convex_hull(points)
  # points: [[x, y], [x, y], ...]
  points = points.sort_by { |x, y| [x, y] }
  return points if points.size <= 1

  cross = ->(o, a, b) {
    (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
  }

  lower = []
  points.each do |p|
    while lower.size >= 2 && cross.call(lower[-2], lower[-1], p) <= 0
      lower.pop
    end
    lower << p
  end

  upper = []
  points.reverse.each do |p|
    while upper.size >= 2 && cross.call(upper[-2], upper[-1], p) <= 0
      upper.pop
    end
    upper << p
  end

  (lower[0...-1] + upper[0...-1])
end

# --- 点が凸包の内側か判定（射影法） ---
def point_inside_polygon?(point, polygon)
  x, y = point
  inside = false
  j = polygon.size - 1
  for i in 0...polygon.size
    xi, yi = polygon[i]
    xj, yj = polygon[j]
    if ((yi > y) != (yj > y)) &&
       (x < (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi)
      inside = !inside
    end
    j = i
  end
  inside
end

# --- a1, b1 の動的範囲計算（a0, b0 から連立不等式を解く） ---
# 共通基底への射影が max_radius_sq 以下という制約から、
# 与えられた a0, b0 に対して許容される a1, b1 の範囲を計算
def calculate_a1_b1_ranges(a0, b0, common_basis, max_radius_sq)
  # 共通基底ベクトル
  basis1 = common_basis[0]  # [c0, c1, c2, c3]
  basis2 = common_basis[1]  # [d0, d1, d2, d3]

  # 許容誤差（射影の二乗和の平方根）
  tolerance = Math.sqrt(max_radius_sq)

  # 連立不等式:
  # (basis1[0]*a0 + basis1[1]*a1 + basis1[2]*b0 + basis1[3]*b1)^2 +
  # (basis2[0]*a0 + basis2[1]*a1 + basis2[2]*b0 + basis2[3]*b1)^2 <= max_radius_sq

  # a0, b0 が固定された時の定数項
  const1 = basis1[0] * a0 + basis1[2] * b0
  const2 = basis2[0] * a0 + basis2[2] * b0

  # a1, b1 の係数
  c1 = basis1[1]  # a1 の係数（第1基底）
  c3 = basis1[3]  # b1 の係数（第1基底）
  d1 = basis2[1]  # a1 の係数（第2基底）
  d3 = basis2[3]  # b1 の係数（第2基底）

  # 簡略化のため、各基底への射影を独立に扱う（保守的な推定）
  # より厳密には楕円体の制約だが、ここでは矩形領域で近似

  # 第1基底からの制約: |const1 + c1*a1 + c3*b1| <= tolerance
  # 第2基底からの制約: |const2 + d1*a1 + d3*b1| <= tolerance

  # a1 の範囲（両方の制約を満たす範囲）
  a1_ranges = []

  # 第1基底からの a1 範囲（b1 を考慮せず、保守的に）
  if c1.abs > 1e-10
    a1_range1_half = (tolerance - c3.abs * tolerance) / c1.abs
    a1_center1 = -const1 / c1
    a1_ranges << [a1_center1 - a1_range1_half, a1_center1 + a1_range1_half]
  else
    a1_ranges << [-Float::INFINITY, Float::INFINITY]
  end

  # 第2基底からの a1 範囲
  if d1.abs > 1e-10
    a1_range2_half = (tolerance - d3.abs * tolerance) / d1.abs
    a1_center2 = -const2 / d1
    a1_ranges << [a1_center2 - a1_range2_half, a1_center2 + a1_range2_half]
  else
    a1_ranges << [-Float::INFINITY, Float::INFINITY]
  end

  # 両方の制約の共通部分
  a1_min = a1_ranges.map { |r| r[0] }.max
  a1_max = a1_ranges.map { |r| r[1] }.min

  # b1 の範囲（同様の計算）
  b1_ranges = []

  if c3.abs > 1e-10
    b1_range1_half = (tolerance - c1.abs * tolerance) / c3.abs
    b1_center1 = -const1 / c3
    b1_ranges << [b1_center1 - b1_range1_half, b1_center1 + b1_range1_half]
  else
    b1_ranges << [-Float::INFINITY, Float::INFINITY]
  end

  if d3.abs > 1e-10
    b1_range2_half = (tolerance - d1.abs * tolerance) / d3.abs
    b1_center2 = -const2 / d3
    b1_ranges << [b1_center2 - b1_range2_half, b1_center2 + b1_range2_half]
  else
    b1_ranges << [-Float::INFINITY, Float::INFINITY]
  end

  b1_min = b1_ranges.map { |r| r[0] }.max
  b1_max = b1_ranges.map { |r| r[1] }.min

  # 安全のため、無限大の場合は入力データ範囲の2倍程度に制限
  {
    a1_min: a1_min.finite? ? a1_min : -100,
    a1_max: a1_max.finite? ? a1_max : 100,
    b1_min: b1_min.finite? ? b1_min : -100,
    b1_max: b1_max.finite? ? b1_max : 100
  }
end

# --- 4次元範囲チェック関数（固定境界・モニタリング用） ---
def check_4d_range(shape)
  shape.vertices.all? do |v|
    a0, a1, b0, b1 = v.to_a
    (Min_a0..Max_a0).include?(a0) &&
    (Min_a1..Max_a1).include?(a1) &&
    (Min_b0..Max_b0).include?(b0) &&
    (Min_b1..Max_b1).include?(b1)
  end
end

# --- 候補検証関数（分岐記録時の詳細チェック用） ---
# 戻り値: { valid: true/false, reason: "理由", details: {...} }
def validate_candidate_detailed(shape, common_basis, max_radius_sq, input_coords_set)
  details = {
    in_4d_range: false,
    satisfies_pca_constraint: false,
    not_in_input: false,
    all_vertices_valid: true
  }

  # 1. 4次元範囲チェック
  details[:in_4d_range] = check_4d_range(shape)
  unless details[:in_4d_range]
    return { valid: false, reason: "4D範囲外", details: details }
  end

  # 2. PCA制約（共通基底への射影）チェック
  max_proj_sq = 0.0
  shape.vertices.each do |v|
    proj = common_basis.map { |b| v.inner_product(Vector[*b]) }
    proj_sq = proj.map { |x| x**2 }.sum
    max_proj_sq = [max_proj_sq, proj_sq].max
  end
  details[:satisfies_pca_constraint] = (max_proj_sq <= max_radius_sq)
  details[:max_proj_sq] = max_proj_sq
  details[:max_radius_sq] = max_radius_sq

  unless details[:satisfies_pca_constraint]
    return { valid: false, reason: "PCA制約違反", details: details }
  end

  # 3. 教師データに含まれていない座標かチェック
  has_new_coords = shape.vertices.any? do |v|
    !input_coords_set.include?(v.to_a)
  end
  details[:not_in_input] = has_new_coords

  # すべてのチェックを通過
  { valid: true, reason: "OK", details: details }
end

# --- ShapeInfo Class ---
class ShapeInfo
  attr_reader :vertices, :centroid, :angle, :scale
  attr_accessor :invalid_connect_from

  def initialize(vertices, angle, scale)
    @vertices = vertices          # Array<Vector[a0, a1, b0, b1]>
    @centroid = calculate_centroid(vertices)
    @angle = angle                # Float
    @scale = scale                # Float
    @invalid_connect_from = []    # Array<Vector>
  end

  def calculate_centroid(vertices)
    sum = Vector[0.0, 0.0, 0.0, 0.0]
    vertices.each { |v| sum += v }
    sum / vertices.size.to_f
  end

  def edges
    Enumerator.new do |y|
      @vertices.each_cons(2) { |v1, v2| y << [v1, v2] }
      y << [@vertices.last, @vertices.first]
    end
  end

  def group_key
    "#{@angle.round(6)}-#{@scale.round(6)}"
  end
end

# --- 渦巻き境界の抽出（凸包） ---
# KNN検索のためのKD木の実装
class KDTree
  Node = Struct.new(:point, :left, :right, :axis)

  def initialize(points)
    @root = build_tree(points, 0)
  end

  def build_tree(points, depth)
    return nil if points.empty?

    axis = depth % 2 # 2次元なので axis は 0(x) か 1(y)
    points.sort_by! { |p| p[axis] }
    median = points.size / 2

    Node.new(
      points[median],
      build_tree(points[0...median], depth + 1),
      build_tree(points[median+1..-1], depth + 1),
      axis
    )
  end

  def nearest_k(target, k)
    best_nodes = [] # [distance_sq, point] のリスト
    search_recursive(@root, target, k, best_nodes)
    best_nodes.sort_by { |d, _| d }
  end

  private

  def search_recursive(node, target, k, best_nodes)
    return unless node

    dist_sq = (node.point[0] - target[0])**2 + (node.point[1] - target[1])**2

    # 候補リストに追加・更新
    if best_nodes.size < k
      best_nodes << [dist_sq, node.point]
      best_nodes.sort_by! { |d, _| -d } # 距離の降順（末尾が最大距離）
    elsif dist_sq < best_nodes.first[0]
      best_nodes[0] = [dist_sq, node.point]
      best_nodes.sort_by! { |d, _| -d }
    end

    axis = node.axis
    diff = target[axis] - node.point[axis]

    near_node = diff < 0 ? node.left : node.right
    far_node = diff < 0 ? node.right : node.left

    search_recursive(near_node, target, k, best_nodes)

    # 反対側の枝を探索する必要があるか？
    # 現在のk個目の候補よりも、分割軸までの距離が近ければ、反対側にもっと近い点があるかもしれない
    if best_nodes.size < k || diff**2 < best_nodes.first[0]
      search_recursive(far_node, target, k, best_nodes)
    end
  end
end

# KNNによる判定関数
# k=5 程度の近傍点との平均距離が、閾値以下なら「有効」とみなす
# 閾値は window_radius の何割か、あるいはデータ密度から自動推定する
# ここでは window_radius (最大半径) ではなく、平均的な点間距離を基準にするのが良いが、
# 簡易的に window_radius * 係数 で試す。
KNN_K = 5
def is_valid_point_knn?(point, kd_tree, knn_threshold)
  neighbors = kd_tree.nearest_k(point, KNN_K)
  return false if neighbors.size < KNN_K

  # 平均距離
  mean_dist = Math.sqrt(neighbors.map { |d, _| d }.sum / KNN_K)
  mean_dist < knn_threshold
end

# --- コマンドライン引数チェック ---
# if ARGV.empty?
#   puts "❗ ファイル名を指定してください: ruby spectre_coordinate_analyzer.rb input.csv"
#   exit
# end

filename = ARGV[0] || 'spectre-Cyclotomic_MonoChrome_Tile-5.3-14.6-4-4401tiles.svg_full_vertex.csv'

# --- ステップ1: データ読み込み ---
columns = ['pt0-coef:a0', 'a1', 'b0', 'b1']

raw_data = CSV.read(filename, headers: true)
data = raw_data.map { |row| columns.map { |col| row[col].to_f } }

puts "✅ #{filename} \n\tデータ読み込み完了。形状: #{data.size}行 × #{columns.size}列"

# --- ステップ1.5: 入力座標セットの構築 ---
puts "\n📍 入力座標セットを構築中..."
input_coords_set = Set.new
input_coord_bounds = {
  a0_min: Float::INFINITY, a0_max: -Float::INFINITY,
  a1_min: Float::INFINITY, a1_max: -Float::INFINITY,
  b0_min: Float::INFINITY, b0_max: -Float::INFINITY,
  b1_min: Float::INFINITY, b1_max: -Float::INFINITY
}

raw_data.each do |row|
  a0 = row['pt0-coef:a0'].to_f
  a1 = row['a1'].to_f
  b0 = row['b0'].to_f
  b1 = row['b1'].to_f

  # 座標をセットに追加（重複排除）
  input_coords_set << [a0, a1, b0, b1]

  # 境界値の更新
  input_coord_bounds[:a0_min] = [input_coord_bounds[:a0_min], a0].min
  input_coord_bounds[:a0_max] = [input_coord_bounds[:a0_max], a0].max
  input_coord_bounds[:a1_min] = [input_coord_bounds[:a1_min], a1].min
  input_coord_bounds[:a1_max] = [input_coord_bounds[:a1_max], a1].max
  input_coord_bounds[:b0_min] = [input_coord_bounds[:b0_min], b0].min
  input_coord_bounds[:b0_max] = [input_coord_bounds[:b0_max], b0].max
  input_coord_bounds[:b1_min] = [input_coord_bounds[:b1_min], b1].min
  input_coord_bounds[:b1_max] = [input_coord_bounds[:b1_max], b1].max
end

puts "✅ 入力座標セット構築完了: #{input_coords_set.size}個のユニークな座標"
puts "📏 入力データの4次元境界:"
puts "  a0: [#{input_coord_bounds[:a0_min].round(2)}, #{input_coord_bounds[:a0_max].round(2)}]"
puts "  a1: [#{input_coord_bounds[:a1_min].round(2)}, #{input_coord_bounds[:a1_max].round(2)}]"
puts "  b0: [#{input_coord_bounds[:b0_min].round(2)}, #{input_coord_bounds[:b0_max].round(2)}]"
puts "  b1: [#{input_coord_bounds[:b1_min].round(2)}, #{input_coord_bounds[:b1_max].round(2)}]"

# --- ステップ1.6: データグループ化 (angle × scale) ---
puts "\n📊 データをangle×scaleでグループ化中..."
data_groups = Hash.new { |h, k| h[k] = [] }

raw_data.each do |row|
  coord = [row['pt0-coef:a0'].to_f, row['a1'].to_f, row['b0'].to_f, row['b1'].to_f]
  angle = row['angle'].to_f
  scale = row['scale_y'].to_f
  group_key = "#{angle.round(6)}-#{scale.round(6)}"

  data_groups[group_key] << { coords: coord, angle: angle, scale: scale }
end

puts "✅ #{data_groups.size}個のグループに分類されました。"
data_groups.each do |key, group|
  puts "  グループ #{key}: #{group.size}点"
end

# --- ステップ2: PCA ---
# --- ステップ2: PCA方式から係数と基底を導出 ---
# --- ステップ2: キーごとにPCA分析を実行 ---
puts "\n🔬 グループごとのPCA分析を実行中..."
grouped_pca_results = Hash.new()
data_groups.each do |key, group|
  coords_data = group.map { |g| g[:coords] }

  if coords_data.size <= 1
    # 0点または1点の場合、基底は空、RMSE=0、境界は元の点
    grouped_pca_results[key] = { basis: [], rmse: 0, boundary: coords_data}
    p ["debug at {grouped_pca_results}", key, coords_data]
  else
    begin
      # 最小固有値2つに対応する基底 (PC3, PC4) を取得
      basis = pca_components(coords_data, 2, key)
      use_basis = basis[0..1]
      # use_basis = basis[0..1]

      # 4D座標をPC3, PC4空間に射影
      proj_points = coords_data.map { |row| use_basis.map { |b| row.zip(b).map { |a,bb| a*bb }.sum } }

      rmse_val = rmse(proj_points)
      boundary = compute_convex_hull(proj_points)

      # KD木の構築（このグループ専用）
      kd_tree = KDTree.new(proj_points)

      # KNN閾値の計算（このグループ専用）
      sample_points = proj_points.sample([100, proj_points.size].min)
      mean_neighbor_dists = sample_points.map do |p|
        neighbors = kd_tree.nearest_k(p, KNN_K + 1)  # 自分自身を含む
        neighbors.shift  # 自分自身を除く
        Math.sqrt(neighbors.map { |d, _| d }.sum / KNN_K)
      end
      avg_density = mean_neighbor_dists.sum / mean_neighbor_dists.size
      threshold = avg_density * 2.5

      grouped_pca_results[key] = {
        basis: use_basis,
        rmse: rmse_val,
        boundary: boundary,
        kd_tree: kd_tree,
        threshold: threshold
      }
    rescue StandardError => e
      p ["debug at {grouped_pca_results-error}", key, e]
      next
    end
  end
end

puts "✅ #{grouped_pca_results.size}グループのPCA分析完了。"

# --- ステップ2.5: 共通基底の計算 ---
puts "\n🌐 共通基底を計算中..."

total_n = 0
total_mean = Vector[0.0, 0.0, 0.0, 0.0]
total_cov_sum = Matrix.zero(4)

data_groups.each_value do |coords_array|
  n = coords_array.size
  next if n < 2

  coords = coords_array.map { |c| Vector[*c[:coords]] }
  mean_i = coords.reduce(Vector[0.0, 0.0, 0.0, 0.0], :+) / n.to_f

  cov_i = Matrix.zero(4)
  coords.each do |v|
    dv = v - mean_i
    cov_i += outer_product(dv, dv)
  end
  cov_i /= n.to_f

  total_mean += mean_i * n
  total_cov_sum += (cov_i + outer_product(mean_i, mean_i)) * n
  total_n += n
end

mean_global = total_mean / total_n.to_f
cov_global = (total_cov_sum / total_n.to_f) - outer_product(mean_global, mean_global)

eig = cov_global.eigen
vals = eig.eigenvalues
vecs = eig.eigenvectors.map(&:to_a)

# 小さい固有値の2つを選択
sorted = vals.zip(vecs).sort_by { |v, _| v.abs }
common_basis = sorted.first(2).map { |_, v| v }

# 99パーセンタイル閾値の計算
all_radii_sq = []
data_groups.each_value do |coords_array|
  coords_array.each do |c|
    coords = c[:coords]
    proj = common_basis.map { |b| coords.zip(b).map { |a, bb| a * bb }.sum }
    r_sq = proj.map { |x| x**2 }.sum
    all_radii_sq << r_sq
  end
end
all_radii_sq.sort!
max_radius_sq = all_radii_sq[all_radii_sq.size * 99 / 100]

puts "✅ 共通基底の計算完了。"
puts "  固有値: #{sorted.map { |v, _| format('%.6f', v) }.join(', ')}"
puts "  最大射影半径² (99%ile): #{max_radius_sq.round(6)}"

# --- ステップ3: 14頂点パターンの抽出 ---
puts "\n🧩 14頂点パターンの抽出を開始..."

# 探索範囲定数（入力データの境界から自動計算）
# 入力データを包含するように、各次元に余裕を持たせる
margin_a0 = (input_coord_bounds[:a0_max] - input_coord_bounds[:a0_min]) * 0.1
margin_a1 = (input_coord_bounds[:a1_max] - input_coord_bounds[:a1_min]) * 0.1
margin_b0 = (input_coord_bounds[:b0_max] - input_coord_bounds[:b0_min]) * 0.1
margin_b1 = (input_coord_bounds[:b1_max] - input_coord_bounds[:b1_min]) * 0.1

relative_range_a0 = [
  input_coord_bounds[:a0_min] - margin_a0,
  input_coord_bounds[:a0_max] + margin_a0
]
relative_range_b0 = [
  input_coord_bounds[:b0_min] - margin_b0,
  input_coord_bounds[:b0_max] + margin_b0
]

puts "📏 探索範囲（入力データ境界+10%マージン）:"
puts "  a0: [#{relative_range_a0[0].round(2)}, #{relative_range_a0[1].round(2)}]"
puts "  b0: [#{relative_range_b0[0].round(2)}, #{relative_range_b0[1].round(2)}]"

find_start_time = Time.now

# max_pointsを入力データの点数の2倍に自動設定
max_points = input_coords_set.size * 2
puts "\n🎯 探索目標: #{max_points}点 (入力データ #{input_coords_set.size}点 × 2)"

# カバレッジ目標
target_coverage = 0.95  # 95%のカバレッジを目標
puts "📊 カバレッジ目標: #{(target_coverage * 100).round(1)}%"

# shape# ごとに vertex_index -1 ～ -14 の行をグループ化
rows_by_shape = Hash.new { |h, k| h[k] = [] }

raw_data.each do |row|
  # BOM対策: shape# カラム名が \uFEFFshape# になっている可能性がある
  shape_id = row['shape#'] || row["\uFEFFshape#"]
  if shape_id.nil?
    # ヘッダーが見つからない場合のデバッグ
    puts "⚠️ Row #{row.inspect} has no shape# key. Keys: #{row.headers}" if rows_by_shape.empty?
    next
  end
  v_idx = row['vertex_index'].to_i
  next unless (-14..-1).include?(v_idx)

  # 座標 (a0, a1, b0, b1) + angle/scale
  coord = [row['pt0-coef:a0'].to_f, row['a1'].to_f, row['b0'].to_f, row['b1'].to_f]
  angle = row['angle'].to_f
  scale = row['scale_y'].to_f
  rows_by_shape[shape_id] << { idx: v_idx, coord: coord, angle: angle, scale: scale }
end

VALID_SPECTRE_PATTERNS = []

rows_by_shape.each do |shape_id, rows|
  # -1 から -14 まで揃っているか確認
  indices = rows.map { |r| r[:idx] }.sort.reverse
  if indices != (-14..-1).to_a.reverse
    # 欠落がある場合はスキップ
    next
  end

  original_points = (-14..-1).to_a.reverse.map{|idx| rows.find { |r| r[:idx] == idx }[:coord]}

  # 最初の行からangle/scaleを取得
  first_row = rows.find { |r| r[:idx] == -1 }
  angle = first_row[:angle]
  scale = first_row[:scale]
  group_key = "#{angle.round(6)}-#{scale.round(6)}"

  base_vector = Vector[*original_points[0]]
  pattern = original_points.map{|p| Vector[*p] - base_vector}

  VALID_SPECTRE_PATTERNS << {
    pattern: pattern,
    angle: angle,
    scale: scale,
    group_key: group_key
  }
end

# 重複排除（相対座標とgroup_keyのセットとして同じなら1つにまとめる）
VALID_SPECTRE_PATTERNS.uniq! { |p| [p[:pattern].map(&:to_a), p[:group_key]] }

puts "✅ 抽出されたユニークなSpectreパターン数: #{VALID_SPECTRE_PATTERNS.size}"
if VALID_SPECTRE_PATTERNS.size < 24
  puts "⚠️ 警告: 全24パターン（12回転×2裏表）が揃っていません。存在するパターンのみで探索します。"
end

# パターンの表示
VALID_SPECTRE_PATTERNS.each_with_index do |pat, i|
  puts "Pattern #{i+1}: #{pat.map(&:to_a).inspect}"
end



# --- ステップ5: 幾何学的・優先度付き探索 ---
# puts "\n💡 幾何学的ルールを適用した優先度付き探索を開始します..."

# candidates = []
# generated_integer_coords = []

# Start_node = Vector[0, 0, 0, 0]
# # 優先度付きキューとして、常にソート済みの配列を維持する
# # キューの要素: [優先度, 現在座標(Vector), 親座標(Vector) | nil]
# priority_queue = [[0.0, Start_node, nil]]
# visited = Set[Start_node]

# while !priority_queue.empty? && candidates.size < max_points
#   # 最も優先度の低い（＝有望な）ノードを取り出す
#   priority, current_node, parent_node = priority_queue.shift

#   # --- 採用処理 ---
#   # 窓の内側のチェックは不要（キュー追加時に済んでいるため）
#   candidates << current_node.to_a + ( P_perp_basis.map { |basis| current_node.inner_product(Vector[*basis]) })
#   generated_integer_coords << current_node.to_a

#   if candidates.size % 5000 == 0
#     puts "   ... #{candidates.size} 個の頂点を生成済み。キューのサイズ: #{priority_queue.size}"
#   end

#   # --- 次の候補点を、文脈に応じて絞り込む ---
#   prev_step = parent_node ? current_node - parent_node : nil

#   next_possible_steps = if prev_step.nil?
#     EDGE_1ST_VECTORS # 始点からは12方向全て
#   else
#     LEGAL_NEXT_STEPS[prev_step] || [] # ルールにない場合は空配列
#   end

#   next_possible_steps.each do |step_vec|
#     neighbor_node = current_node + step_vec

#     # 訪問済みチェックと範囲チェック
#     next if visited.include?(neighbor_node)
#     next unless (Min_a0..Max_a0).include?(neighbor_node[0]) && (Min_b0..Max_b0).include?(neighbor_node[2])

#     visited << neighbor_node

#     perp = P_perp_basis.map { |basis| neighbor_node.inner_product(Vector[*basis]) }
#     neighbor_priority = Math.sqrt(perp.map { |x| x**2 }.sum)
#     if neighbor_priority < window_radius &&
#       point_inside_polygon?(perp, boundary_polygon)   # ✅ 渦巻きの内側 → 採用
#       priority_queue << [neighbor_priority, neighbor_node, current_node]
#     end
#   end
# end
# 💾 生成された4D整数座標を 13526個、'generated_spectre_integer_coords3.csv' に保存中... ["spectre座標　探索時間", 0.5301304]

# --- ステップ5: FIFOキューと先読みによる探索 ---
puts "\n💡 FIFOキューと14ステップ形状チェックによる探索を開始します..."

# パフォーマンス・トレース用変数
$perf_stats = {
  check_count: 0,
  prune_counts: Hash.new(0), # 何手目で枝刈りされたか
  valid_tile_found: 0,
  duplicates_found: 0
}

# --- 3段階検証関数 ---

# 共通基底検証（大域フィルタリング - 最優先）
# 理由: 最も高速で、大部分の無効な候補を排除できる
def validate_with_common_basis(shape, common_basis, max_radius_sq, debug_stats)
  debug_stats[:common_basis_checks] += 1

  shape.vertices.each do |v|
    proj = common_basis.map { |b| v.inner_product(Vector[*b]) }
    proj_sq = proj.map { |x| x**2 }.sum

    if proj_sq > max_radius_sq
      debug_stats[:common_basis_rejected] += 1
      return false
    end
  end

  true
end

# PCA検証（グループ固有の凸包境界）
def validate_with_group_pca(shape, pca_result, debug_stats)
  if pca_result.nil?
    STDERR.puts "⚠️ 警告: グループ #{shape.group_key} が存在しません"
    debug_stats[:missing_groups] ||= Set.new
    debug_stats[:missing_groups] << shape.group_key
    return true  # グループが存在しない場合はスキップ
  end

  debug_stats[:pca_checks] += 1

  # 全14頂点を検証
  shape.vertices.each do |v|
    # グループ固有の基底への射影
    proj = pca_result[:basis].map { |b| v.inner_product(Vector[*b]) }
    proj_sq = proj.map { |x| x**2 }.sum

    # RMSE閾値チェック
    if proj_sq > (pca_result[:rmse] * 2)**2
      debug_stats[:pca_rejected] += 1
      return false
    end

    # 凸包境界チェック
    unless point_inside_polygon?(proj, pca_result[:boundary])
      debug_stats[:pca_rejected] += 1
      return false
    end
  end

  true
end

# KNN検証（密度チェック - グループ固有のKD木と閾値を使用）
def validate_with_knn(shape, pca_result, debug_stats)
  return true if pca_result.nil?  # グループが存在しない場合はスキップ

  debug_stats[:knn_checks] += 1

  kd_tree = pca_result[:kd_tree]
  threshold = pca_result[:threshold]

  shape.vertices.each do |v|
    # グループ固有の基底への射影（PCA検証と同じ空間）
    pt_perp = pca_result[:basis].map { |b| v.inner_product(Vector[*b]) }

    unless is_valid_point_knn?(pt_perp, kd_tree, threshold)
      debug_stats[:knn_rejected] += 1
      return false
    end
  end

  true
end

# 14ステップ整合性チェック関数 (Shape-based with 3-stage validation)
# current_shape_info: 現在のShapeInfoオブジェクト
# 戻り値: [new_shape_infos] (新しく見つかったShapeInfoのリスト)
def find_valid_tile_configuration(current_shape_info, visited, grouped_pca_results, common_basis, max_radius_sq, debug_stats, input_coords_set)
  new_shapes = []

  current_shape_info.edges.each do |v1, v2|
    edge_vec = v2 - v1
    # このエッジに対して見つかった新規候補
    candidates_for_edge = []

    # VALID_SPECTRE_PATTERNS の中から、このエッジにマッチするものを探す
    VALID_SPECTRE_PATTERNS.each do |pattern_info|
      pattern = pattern_info[:pattern]
      angle = pattern_info[:angle]
      scale = pattern_info[:scale]
      group_key = pattern_info[:group_key]

      14.times do |i|
        p_start = pattern[i]
        p_end = pattern[(i + 1) % 14]
        p_vec = p_start - p_end

        next unless p_vec == edge_vec

        # 配置のためのオフセット計算
        offset = v2 - p_start

        # 候補形状の頂点を計算
        candidate_points = pattern.map { |v| v + offset }
        candidate_shape = ShapeInfo.new(candidate_points, angle, scale)

        # 訪問済みチェック
        next if visited.include?(candidate_shape.centroid)

        # 範囲チェック（4次元固定境界・モニタリング用）
        in_range = check_4d_range(candidate_shape)
        next unless in_range

        # ========== ハイブリッド検証（効率的な順序） ==========

        # 1. 共通基底検証（最も高速、大域フィルタリング）
        next unless validate_with_common_basis(candidate_shape, common_basis, max_radius_sq, debug_stats)

        # 2. PCA検証（グループ固有、凸包境界）
        pca_result = grouped_pca_results[group_key]
        next unless validate_with_group_pca(candidate_shape, pca_result, debug_stats)

        # 3. KNN検証（最も時間がかかる、密度チェック）
        next unless validate_with_knn(candidate_shape, pca_result, debug_stats)

        # 全検証通過
        debug_stats[:all_checks_passed] += 1
        candidates_for_edge << candidate_shape
      end
    end

    # 分岐記録: 1つのエッジに対して2つ以上の新規候補が見つかったら記録
    if candidates_for_edge.uniq { |s| s.centroid }.size >= 2
      debug_stats[:branch_detected] += 1
      puts "⚠️ 分岐検出: エッジ #{v1} -> #{v2} に対して #{candidates_for_edge.size} 個の新規候補が見つかりました。"

      # 詳細検証を行い、無効な候補を除外
      valid_candidates = []
      candidates_for_edge.each do |s|
        validation = validate_candidate_detailed(s, common_basis, max_radius_sq, input_coords_set)

        if validation[:valid]
          valid_candidates << s
          s.invalid_connect_from << current_shape_info.centroid
        else
          puts "   ❌ 候補除外: #{validation[:reason]} (詳細: #{validation[:details]})"
        end
      end

      # 有効な候補のみを残す
      candidates_for_edge = valid_candidates
      puts "   ➡️ 有効な候補数: #{candidates_for_edge.size}"
    end

    new_shapes.concat(candidates_for_edge)
  end

  new_shapes
end

# --- メイン探索ループ ---

# 初期化
# 初期化: CSVからShape#0～Shape#9を読み込む
initial_shapes = []
(0..9).each do |id|
  rows = rows_by_shape[id.to_s]
  if rows.empty?
    puts "⚠️ Shape##{id} not found in CSV."
    next
  end
  # vertex_index -14..-1 の順にソートして座標を取得
  sorted_rows = rows.sort_by { |r| -r[:idx] } # -1, -2, ..., -14 の順?
  # ShapeInfoは頂点順序に依存するため、CSVのvertex_indexの順序(-1, -2, ...)に従うか、
  # VALID_SPECTRE_PATTERNSの抽出ロジック(-14..-1のreverse => -1, -2...)に合わせる必要がある。
  # ここでは vertex_index の降順 (-1, -2, ..., -14) で取得する (VALID_SPECTRE_PATTERNSと同じ)

  vertices = (-14..-1).to_a.reverse.map do |idx|
    row = rows.find { |r| r[:idx] == idx }
    unless row
      raise "❌ Shape##{id}: vertex_index #{idx} is missing."
    end
    Vector[*row[:coord]]
  end
  p rows
  initial_shapes << ShapeInfo.new(vertices, rows[0][:angle], rows[0][:scale])
end

if initial_shapes.empty?
  raise "❌ 初期形状(Shape#0-9)が見つかりませんでした。"
end

start_shape = initial_shapes[0] # Shape#0 (基準)

# 探索範囲の設定 (Shape#0を基準に設定)
Min_a0 = start_shape.vertices.min_by { |v| v[0] }[0] + relative_range_a0[0]
Max_a0 = start_shape.vertices.max_by { |v| v[0] }[0] + relative_range_a0[1]
Min_b0 = start_shape.vertices.min_by { |v| v[2] }[2] + relative_range_b0[0]
Max_b0 = start_shape.vertices.max_by { |v| v[2] }[2] + relative_range_b0[1]
Min_a1 = input_coord_bounds[:a1_min] - margin_a1
Max_a1 = input_coord_bounds[:a1_max] + margin_a1
Min_b1 = input_coord_bounds[:b1_min] - margin_b1
Max_b1 = input_coord_bounds[:b1_max] + margin_b1

puts "📏 探索範囲: a0=[#{Min_a0}, #{Max_a0}], a1=[#{Min_a1}, #{Max_a1}], b0=[#{Min_b0}, #{Max_b0}], b1=[#{Min_b1}, #{Max_b1}]"

# 初期化: visited と queue
visited = Set.new
queue = []
candidates = [] # ShapeInfo objects

# デバッグ統計情報の初期化
debug_stats = {
  total_queue_processed: 0,
  common_basis_checks: 0,
  common_basis_rejected: 0,
  pca_checks: 0,
  pca_rejected: 0,
  knn_checks: 0,
  knn_rejected: 0,
  all_checks_passed: 0,
  branch_detected: 0,
  shapes_by_group: Hash.new(0),  # グループごとの採用数
  missing_groups: Set.new
}

initial_shapes.each_with_index do |shape, i|
  # 範囲チェック
  shape.vertices.each do |pt|
    unless (Min_a0..Max_a0).include?(pt[0]) && (Min_b0..Max_b0).include?(pt[2])
      puts "❌ エラー: Shape##{i} の頂点 #{pt} が探索範囲外です。"
      exit
    end
  end

  visited << shape.centroid
  candidates << shape # Store ShapeInfo object
  debug_stats[:shapes_by_group][shape.group_key] += 1

  # Shape#0 は探索済み(展開元としない)とするため、queueには入れない
  # Shape#1 ～ Shape#9 を queue に入れる
  if i > 0
    queue.push(shape)
  end
end

puts "\n🚀 ハイブリッド探索を開始します..."
puts "   初期形状数: #{initial_shapes.size} (Shape#0-9)"
puts "   グループ数: #{grouped_pca_results.size}"
puts "   Queueサイズ: #{queue.size} (Shape#1-9)"

# 生成された座標を追跡（カバレッジ計算用）
generated_coords_set = Set.new
initial_shapes.each do |shape|
  shape.vertices.each { |v| generated_coords_set << v.to_a }
end

# カバレッジ統計
coverage_stats = {
  last_report_size: 0,
  last_coverage: 0.0
}

while !queue.empty? && candidates.size < max_points
  current_shape = queue.shift
  debug_stats[:total_queue_processed] += 1

  begin
    new_shapes = find_valid_tile_configuration(
      current_shape, visited, grouped_pca_results, common_basis, max_radius_sq, debug_stats, input_coords_set
    )

    new_shapes.each do |shape|
      next if visited.include?(shape.centroid) # 二重チェック

      visited << shape.centroid
      queue.push(shape)
      candidates << shape # Store ShapeInfo object
      debug_stats[:shapes_by_group][shape.group_key] += 1

      # 生成座標を追跡
      shape.vertices.each { |v| generated_coords_set << v.to_a }
    end
  rescue RuntimeError => e
    puts e.message
    break
  end

  # カバレッジ計算と進捗表示（100形状ごと）
  if candidates.size % 100 == 0
    matched_coords = input_coords_set & generated_coords_set
    current_coverage = matched_coords.size.to_f / input_coords_set.size

    puts "   ... #{candidates.size} 個の形状を生成済み。キュー: #{queue.size}, カバレッジ: #{(current_coverage * 100).round(2)}%"

    coverage_stats[:last_report_size] = candidates.size
    coverage_stats[:last_coverage] = current_coverage

    # 目標カバレッジ達成で早期終了
    if current_coverage >= target_coverage
      puts "\n🎉 目標カバレッジ達成！ (#{(current_coverage * 100).round(2)}% >= #{(target_coverage * 100).round(1)}%)"
      puts "   探索を終了します。"
      break
    end
  end
end

# 最終カバレッジ計算
final_matched = input_coords_set & generated_coords_set
final_coverage = final_matched.size.to_f / input_coords_set.size

puts "✅ 探索完了: #{candidates.size} 形状出力"
puts "📊 最終カバレッジ: #{(final_coverage * 100).round(2)}% (#{final_matched.size}/#{input_coords_set.size}点)"
puts "\n" + "="*60
puts "[DEBUG PERFORMANCE STATISTICS]"
puts "="*60

puts "\n📊 探索統計:"
puts "  総キュー処理数: #{debug_stats[:total_queue_processed]}"

puts "\n🔍 検証統計:"
puts "  共通基底検証実行回数: #{debug_stats[:common_basis_checks]}"
puts "  共通基底検証排除数: #{debug_stats[:common_basis_rejected]}"
puts "  PCA検証実行回数: #{debug_stats[:pca_checks]}"
puts "  PCA検証排除数: #{debug_stats[:pca_rejected]}"
puts "  KNN検証実行回数: #{debug_stats[:knn_checks]}"
puts "  KNN検証排除数: #{debug_stats[:knn_rejected]}"
puts "  全検証通過数: #{debug_stats[:all_checks_passed]}"

puts "\n⚠️ 分岐検出:"
puts "  分岐検出回数: #{debug_stats[:branch_detected]}"

if debug_stats[:missing_groups].any?
  puts "\n⚠️ 警告: 以下のグループが見つかりませんでした:"
  debug_stats[:missing_groups].each { |g| puts "    #{g}" }
end

puts "\n📈 グループ別採用数:"
debug_stats[:shapes_by_group].sort_by { |k, v| -v }.each do |key, count|
  puts "  #{key}: #{count} 形状"
end

puts "\n💡 効率分析:"
total_checks = debug_stats[:common_basis_checks] + debug_stats[:pca_checks] + debug_stats[:knn_checks]
total_rejected = debug_stats[:common_basis_rejected] + debug_stats[:pca_rejected] + debug_stats[:knn_rejected]

puts "  総検証回数: #{total_checks}"
puts "  総排除数: #{total_rejected}"
puts "  排除率: #{total_checks > 0 ? (total_rejected.to_f / total_checks * 100).round(2) : 0}%"

if debug_stats[:common_basis_checks] > 0
  cb_efficiency = (debug_stats[:common_basis_rejected].to_f / debug_stats[:common_basis_checks] * 100).round(2)
  puts "  共通基底検証排除率: #{cb_efficiency}%"
end

if debug_stats[:pca_checks] > 0
  pca_efficiency = (debug_stats[:pca_rejected].to_f / debug_stats[:pca_checks] * 100).round(2)
  puts "  PCA検証排除率: #{pca_efficiency}%"
end

if debug_stats[:knn_checks] > 0
  knn_efficiency = (debug_stats[:knn_rejected].to_f / debug_stats[:knn_checks] * 100).round(2)
  puts "  KNN検証排除率: #{knn_efficiency}%"
end

puts "="*60

########################

# --- ステップ6: CSV保存 ---
output_filename = "generated_spectre_integer_coords3.csv"
puts "\n💾 生成された形状を #{candidates.size}個、'#{output_filename}' に保存中..."

# 統計カウンタ
comparison_stats = {
  in_input: 0,
  extra: 0,
  total: 0
}

CSV.open(output_filename, 'w') do |csv|
  # ヘッダー行（12カラム形式: 比較列を追加）
  csv << ['a0', 'a1', 'b0', 'b1', 'key', 'perp_x', 'perp_y', 'perp_sq', 'perp_x_common', 'perp_y_common', 'in_input', 'is_extra']

  candidates.each do |shape|
    group_key = shape.group_key
    pca_result = grouped_pca_results[group_key]

    # 各頂点を出力
    shape.vertices.each do |v|
      a0, a1, b0, b1 = v.to_a

      # 入力データとの比較
      coord_array = [a0, a1, b0, b1]
      in_input = input_coords_set.include?(coord_array)
      is_extra = !in_input

      # 統計更新
      comparison_stats[:total] += 1
      comparison_stats[:in_input] += 1 if in_input
      comparison_stats[:extra] += 1 if is_extra

      # グループ固有の基底への射影（perp_x, perp_y, perp_sq）
      if pca_result && pca_result[:basis].any?
        perp_local = pca_result[:basis].map { |b| v.inner_product(Vector[*b]) }
        perp_x = perp_local[0]
        perp_y = perp_local[1]
        perp_sq = perp_local.map { |x| x**2 }.sum
      else
        perp_x = 0.0
        perp_y = 0.0
        perp_sq = 0.0
      end

      # 共通基底への射影（perp_x_common, perp_y_common）
      perp_common = common_basis.map { |b| v.inner_product(Vector[*b]) }
      perp_x_common = perp_common[0]
      perp_y_common = perp_common[1]

      # CSV行の出力（比較列を含む）
      csv << [a0, a1, b0, b1, group_key, perp_x, perp_y, perp_sq, perp_x_common, perp_y_common, in_input, is_extra]
    end
  end
end

total_points = candidates.sum { |s| s.vertices.size }
puts "✅ CSV出力完了: #{output_filename} (#{total_points}点)"

# 比較統計の出力
puts "\n📊 入力データとの比較統計:"
puts "  総出力点数: #{comparison_stats[:total]}"
puts "  入力データに存在: #{comparison_stats[:in_input]} (#{(comparison_stats[:in_input].to_f / comparison_stats[:total] * 100).round(2)}%)"
puts "  探索結果の余分な点: #{comparison_stats[:extra]} (#{(comparison_stats[:extra].to_f / comparison_stats[:total] * 100).round(2)}%)"
puts "  入力データの未発見点: #{input_coords_set.size - comparison_stats[:in_input]}"

p ["spectre座標　探索時間", Time.now - find_start_time]

puts "✅ 保存完了！"

require 'gnuplot'

# plot_filename = "spectre_plot.png"
# puts "\n📈 グラフを '#{plot_filename}' に描画中..."

# Gnuplot.open do |gp|
#   Gnuplot::Plot.new(gp) do |plot|
#     plot.term "png size 800,800"
#     plot.output plot_filename
#     plot.title "Spectre Tiling via Best-Fit Projection"
#     plot.xlabel "perp_x"
#     plot.ylabel "perp_y"
#     plot.grid
#     plot.set "size square"

#     perp_points = candidates.map { |row| [row[4], row[5]] }.transpose
#     plot.data << Gnuplot::DataSet.new(perp_points) do |ds|
#       ds.with = "points pt 7 ps 0.5 lc rgb '#3366cc'"
#       ds.title = "Projected Points"
#     end
#   end
# end

# puts "✅ グラフ描画完了！"
