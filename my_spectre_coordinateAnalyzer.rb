
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
if ARGV.empty?
  puts "❗ ファイル名を指定してください: ruby spectre_coordinate_analyzer.rb input.csv"
  exit
end

filename = ARGV[0]

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

# x_perp_pca_raw_data = [[x, y], [x, y], ...] ← PCA残差ベクトル群
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
  csv << ['pt0-coef:a0', 'a1', 'b0', 'b1',
          'raw_PCA_x', 'raw_PCA_y',
          'perp_PCA_x', 'perp_PCA_y',
          'perp_LSQ_x', 'perp_LSQ_y']

  # 各行のデータを結合して出力
  data.each_with_index do |row, i|
    csv << row +
           x_perp_pca_raw_data[i] +
           x_perp_pca_data[i] +
           x_perp_lsq_data[i]
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


find_start_time = Time.now
candidates = []

max_points = 30000

Start_node = Vector[1,-230,-201,81]
Min_a0 = -1
Max_a0 = 24
Min_b0 = -226
Max_b0 = -200

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
puts "\n💡 FIFOキューと先読みルールを適用した、履歴に依存しない探索を開始します..."


# キューの要素: [現在座標(Vector)] のみ
# Start_node = Vector[0, 0, 0, 0]
queue = [Start_node] # シンプルなFIFOキュー
visited = Set[Start_node]
window_radius_2pow = window_radius**2

# --- メインの探索ループ ---
while !queue.empty? && candidates.size < max_points
  # キューの先頭からFIFOで取り出す
  current_node = queue.shift

  # --- 採用処理 ---
  current_node_perp = P_perp_basis.map { |basis| current_node.inner_product(Vector[*basis]) }
  next unless point_inside_polygon?(current_node_perp, boundary_polygon)
  candidates << current_node.to_a + current_node_perp

  if candidates.size % 5000 == 0
    puts "   ... #{candidates.size} 個の頂点を生成済み。キューのサイズ: #{queue.size}"
  end

  # --- 次の候補を、履歴に依存せず常に12方向から探す ---
  EDGE_1ST_VECTORS.each do |step_vec|
    neighbor_node = current_node + step_vec

    # 訪問済みチェックと範囲チェック
    next unless (Min_a0..Max_a0).include?(neighbor_node[0]) && (Min_b0..Max_b0).include?(neighbor_node[2])
    next if visited.include?(neighbor_node)

    # 候補点の有効性チェック（窓の内側か？）
    neighbor_node_perp = P_perp_basis.map { |basis| neighbor_node.inner_product(Vector[*basis]) }
    unless (neighbor_node_perp.map { |x| x**2 }.sum) < window_radius_2pow &&
      point_inside_polygon?(neighbor_node_perp, boundary_polygon)
      visited << neighbor_node
      next
    end

    # --- 「先読み」ロジック ---
    is_not_dead_end = false
    # この候補手（neighbor_node）から、さらに次に行ける手を探す
    # 次のステップは、現在の移動ベクトル(step_vec)に依存する
    grandchild_possible_steps = LEGAL_NEXT_STEPS[step_vec] || []
    grandchild_possible_steps.each do |grandchild_step_vec|
      grandchild_node = neighbor_node + grandchild_step_vec

      grandchild_perp = P_perp_basis.map { |basis| grandchild_node.inner_product(Vector[*basis]) }

      # 有効な次の手が一つでも見つかればOK
      if (grandchild_perp.map { |x| x**2 }.sum) < window_radius_2pow
        is_not_dead_end = true
        break
      end
    end
    # --- 「先読み」ここまで ---

    # 行き止まりでなければ、この候補点を正式に採用
    if is_not_dead_end
      visited << neighbor_node
      # キューの末尾に追加（FIFO）
      queue.push(neighbor_node)
    # else
      # 行き止まりなら、次の候補点を探す。neighbor_nodeと同じ座標に、別の方向から侵入した場合には　行き止まりにならないかもしれないので、visitedに追加しない。
    end
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
puts "\n💾 生成された4D整数座標を #{candidates.size}個、'#{output_filename}' に保存中..."

CSV.open(output_filename, 'w') do |csv|
  csv << ['a0', 'a1', 'b0', 'b1', 'perp_x', 'perp_y']
  candidates.each { |row| csv << row }
end
p ["spectre座標　探索時間", Time.now -  find_start_time]

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
