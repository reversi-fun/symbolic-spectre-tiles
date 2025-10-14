
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

def least_squares(x_data, y_data)
  x = Matrix[*x_data]
  y = Vector[*y_data]
  xt = x.transpose
  beta = (xt * x).inverse * xt * y
  beta.to_a
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

visited = Set.new
candidates = []
queue = []
queue.push([0, 0, 0, 0])

max_points = 20000
max_a0 = 5
max_b0 = 20
# dw = (4.0 / c0 / c1).abs.ceil

# while !queue.empty? && candidates.size < max_points
#   a0, a1, b0, b1 = queue.shift
#   [
#     [-1, 0, 0, 0], [-1, 1, 0, 0], [0, -1, 0, 0],
#     [0, 0, -1, 0], [0, 0, -1, 1], [0, 0, 0, -1],
#     [0, 0, 0, 1], [0, 0, 1, -1], [0, 0, 1, 0],
#     [0, 1, 0, 0], [1, -1, 0, 0], [1, 0, 0, 0]
#   ].each do |dA0, dA1, dB0, dB1|
#     vec = [a0 + dA0, a1 + dA1, b0 + dB0, b1 + dB1]
#     next unless (-max_a0..max_a0).include?(vec[0]) && (-max_b0..max_b0).include?(vec[2])
#     next if visited.include?(vec)
#     visited << vec
#     perp = P_perp_basis.map { |basis| vec.zip(basis).map { |a, b| a * b }.sum }
#     if Math.sqrt(perp.map { |x| x**2 }.sum) < window_radius
#       candidates << vec + perp
#       queue.push(vec)
#     end
#   end
# end

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

(-max_a0..max_a0).each do |a0|
  (-max_b0..max_b0).each do |b0|
    begin
      a1_est, b1_est = estimate_a1_b1(a0, b0, c0, c1, d0, d1)
    rescue
      next
    end

    ((a1_est - window_radius).floor).upto((a1_est + window_radius).ceil) do |a1|
      ((b1_est - window_radius).floor).upto((b1_est + window_radius).ceil) do |b1|
        vec = [a0, a1, b0, b1]
        next if visited.include?(vec)
        visited << vec

        perp = P_perp_basis.map { |basis| vec.zip(basis).map { |a, b| a * b }.sum } # perp = [x, y] ← 任意の候補点
        if point_inside_polygon?(perp, boundary_polygon)   # ✅ 渦巻きの内側 → 採用
          candidates << vec + perp
          break if candidates.size >= max_points
        end
      end
      break if candidates.size >= max_points
    end
    break if candidates.size >= max_points
  end
  break if candidates.size >= max_points
end

# --- ステップ6: CSV保存 ---
output_filename = "generated_spectre_integer_coords3.csv"
puts "\n💾 生成された4D整数座標を #{candidates.size}個、'#{output_filename}' に保存中..."

CSV.open(output_filename, 'w') do |csv|
  csv << ['a0', 'a1', 'b0', 'b1', 'perp_x', 'perp_y']
  candidates.each { |row| csv << row }
end

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
