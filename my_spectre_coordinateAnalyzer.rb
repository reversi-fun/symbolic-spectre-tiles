# my_spectre_coordinateAnalyzer3.rb

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

def pca_components(data, n_components = 2)
  cov = covariance_matrix(data)
  eig = cov.eigen

  # 固有値の絶対値で降順ソートして、対応する固有ベクトルを抽出
  sorted = eig.eigenvalues.zip(eig.eigenvectors)
             .sort_by { |val, _| -val.abs }
             .first(n_components)
             .map { |_, vec| vec.to_a }

  sorted
  # # 標準化（平均0、分散1）
  # cols = data.transpose
  # means = cols.map { |col| col.sum / col.size }
  # stds  = cols.map { |col| Math.sqrt(col.map { |x| (x - col.sum / col.size)**2 }.sum / col.size) }

  # standardized = data.map do |row|
  #   row.zip(means, stds).map { |x, m, s| s.zero? ? 0.0 : (x - m) / s }
  # end

  # m = Matrix[*standardized]
  # u, s, vt = m.singular_value_decomposition

  # # vt は右特異ベクトル（主成分）
  # components = vt.to_a.first(n_components)
  # components
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

def rmse(vectors)
  Math.sqrt(vectors.map { |v| v.map { |x| x**2 }.sum }.sum / vectors.size)
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

# --- ステップ2: PCA ---
# --- ステップ2: PCA方式から係数と基底を導出 ---
c0_pca = c1_pca = d0_pca = d1_pca = nil
raw_pca_basis = nil
p_perp_pca = nil
window_radius_pca = rmse_pca = nil
rmse_pca_raw = nil
window_radius_pca_raw = nil
x_perp_pca_raw_data = nil
x_perp_pca_data = nil

begin
  raw_pca_basis = pca_components(data, 4)
  puts "🔍 PCA固有ベクトル（Ruby）:"
  raw_pca_basis.each_with_index { |vec, i| puts "PC#{i+1}: #{vec.map { |v| v.round(6) }.join(', ')}" }

  raw_pca_basis = raw_pca_basis[2..3]
  x_perp_pca_raw_data = data.map { |row| raw_pca_basis.map { |basis| row.zip(basis).map { |a, b| a * b }.sum } }
  rmse_pca_raw = rmse(x_perp_pca_raw_data)
  window_radius_pca_raw = x_perp_pca_raw_data.map { |v| Math.sqrt(v.map { |x| x**2 }.sum) }.max * 1.05

  k = raw_pca_basis[0][2] / raw_pca_basis[1][2]
  n3 = raw_pca_basis[0].zip(raw_pca_basis[1]).map { |a, b| a - k * b }
  n3 = n3.map { |x| x / n3[3] }
  c0_pca, c1_pca = n3[0], n3[1]

  m = raw_pca_basis[1][0] / raw_pca_basis[0][0]
  n4 = raw_pca_basis[1].zip(raw_pca_basis[0]).map { |b, a| b - m * a }
  n4 = n4.map { |x| x / n4[1] }
  d0_pca, d1_pca = n4[2], n4[3]

  n1_pca = [c0_pca, c1_pca, 0, 1]
  n2_pca = [0, 1, d0_pca, d1_pca]
  v1_pca = n1_pca
  v2_pca = orthogonalize(v1_pca, n2_pca)
  p_perp_pca = [normalize(v1_pca), normalize(v2_pca)]

  x_perp_pca_data = data.map { |row| p_perp_pca.map { |basis| row.zip(basis).map { |a, b| a * b }.sum } }
  rmse_pca = rmse(x_perp_pca_data)
  window_radius_pca = x_perp_pca_data.map { |v| Math.sqrt(v.map { |x| x**2 }.sum) }.max * 1.05
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

# x_perp_pca_raw_data = [[x, y], [x, y], ...] ← PCA残差ベクトル群
# KD木を構築
puts "🌳 KNN検索用のKD木を構築中..."
kd_tree = KDTree.new(x_perp_pca_raw_data)

# KNNによる判定関数
# k=5 程度の近傍点との平均距離が、閾値以下なら「有効」とみなす
# 閾値は window_radius の何割か、あるいはデータ密度から自動推定する
# ここでは window_radius (最大半径) ではなく、平均的な点間距離を基準にするのが良いが、
# 簡易的に window_radius * 係数 で試す。
KNN_K = 5
# 閾値の調整: データの平均的な「隣接距離」を見積もる必要がある。
# 簡易的に、window_radius (データの広がり) の 1/10 程度を許容範囲としてみる。
# 厳密には、正解データの平均最近傍距離を計算して決めるのがベスト。
KNN_THRESHOLD = window_radius_pca_raw * 0.2

def is_valid_point_knn?(point, kd_tree, threshold)
  neighbors = kd_tree.nearest_k(point, KNN_K)
  return false if neighbors.size < KNN_K

  # 平均距離
  mean_dist = Math.sqrt(neighbors.map { |d, _| d }.sum / KNN_K)
  mean_dist < threshold
end

# 閾値の自動調整（正解データ自身の平均距離を測る）
sample_points = x_perp_pca_raw_data.sample(100)
mean_neighbor_dists = sample_points.map do |p|
  neighbors = kd_tree.nearest_k(p, KNN_K + 1) # 自分自身が含まれるので +1
  neighbors.shift # 自分自身(距離0)を除く
  Math.sqrt(neighbors.map { |d, _| d }.sum / KNN_K)
end
avg_density = mean_neighbor_dists.sum / mean_neighbor_dists.size
KNN_THRESHOLD_ADAPTIVE = avg_density * 2.5 # 平均密度の2.5倍まで許容（隙間はこれより広いはず）

puts "📏 KNN閾値設定: 平均密度=#{avg_density.round(4)}, 採用閾値=#{KNN_THRESHOLD_ADAPTIVE.round(4)}"

# --- 渦巻き境界の抽出（凸包） ---
def compute_convex_hull(points)
  # points: [[x, y], [x, y], ...]
  # hull = ConvexHull.compute(points)
  # hull.map { |pt| [pt.x, pt.y] }

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

boundary_polygon = compute_convex_hull(x_perp_pca_raw_data)
p ["凸包点数", boundary_polygon.size]
p ["凸包", boundary_polygon]
# --- ステップ3: LSQ方式から係数と基底を導出 ---
c0_lsq = c1_lsq = d0_lsq = d1_lsq = nil
p_perp_lsq = nil
window_radius_lsq = rmse_lsq = nil
x_perp_lsq_data = nil  # ← 警告回避のため別名に変更

begin
  y1 = data.map { |row| row[3] }
  X1 = data.map { |row| [row[0], row[1]] }
  coef1 = least_squares(X1, y1)
  c0_lsq, c1_lsq = -coef1[0], -coef1[1]

  y2 = data.map { |row| row[1] }
  X2 = data.map { |row| [row[2], row[3]] }
  coef2 = least_squares(X2, y2)
  d0_lsq, d1_lsq = -coef2[0], -coef2[1]

  n1_lsq = [c0_lsq, c1_lsq, 0, 1]
  n2_lsq = [0, 1, d0_lsq, d1_lsq]
  v1_lsq = n1_lsq
  v2_lsq = orthogonalize(v1_lsq, n2_lsq)
  p_perp_lsq = [normalize(v1_lsq), normalize(v2_lsq)]

  x_perp_lsq_data = data.map { |row| p_perp_lsq.map { |basis| row.zip(basis).map { |a, b| a * b }.sum } }
  x_mean_lsq = x_perp_lsq_data.transpose.map { |col| col.sum / col.size }
  x_perp_lsq_data = x_perp_lsq_data.map { |v| v.zip(x_mean_lsq).map { |a, b| a - b } }
  rmse_lsq = rmse(x_perp_lsq_data)
  window_radius_lsq = x_perp_lsq_data.map { |v| Math.sqrt(v.map { |x| x**2 }.sum) }.max * 1.05
end

# --- ステップ4: 結合 ---
output_filename = "combined_output.csv"
puts "💾 結合データを '#{output_filename}' に保存中..."

CSV.open(output_filename, 'w') do |csv|
  # ヘッダー行
  csv << [
          "\uFEFF" + 'shape#','label','vertex_index',	'angle','scale_y','vertex_expression','x','y',
          'pt0-coef:a0', 'a1', 'b0', 'b1',
          # 'raw_PCA_x', 'raw_PCA_y',
          'perp_PCA_x', 'perp_PCA_y',
          'perp_LSQ_x', 'perp_LSQ_y']

  # 各行のデータを結合して出力
  raw_data.each_with_index do |row, i|
    csv << (row.values_at("\uFEFF" + 'shape#', 'label', 'vertex_index', 'angle', 'scale_y', 'vertex_expression', 'x', 'y', 'pt0-coef:a0', 'a1', 'b0', 'b1') +
           x_perp_pca_data[i] +
           x_perp_lsq_data[i])
  end
end

puts "✅ 結合データを '#{output_filename}' に保存しました！"

# --- ステップ4: ベスト方式選択 ---
puts "\n📊 処理方式の比較:"
puts "   rawPCA方式 → \tRMSE = #{rmse_pca_raw.round(6)}, \tWindow Radius = #{window_radius_pca_raw.round(4)}"
puts "   PCA方式    → \tRMSE = #{rmse_pca.round(6)}, \tWindow Radius = #{window_radius_pca.round(4)}"
puts "   LSQ方式    → \tRMSE = #{rmse_lsq.round(6)}, \tWindow Radius = #{window_radius_lsq.round(4)}"

if rmse_pca <= rmse_lsq
  puts "\n🏆 PCA方式が選ばれました！"
  c0, c1, d0, d1 = c0_pca, c1_pca, d0_pca, d1_pca
  window_radius = window_radius_pca
else
  puts "\n🏆 LSQ方式が選ばれました！"
  c0, c1, d0, d1 = c0_lsq, c1_lsq, d0_lsq, d1_lsq
  window_radius = window_radius_lsq
end
P_perp_basis = raw_pca_basis

puts "\n✅ 使用係数: c0=#{c0.round(4)}, c1=#{c1.round(4)}, d0=#{d0.round(4)}, d1=#{d1.round(4)}"

# --- ステップ5: 近傍探索 ---
require 'set'
# --- 近傍探索に使う関数 ---
def estimate_a1_b1(a0, b0, c0, c1, d0, d1)
  det = c1 * d1 - 1
  raise "⚠️ 特異行列（det ≈ 0）" if det.abs < 1e-8

  rhs1 = -c0 * a0
  rhs2 = -d0 * b0

  a1 = (rhs1 * d1 - rhs2) / det
  b1 = (c1 * rhs2 - rhs1) / det
  [a1, b1]
end

# --- ShapeInfo Class ---
class ShapeInfo
  attr_reader :vertices, :centroid
  attr_accessor :invalid_connect_from

  def initialize(vertices)
    @vertices = vertices # Array of Vectors
    @centroid = calculate_centroid(vertices)
    @invalid_connect_from = [] # Array of centroids (Vectors) from which this shape was reached via invalid branching
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
end


relative_range_a0 = [-6,24]
relative_range_b0 = [-50,50]

# Min/Max will be calculated after loading shapes



find_start_time = Time.now
candidates = []

max_points = 3000



# visited = Set.new
# queue = []
# queue.push([0, 0, 0, 0])
# while !queue.empty? && candidates.size < max_points
#   a0, a1, b0, b1 = queue.shift
#   [
#     [-1, 0, 0, 0], [-1, 1, 0, 0], [0, -1, 0, 0],
#     [0, 0, -1, 0], [0, 0, -1, 1], [0, 0, 0, -1],
#     [0, 0, 0, 1], [0, 0, 1, -1], [0, 0, 1, 0],
#     [0, 1, 0, 0], [1, -1, 0, 0], [1, 0, 0, 0]
#   ].each do |dA0, dA1, dB0, dB1|
#     vec = [a0 + dA0, a1 + dA1, b0 + dB0, b1 + dB1]
#     next unless (Min_a0..Max_a0).include?(vec[0]) && (Min_b0..Max_b0).include?(vec[2])
#     next if visited.include?(vec)
#     visited << vec
#     perp = P_perp_basis.map { |basis| vec.zip(basis).map { |a, b| a * b }.sum }
#     a1_est, b1_est = estimate_a1_b1(a0, b0, c0, c1, d0, d1)
#     if point_inside_polygon?(perp, boundary_polygon) &&   # ✅ 渦巻きの内側 → 採用
#       (a1_est -a1).abs < window_radius && (b1_est - b1).abs < window_radius
#       candidates << vec + perp
#       queue.push(vec)
#     end
#   end
# end
# 💾 生成された4D整数座標を 13632個、'generated_spectre_integer_coords3.csv' に保存中... ["spectre座標　探索時間", 0.4056887]　

# --- 幾何学的特徴の定義 ---
# edge1st_coef_set: 許容される隣接ベクトル (12種類)
EDGE_1ST_VECTORS = Set[
  [-1, 0, 0, 0], [-1, 1, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0],
  [0, 0, -1, 1], [0, 0, 0, -1], [0, 0, 0, 1], [0, 0, 1, -1],
  [0, 0, 1, 0], [0, 1, 0, 0], [1, -1, 0, 0], [1, 0, 0, 0]
].map { |v| Vector[*v] } # 計算しやすいようにVectorオブジェクトに変換

# edge2st_coef_set: 許容される2ステップの経路 (60種類)
# これを「前のステップ」から「次のステップ」への対応表に変換する
LEGAL_NEXT_STEPS = Hash.new { |h, k| h[k] = [] }
[
[[-1, 0, 0, 0], [-1, -1, 0, 0]],
[[-1, 0, 0, 0], [-1, 0, -1, 0]],
[[-1, 0, 0, 0], [-1, 0, 1, 0]],
[[-1, 0, 0, 0], [-2, 0, 0, 0]],
[[-1, 0, 0, 0], [-2, 1, 0, 0]],
[[-1, 1, 0, 0], [-1, 1, 0, -1]],
[[-1, 1, 0, 0], [-1, 1, 0, 1]],
[[-1, 1, 0, 0], [-1, 2, 0, 0]],
[[-1, 1, 0, 0], [-2, 1, 0, 0]],
[[-1, 1, 0, 0], [-2, 2, 0, 0]],
[[0, -1, 0, 0], [-1, -1, 0, 0]],
[[0, -1, 0, 0], [0, -1, -1, 1]],
[[0, -1, 0, 0], [0, -1, 1, -1]],
[[0, -1, 0, 0], [0, -2, 0, 0]],
[[0, -1, 0, 0], [1, -2, 0, 0]],
[[0, 0, -1, 0], [-1, 0, -1, 0]],
[[0, 0, -1, 0], [0, 0, -1, -1]],
[[0, 0, -1, 0], [0, 0, -2, 0]],
[[0, 0, -1, 0], [0, 0, -2, 1]],
[[0, 0, -1, 0], [1, 0, -1, 0]],
[[0, 0, -1, 1], [0, -1, -1, 1]],
[[0, 0, -1, 1], [0, 0, -1, 2]],
[[0, 0, -1, 1], [0, 0, -2, 1]],
[[0, 0, -1, 1], [0, 0, -2, 2]],
[[0, 0, -1, 1], [0, 1, -1, 1]],
[[0, 0, 0, -1], [-1, 1, 0, -1]],
[[0, 0, 0, -1], [0, 0, -1, -1]],
[[0, 0, 0, -1], [0, 0, 0, -2]],
[[0, 0, 0, -1], [0, 0, 1, -2]],
[[0, 0, 0, -1], [1, -1, 0, -1]],
[[0, 0, 0, 1], [-1, 1, 0, 1]],
[[0, 0, 0, 1], [0, 0, -1, 2]],
[[0, 0, 0, 1], [0, 0, 0, 2]],
[[0, 0, 0, 1], [0, 0, 1, 1]],
[[0, 0, 0, 1], [1, -1, 0, 1]],
[[0, 0, 1, -1], [0, -1, 1, -1]],
[[0, 0, 1, -1], [0, 0, 1, -2]],
[[0, 0, 1, -1], [0, 0, 2, -1]],
[[0, 0, 1, -1], [0, 0, 2, -2]],
[[0, 0, 1, -1], [0, 1, 1, -1]],
[[0, 0, 1, 0], [-1, 0, 1, 0]],
[[0, 0, 1, 0], [0, 0, 1, 1]],
[[0, 0, 1, 0], [0, 0, 2, -1]],
[[0, 0, 1, 0], [0, 0, 2, 0]],
[[0, 0, 1, 0], [1, 0, 1, 0]],
[[0, 1, 0, 0], [-1, 2, 0, 0]],
[[0, 1, 0, 0], [0, 1, -1, 1]],
[[0, 1, 0, 0], [0, 1, 1, -1]],
[[0, 1, 0, 0], [0, 2, 0, 0]],
[[0, 1, 0, 0], [1, 1, 0, 0]],
[[1, -1, 0, 0], [1, -1, 0, -1]],
[[1, -1, 0, 0], [1, -1, 0, 1]],
[[1, -1, 0, 0], [1, -2, 0, 0]],
[[1, -1, 0, 0], [2, -1, 0, 0]],
[[1, -1, 0, 0], [2, -2, 0, 0]],
[[1, 0, 0, 0], [1, 0, -1, 0]],
[[1, 0, 0, 0], [1, 0, 1, 0]],
[[1, 0, 0, 0], [1, 1, 0, 0]],
[[1, 0, 0, 0], [2, -1, 0, 0]],
[[1, 0, 0, 0], [2, 0, 0, 0]]
].each do |path|
  # path = [vec_to_1st, vec_to_2nd]
  # vec_to_2nd = vec_to_1st + next_step なので、
  # next_step = vec_to_2nd - vec_to_1st
  vec_to_1st = Vector[*path[0]]
  vec_to_2nd = Vector[*path[1]]
  next_step = vec_to_2nd - vec_to_1st

  # 「-vec_to_1st」という方向から来た場合、「next_step」に進める、というルール
  LEGAL_NEXT_STEPS[-vec_to_1st] << next_step
end
puts "\nジオメトリルールを構築完了。 LEGAL_NEXT_STEPSのキー数: #{LEGAL_NEXT_STEPS.size}"

# --- 14頂点パターンの抽出 ---
puts "\n🧩 14頂点パターンの抽出を開始..."
# shape# ごとに vertex_index -1 ～ -14 の行をグループ化
spectre_patterns = {} # { shape_id => [relative_vectors] }

# raw_data は CSV::Table
# shape# と vertex_index 列が必要
# データの各行をハッシュ化して扱いやすくする
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

  # 座標 (a0, a1, b0, b1)
  coord = [row['pt0-coef:a0'].to_f, row['a1'].to_f, row['b0'].to_f, row['b1'].to_f]
  rows_by_shape[shape_id] << { idx: v_idx, coord: coord }
end

VALID_SPECTRE_PATTERNS = []

rows_by_shape.each do |shape_id, rows|
  # -1 から -14 まで揃っているか確認
  indices = rows.map { |r| r[:idx] }.sort.reverse
  if indices != (-14..-1).to_a.reverse
    # 欠落がある場合はスキップ（あるいは警告）
    # puts "⚠️ Shape##{shape_id}: 頂点が揃っていません (#{indices.size}/14)"
    next
  end

  orignal_points = (-14..-1).to_a.reverse.map{|idx| rows.find { |r| r[:idx] == idx }[:coord]}
  # orignal_points.size.times do |i|
    base_vector = Vector[*orignal_points[0]] # Vector[*orignal_points[i]] # 各頂点を基準とした相対座標を計算
    pattern = orignal_points.map{|p| Vector[*p] - base_vector}
    VALID_SPECTRE_PATTERNS << pattern
    # orignal_points.rotate!
  # end
end

# 重複排除（相対座標のセットとして同じなら1つにまとめる）
# Vectorの配列を比較
VALID_SPECTRE_PATTERNS.uniq!

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

# 14ステップ整合性チェック関数 (Shape-based)
# current_shape_info: 現在のShapeInfoオブジェクト
# 戻り値: [new_shape_infos] (新しく見つかったShapeInfoのリスト)
def find_valid_tile_configuration(current_shape_info, visited, kd_tree, threshold)
  new_shapes = []

  current_shape_info.edges.each do |v1, v2|
    edge_vec = v2 - v1

    # このエッジに対して見つかった新規候補
    candidates_for_edge = []

    # VALID_SPECTRE_PATTERNS の中から、このエッジにマッチするものを探す
    # パターン内の各エッジについて、edge_vec または -edge_vec と一致するかチェック

    VALID_SPECTRE_PATTERNS.each do |pattern|
      # patternは相対座標のリスト (Vector)。隣接点間のベクトルを計算して照合
      # patternの頂点は14個。エッジは (0->1), (1->2), ..., (13->0)
      14.times do |i|
        # マッチ判定
        # 1. 順方向マッチ: v_edge == p_vec
        #    現在のエッジ v1 -> v2 に対して、パターンのエッジ p_start -> p_end が重なる
        #    配置: v1 が p_start に、v2 が p_end になるように平行移動
        #    しかし、辺を共有して隣接する場合、通常は「逆向き」に重なることが多い（多角形の向きによる）
        #    Spectreタイルの並べ方は、虚像反転を含めないので、逆順でのマッチのみ確認する。
        p_start = pattern[i]
        p_end = pattern[(i + 1) % 14]
        p_vec = p_start - p_end
        next unless p_vec == edge_vec

        # 配置のためのオフセット計算
        # 逆方向マッチ(推奨): v1 -> v2 と p_end -> p_start が重なる
        # つまり v1 = target_p_end, v2 = target_p_start
        # target_p_start = offset + p_start
        # v2 = offset + p_start => offset = v2 - p_start

        offset = v2 - p_start

        # 候補形状の頂点を計算
        candidate_points = pattern.map { |v| v + offset }

        # 重心を計算して visited チェック (KNNの前にコストの低いチェック)
        candidate_shape = ShapeInfo.new(candidate_points)
        next if visited.include?(candidate_shape.centroid)

        # 範囲チェック & KNNチェック
        is_valid = true
        candidate_points.each do |pt|
          unless (Min_a0..Max_a0).include?(pt[0]) && (Min_b0..Max_b0).include?(pt[2])
            is_valid = false; break
          end

          pt_perp = P_perp_basis.map { |basis| pt.inner_product(Vector[*basis]) }
          unless is_valid_point_knn?(pt_perp, kd_tree, threshold)
            is_valid = false; break
          end
        end

        if is_valid
          candidates_for_edge << candidate_shape
        end
      end
    end

    # 分岐記録: 1つのエッジに対して2つ以上の新規候補が見つかったら記録
    if candidates_for_edge.uniq { |s| s.centroid }.size >= 2
      puts "⚠️ 分岐検出: エッジ #{v1} -> #{v2} に対して #{candidates_for_edge.size} 個の新規タイルが見つかりました。"
      candidates_for_edge.each_with_index do |s, idx|
        puts "  Candidate #{idx}: Centroid #{s.centroid}"
        s.invalid_connect_from << current_shape_info.centroid
      end
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
  initial_shapes << ShapeInfo.new(vertices)
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

puts "📏 探索範囲: a0=[#{Min_a0}, #{Max_a0}], b0=[#{Min_b0}, #{Max_b0}]"

# 初期化: visited と queue
visited = Set.new
queue = []
candidates = [] # ShapeInfo objects

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

  # Shape#0 は探索済み(展開元としない)とするため、queueには入れない
  # Shape#1 ～ Shape#9 を queue に入れる
  if i > 0
    queue.push(shape)
  end
end

puts "\n🚀 形状ベースの探索を開始します..."
puts "   初期形状数: #{initial_shapes.size} (Shape#0-9)"
puts "   Queueサイズ: #{queue.size} (Shape#1-9)"

while !queue.empty? && candidates.size < max_points
  current_shape = queue.shift

  begin
    new_shapes = find_valid_tile_configuration(current_shape, visited, kd_tree, KNN_THRESHOLD_ADAPTIVE)

    new_shapes.each do |shape|
      next if visited.include?(shape.centroid) # 二重チェック

      visited << shape.centroid
      queue.push(shape)
      candidates << shape # Store ShapeInfo object
    end
  rescue RuntimeError => e
    puts e.message
    break
  end

  if candidates.size % 100 < 10
     puts "   ... #{candidates.size} 個の形状を生成済み。キュー: #{queue.size}, Visited Tiles: #{visited.size}"
  end
end

########################

# (Min_a0..Max_a0).each do |a0|
#   (Min_b0..Max_b0).each do |b0|
#     begin
#       a1_est, b1_est = estimate_a1_b1(a0, b0, c0, c1, d0, d1)
#     rescue
#       next
#     end

#     ((a1_est - window_radius).floor).upto((a1_est + window_radius).ceil) do |a1|
#       ((b1_est - window_radius).floor).upto((b1_est + window_radius).ceil) do |b1|
#         vec = [a0, a1, b0, b1]
#         next if visited.include?(vec)
#         visited << vec

#         perp = P_perp_basis.map { |basis| vec.zip(basis).map { |a, b| a * b }.sum } # perp = [x, y] ← 任意の候補点
#         if point_inside_polygon?(perp, boundary_polygon)   # ✅ 渦巻きの内側 → 採用
#           candidates << vec + perp
#           break if candidates.size >= max_points
#         end
#       end
#       break if candidates.size >= max_points
#     end
#     break if candidates.size >= max_points
#   end
#   break if candidates.size >= max_points
# end
# 💾 生成された4D整数座標を 13776個、'generated_spectre_integer_coords3.csv' に保存中... ["spectre座標　探索時間", 0.2826513]

# --- ステップ6: CSV保存 ---
output_filename = "generated_spectre_integer_coords3.csv"
puts "\n💾 生成された形状を #{candidates.size}個、'#{output_filename}' に保存中..."

CSV.open(output_filename, 'w') do |csv|
  csv << ['shape_centroid', 'invalid_connect_from', 'a0', 'a1', 'b0', 'b1', 'perp_x', 'perp_y']

  candidates.each do |shape|
    # 重心の文字列化
    centroid_str = "[#{shape.centroid.to_a.map { |v| v.round(4) }.join(',')}]"

    # invalid_connect_from の文字列化
    invalid_str = if shape.invalid_connect_from.empty?
      ""
    else
      shape.invalid_connect_from.map { |c| "[#{c.to_a.map { |v| v.round(4) }.join(',')}]" }.join("; ")
    end

    # 各頂点を出力
    shape.vertices.each do |v|
      perp = P_perp_basis.map { |basis| v.inner_product(Vector[*basis]) }
      csv << [centroid_str, invalid_str] + v.to_a + perp
    end
  end
end
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
