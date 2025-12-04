#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# spectre_coordinateAnalyzer_debug_full_v8.rb

require 'csv'
require 'matrix'
require 'set'

# ====================================================================
# I. ヘルパー関数群 (数学・共通処理)
# ====================================================================

# --- 分類キーの作成 ------------------------------------------------
# 機能概要: データの label, angle, vertex_index から一意なキーを生成する。
# Input: label (String), angle (String), vertex_index (String)
# Returns: key (String)
def create_key(label, angle, vertex_index)
  match = label.match(/\.([^.\-]+?\/[^.\-]+?)$/)
  last_words = match ? match[0] : label
  "#{last_words}-#{angle}-#{vertex_index}"
end

# 機能概要: 詳細キーから vertex_index の部分を '*' に置換したキーを生成する。
# Input: key (String) - 例: ".Lambda/Psi-300--1"
# Returns: combined_key (String) - 例: ".Lambda/Psi-300-*"
def create_combined_key(key)
  # キーは通常 "{label}-{angle}-{vertex_index}" の形式。
  # 最後のハイフンとそれ以降を置換する。
  key.sub(/-\d+$/, '-*')
end

# --- 行列/ベクトル演算ヘルパー ----------------------------------------

# 機能概要: データの平均ベクトルを算出する。
# Input: data (Array<Array<Numeric>>) - 行ごとにデータ点を持つ配列。
# Returns: mean_vector (Array<Numeric>)
def mean_vector(data)
  cols = data.transpose
  cols.map { |col| col.sum / col.size.to_f }
end

# 機能概要: データから平均を引いて中心化する。
# Input: data (Array<Array<Numeric>>)
# Returns: centered_data (Array<Array<Numeric>>)
def center_data(data)
  mean = mean_vector(data)
  data.map { |row| row.zip(mean).map { |x, m| x - m } }
end

# 機能概要: 2つのベクトル（Vectorオブジェクト）の外積行列を計算する。
# Input: v1 (Vector), v2 (Vector)
# Returns: outer_product_matrix (Matrix)
def outer_product(v1, v2)
  Matrix.rows(v1.to_a.map { |x| v2.to_a.map { |y| x * y } })
end

# 機能概要: 共分散行列を計算する。
# Input: data (Array<Array<Numeric>>)
# Returns: covariance_matrix (Matrix)
def covariance_matrix(data)
  centered = center_data(data)
  m = Matrix[*centered]
  (m.transpose * m) / data.size.to_f
end

# 機能概要: データのRMSE (Root Mean Square Error) を計算する。
# Input: vectors (Array<Array<Numeric>>) - 誤差ベクトルまたは残差ベクトルの配列
# Returns: rmse_value (Float)
def rmse(vectors)
  return 0.0 if vectors.empty?
  Math.sqrt(vectors.map { |v| v.map { |x| x**2 }.sum }.sum / vectors.size.to_f)
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

# --- 凸包 (Convex Hull) --------------------------------------------

# 機能概要: 2D点群の凸包を Andrew's Monotone Chain で計算する (点数 >= 3)。
# Input: points (Array<Array<Float>>)
# Returns: hull_points (Array<Array<Float>>) - 凸包を構成する点の配列
def convex_hull_monotone_chain(points)
  # 最小のx座標、次に最小のy座標でソート
  points = points.sort_by { |x, y| [x, y] }

  # size <= 3 の場合の処理は compute_convex_hull に任せる

  # 外積の符号を返すラムダ (0以下なら右回りまたは共線)
  cross = ->(o, a, b) {
    (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
  }

  # 下側の包
  lower = []
  points.each do |p|
    # 反時計回りになるように点をポップ
    while lower.size >= 2 && cross.call(lower[-2], lower[-1], p) <= 0
      lower.pop
    end
    lower << p
  end

  # 上側の包
  upper = []
  points.reverse.each do |p|
    while upper.size >= 2 && cross.call(upper[-2], upper[-1], p) <= 0
      upper.pop
    end
    upper << p
  end

  # 上下を結合し、重複する最初と最後の点を除去
  (lower[0...-1] + upper[0...-1])
end


# 機能概要: 2D点群の凸包を計算する。要素数 0, 1, 2 の場合も対応。
# Input: points (Array<Array<Float>>)
# Returns: boundary_polygon (Array<Array<Float>>) - 0個以上の点の配列
def compute_convex_hull(points)
  # インターフェース整合性のため、0, 1, 2点のケースはそのまま返す
  return points if points.size <= 2

  hull = convex_hull_monotone_chain(points)
  hull
end

# 機能概要: 点が2D多角形（凸包）の内部にあるかどうかを判定する。
#           要素数 0, 1, 2, >=3 の全てに対応。単一の exit point を持つ。
# Input: pt (Array<Float>), polygon (Array<Array<Float>>), tol (Float)
# Returns: is_inside (Boolean)
def point_inside_polygon?(pt, polygon, tol = 1e-6)
  x, y = pt
  result = false

  if polygon.nil? || polygon.empty?
    result = false
  elsif polygon.size == 1
    # --- 点同士比較 ---
    point = polygon[0]
    if point && point[0] && point[1]
      result = (x - point[0]).abs < tol && (y - point[1]).abs < tol
    else
      result = false
    end
  elsif polygon.size == 2
    # --- 線分上判定（距離と射影位置を考慮）---
    # ... (線分上判定ロジックは前回修正済みのものが正しい) ...
    if polygon[0] && polygon[1] && polygon[0][0] && polygon[0][1] && polygon[1][0] && polygon[1][1]
      px, py = pt
      x1, y1 = polygon[0]
      x2, y2 = polygon[1]

      vx, vy = x2 - x1, y2 - y1
      wx, wy = px - x1, py - y1
      seg_len2 = vx * vx + vy * vy

      if seg_len2 < tol * tol
        result = (x - x1).abs < tol && (y - y1).abs < tol
      else
        t = (vx * wx + vy * wy) / seg_len2

        if t > -tol && t < 1.0 + tol
          projx = x1 + t * vx
          projy = y1 + t * vy
          dist2 = (px - projx)**2 + (py - projy)**2
          result = dist2 <= tol * tol
        else
          result = false
        end
      end
    else
      result = false
    end
  else # polygon.size >= 3

    # 🚨 修正ロジックの追加: 最初に境界（辺上）判定を行う
    j = polygon.size - 1
    is_on_boundary = false

    polygon.each_with_index do |point_i, i|
      point_j = polygon[j]

      # 座標値が有効かどうかのチェック
      if point_i && point_j && point_i[0] && point_i[1] && point_j[0] && point_j[1]
        x1, y1 = point_i
        x2, y2 = point_j

        # 点と線分の距離チェック（線分上判定ロジックを再利用）
        vx, vy = x2 - x1, y2 - y1
        wx, wy = x - x1, y - y1
        seg_len2 = vx * vx + vy * vy

        if seg_len2 < tol * tol # 辺が点の場合
          if (x - x1).abs < tol && (y - y1).abs < tol
            is_on_boundary = true
            break
          end
        else
          t = (vx * wx + vy * wy) / seg_len2
          if t > -tol && t < 1.0 + tol # 射影点が線分内
            projx = x1 + t * vx
            projy = y1 + t * vy
            dist2 = (x - projx)**2 + (y - projy)**2
            if dist2 <= tol * tol
              is_on_boundary = true
              break
            end
          end
        end
      end # 座標値チェックの終端
      j = i
    end # 境界判定ループ終了

    if is_on_boundary
      result = true
    else
      # --- 多角形内判定（Ray Casting）---
      inside = false
      j = polygon.size - 1

      polygon.each_with_index do |point_i, i|
        point_j = polygon[j]

        if point_i && point_j && point_i[0] && point_i[1] && point_j[0] && point_j[1]
          xi, yi = point_i
          xj, yj = point_j

          if ((yi > y) != (yj > y))
            x_int = (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi
            inside = !inside if x <= x_int + tol
          end
        end
        j = i
      end
      result = inside
    end
  end

  # 変更前と同様のデバッグ情報を出力
  # p ["point_inside_polygon failed", pt, result, polygon] unless result

  result # 単一の exit point
end

# ====================================================================
# II. 大域的PCA処理 (共通基底の計算)
# ====================================================================

# 機能概要: 全データ群から大域的な共分散行列を計算し、共通基底（PC1, PC2）と平均を算出する。
# Input: data_groups (Hash)
# Returns: common_basis_and_mean (Array) - [common_basis (Array<Array<Float>>), global_mean (Vector)]
def compute_common_basis_from_groups(data_groups)
  total_n = 0
  total_mean = Vector.zero(4)
  total_cov_sum = Matrix.zero(4)

  data_groups.each do |_, group|
    coords = group.map { |g| Vector[*g[:coords]] }
    n = coords.size
    next if n < 2
    mean_i = coords.reduce(Vector.zero(4), :+) / n.to_f

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

  sorted = vals.zip(vecs).sort_by { |v, _| v.abs }

  puts "📊 共通基底 固有値: #{sorted.map { |v,_| format('%.3f', v) }.join(', ')}"
  common_basis = sorted.first(2).map { |_, v| v }

  [common_basis, mean_global]
end

# 機能概要: 全データ群を共通基底に射影した際の最大半径（二乗）を算出する。
# Input: data_groups (Hash), common_basis (Array<Array<Float>>)
# Returns: max_radius_sq (Float)
def compute_max_window_radius_sq(data_groups, common_basis)
  max_r_sq = 0.0
  data_groups.each_value do |group|
    group.each do |g|
      coords = g[:coords]
      proj = common_basis.map { |b| coords.zip(b).map { |a, bb| a * bb }.sum }
      r_sq = proj.map { |x| x**2 }.sum
      max_r_sq = r_sq if r_sq > max_r_sq
    end
  end
  max_r_sq
end

# def compute_max_residual_radius_sq(data_groups, grouped_pca_results)
#   max_r_sq = 0.0

#   data_groups.each do |key, group|
#     # 1. キー固有のPCA結果を取得
#     res = grouped_pca_results[key]

#     # PCA結果が存在しない、または基底が空（0点/1点かつ補完失敗）の場合はスキップ
#     next unless res && !res[:basis].empty?

#     # res[:basis] は、キー固有の PC3/PC4 基底 (残差空間)
#     res_basis = res[:basis]

#     # 2. そのグループ内の全データ点をチェック
#     group.each do |g|
#       coords = g[:coords]

#       # PC3/PC4空間への射影 (残差) を計算
#       # 射影は、座標ベクトルと基底ベクトルの内積の計算
#       proj = res_basis.map do |b|
#         coords.zip(b).map { |a, bb| a * bb }.sum
#       end

#       # 残差の二乗和 (r_sq) を計算
#       r_sq = proj.map { |x| x**2 }.sum

#       # 最大値を更新
#       max_r_sq = r_sq if r_sq > max_r_sq
#     end
#   end

#   max_r_sq
# end


# ====================================================================
# III. メイン処理 (データ読み込み、PCA、検証、探索)
# ====================================================================

# --- メイン実行ブロック ---

# コマンドライン引数チェック
if ARGV.empty?
  puts "❗ ファイル名を指定してください: ruby spectre_coordinateAnalyzer_debug_full_v8.rb input.csv"
end

filename = ARGV[0] || "input.csv"
columns = ['pt0-coef:a0', 'a1', 'b0', 'b1']
raw_header_names = nil

# --- ステップ1: データ読み込みとグループ化 ---
raw_data_all = CSV.read(filename, headers: true)
if raw_data_all.headers.first.start_with?("\uFEFF")
  raw_header_names = raw_data_all.headers.map { |h| h.start_with?("\uFEFF") ? h.delete("\uFEFF") : h }
else
  raw_header_names = raw_data_all.headers
end

data_groups = Hash.new{|h,k| h[k] = [] }
raw_data_all.each do |row|
  label = row['label'] || row["\uFEFFlabel"]
  angle = row['angle']
  vertex_index = row['vertex_index']
  next unless label && angle && vertex_index

  key = create_key(label, angle, vertex_index)
  coords = columns.map { |col| row[col].to_f }
  data_groups[key] << { raw_row: row, coords: coords }
end

puts "✅ #{raw_data_all.size}行, #{data_groups.size} グループのデータを読み込みました。"

# size > 1 のグループと、size <= 1 のグループに分ける
small_groups = data_groups.select { |_, group| group.size <= 1 }
large_groups = data_groups.select { |_, group| group.size > 1 }

if small_groups.empty?
  puts "✅ 再統合対象の単一点クラスタはありませんでした。"
else
  # 統合先の新しいデータグループを準備
  recombined_data_groups = large_groups # .dup # 既存の大きいグループはそのまま維持

  # 再統合対象のキーとデータを処理
  small_groups.each do |key, group|
    # vertex_index を "*" に置換したキーを生成
    combined_key = create_combined_key(key)

    # 統合先のグループにデータを追加
    # combined_key が large_groups に存在する場合、そのグループに結合されるが、そのようにならないように、keyを構成する。
    # 存在しない場合、新しいグループとして作成される。
    recombined_data_groups[combined_key] ||= []
    recombined_data_groups[combined_key].concat(group)
  end

  # 再統合されたデータグループに上書き
  data_groups = recombined_data_groups

  # 統合後のグループサイズを確認
  recombined_count = data_groups.size
  recombined_small_count = data_groups.count { |_, group| group.size <= 1 }

  puts "✅ 単一点クラスタの再統合が完了しました。"
  puts "   -> 統合前グループ数: #{small_groups.size + large_groups.size}"
  puts "   -> 統合後グループ数: #{recombined_count}"
  puts "   -> 統合後も単一点のままのグループ数: #{recombined_small_count}"
end

# --- ステップ2: キーごとにPCA分析を実行 ---
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

      grouped_pca_results[key] = { basis: use_basis, rmse: rmse_val, boundary: boundary }
    rescue StandardError => e
      p ["debug at {grouped_pca_results-error}", key, e]
      next
    end
  end
end

# --- ステップ3: 共通基底と大域射影半径²を計算 ---
common_basis, global_mean = compute_common_basis_from_groups(data_groups)
max_window_radius_sq = compute_max_window_radius_sq(data_groups, common_basis)
# max_window_radius_sq = 30 # compute_max_residual_radius_sq(data_groups, grouped_pca_results)

puts "🌐 共通基底による最大射影半径² = #{max_window_radius_sq}"

# --- ステップ4: 検証CSV出力 ---
verification_csv = "key_restoration_verification-#{raw_data_all.size}.csv"
puts "\n💾 検証CSVを出力中 → #{verification_csv}"

verification_csv_lines = 0
CSV.open(verification_csv, 'w') do |csv|
  # ヘッダーに元のヘッダー名と検証情報を追加
  csv << raw_header_names + %w[
    claster proj_x proj_y inside_boundary rmse radius_sq inside_sq
  ]

  data_groups.each do |key, group|
    res = grouped_pca_results[key]
    unless res
      p ["debug at {verification_csv-data_groups}", key, res, group.size]
      next
    end

    res_basis = res[:basis]
    unless res_basis.size == 2 && res_basis.all? { |b| b.size == 4 }
      p ["debug at {verification_csv-data_groups-basis}", key, res_basis]
      next
    end
    boundary = res[:boundary]
    rmse_val = res[:rmse]

    # PC3/PC4の基底ベクトルの長さの二乗の合計を計算
    radius_sq = res_basis.map { |b| b.map { |x| x**2 }.sum }.sum

    group.each do |g|
      coords = g[:coords]
      if coords.size != 4 || coords.any?(&:nil?)
        p ["debug at {verification_csv-data_groups-group}", key, coords]
        next
      end
      row = g[:raw_row]

      # 各キー固有のPC3/PC4基底を使って射影
      proj = res_basis.map { |b| coords.zip(b).map { |a,bb| a*bb }.sum }
      inside = point_inside_polygon?(proj, boundary)

      # 元の row の値を fields で取得し、射影情報と連結
      row_fields = row.fields

      csv << row_fields + [
        key,
        proj[0].round(6), proj[1].round(6),
        inside,
        rmse_val.round(6),
        radius_sq.round(6), radius_sq <= max_window_radius_sq
      ]
      verification_csv_lines += 1
    end
  end
end

puts "✅ 検証CSV出力完了: #{verification_csv} #{verification_csv_lines}行 (#{raw_data_all.size - verification_csv_lines}行 不足)"

# --- ステップ5: 4D格子探索 ---
max_points=10000
step_points=1000
Start_node = Vector[0,0,0,0] # 1,-230,-201,81]

# 1次近傍ベクトル (隣接点)
# edge1st_coef_set: 許容される隣接ベクトル (12種類)
EDGE_1ST_VECTORS = [
  [-1, 0, 0, 0], [-1, 1, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0],
  [0, 0, -1, 1], [0, 0, 0, -1], [0, 0, 0, 1], [0, 0, 1, -1],
  [0, 0, 1, 0], [0, 1, 0, 0], [1, -1, 0, 0], [1, 0, 0, 0]
].map{|v|Vector[*v]}

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

# --- ステップ5: 幾何学的先読みとPCAフィルタリングによる探索 ---

# --- デバッグカウンターの初期化 ---
$hull_checks = 0
$lookahead_success = 0 # 先読みチェックで通過した回数
$lookahead_fail = 0    # 先読みチェックで排除された回
$multi_match_count = 0
$total_matches_checked = 0

candidates_count = 0
output_csv_filename = "generated_spectre_integer_coords_keyed.csv"

puts "\n🔍 幾何学的先読み探索を開始、結果をファイルに逐次出力中 → #{output_csv_filename}"

visited = Set[Start_node]
CSV.open(output_csv_filename, "w") do |csv|
  # ヘッダーは、ノード座標(4D)と共通基底への射影(2D)とキー
  csv << ['a0', 'a1', 'b0', 'b1', 'key','perp_x', 'perp_y', 'perp_sq','perp_x_common', 'perp_y_common']

  # キューには座標のみを保持（先読みロジックでは親ノード情報は不要）
  queue = [Start_node]

  while !queue.empty? && candidates_count < max_points
    # キューの先頭からFIFOで取り出す
    current_node = queue.shift

    # ===============================================
    # A. 現在ノードの統計的有効性の確認（採用処理）
    # ===============================================

    # 1. 大域的なPC3/PC4残差チェック (PC3/PC4基底への射影)
    perp = common_basis.map { |b| current_node.inner_product(Vector[*b]) }
    perp_sq = perp.map { |x| x**2 }.sum

    # 🚨 大域残差フィルタリング: キュー追加時に既にチェックされているはずだが、
    #    念のためチェック (探索開始ノードのための初期チェックとしても機能)
    next if perp_sq > max_window_radius_sq

    # 2. 局所的な凸包判定とキー復元
    matched_info = []
    grouped_pca_results.each do |key, res|
      $hull_checks += 1

      proj = res[:basis].map { |b| current_node.inner_product(Vector[*b]) }
      proj_sq = proj.map { |x| x**2 }.sum

      if (proj_sq < (res[:rmse] * 2)**2) && point_inside_polygon?(proj, res[:boundary])
        matched_info << [key, proj, proj.map { |x| x**2 }.sum]
      end
    end

    if !matched_info.empty?
      # 採用: RMSE最小のキーを選択 (キー矛盾解消ロジック)
      best_info = matched_info.min_by { |m| m[2] }

      # 🚨 逐次CSV出力とカウント
      csv << current_node.to_a + [best_info[0]] + best_info[1] + [best_info[2]]  + perp
      candidates_count += 1
      # 🚨 DEBUG: ノードが属した凸包の数をカウント
      $multi_match_count += 1 if matched_info.size > 1
      $total_matches_checked += matched_info.size # 一致した凸包の総数
    end

    # ===============================================
    # B. 隣接ノードの生成とフィルタリング（先読み適用）
    # ===============================================

    # 次の候補を、履歴に依存せず常に12方向から探す
    EDGE_1ST_VECTORS.each do |step_vec|
      neighbor_node = current_node + step_vec

      # 訪問済みチェック
      next if visited.include?(neighbor_node)

      # 1. 候補点の統計的有効性チェック (大域残差)
      neighbor_perp = common_basis.map { |b| neighbor_node.inner_product(Vector[*b]) }
      neighbor_perp_sq = neighbor_perp.map { |x| x**2 }.sum

      # 大域残差でオーバーしたら、先読みもせずにスキップ
      if neighbor_perp_sq > max_window_radius_sq
        # 🚨 修正点: フィルタリングで排除されたノードは visited に追加しない 🚨
        # visited << neighbor_node # フィルタリングで排除されたノードも visited に追加
        next
      end

      # 2. 「先読み」ロジックの適用 (幾何学的制約)
      is_not_dead_end = false

      # この候補手（neighbor_node）から、さらに次に行ける手を探す
      grandchild_possible_steps = LEGAL_NEXT_STEPS[step_vec] || []

      grandchild_possible_steps.each do |grandchild_step_vec|
        grandchild_node = neighbor_node + grandchild_step_vec

        # 孫ノードの有効性チェック（大域残差のみ）
        grandchild_perp = common_basis.map { |b| grandchild_node.inner_product(Vector[*b]) }
        grandchild_perp_sq = grandchild_perp.map { |x| x**2 }.sum

        # 統計的制約を通過すればOK
        if grandchild_perp_sq <= max_window_radius_sq
          is_not_dead_end = true
          break
        end
      end

      # 3. 最終的なキューへの追加
      if is_not_dead_end
        $lookahead_success += 1
        visited << neighbor_node
        queue.push(neighbor_node)
      else
        $lookahead_fail += 1
        # 行き止まりの場合、visited には追加しない。
        # (visitedに追加しないことで、他の有効な経路から到達する可能性を残す)
      end
    end

    # step_points 点ごとに出力を表示
    puts "  -> #{candidates_count} nodes, Queue size: #{queue.size}" if candidates_count % step_points == 0
  end
end

puts "✅ 探索完了: #{candidates_count} 点出力"

# --- 探索完了後のデバッグ情報 ---
puts "\n[DEBUG PERFORMANCE]"
puts "  総キュー処理数 (Visited): #{visited.size}"
puts "  先読みチェック通過数: #{$lookahead_success}"
puts "  先読みチェック排除数: #{$lookahead_fail}"
puts "  凸包判定の総実行回数: #{$hull_checks}"
puts "  ノードが属した凸包の総数: #{$total_matches_checked}"
puts "  複数の凸包に属したノード数: #{$multi_match_count}"
puts "  平均多重所属数 (採用点あたり): #{$total_matches_checked.to_f / candidates_count.to_f if candidates_count > 0}"
puts "  ノードごとの平均凸包チェック回数: #{$hull_checks.to_f / visited.size.to_f if visited.size > 0}"
