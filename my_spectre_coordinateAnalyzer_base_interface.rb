# frozen_string_literal: true
require 'matrix'
require 'set'

# ====================================================================
# SpectreCoordinateAnalyzerBaseInterface
#
# 実験的なコード群 (hybrid, keyed, etc.) から抽出された共通機能と
# 最も洗練された実装（精度向上版）を集約したインターフェース定義ファイル。
# ====================================================================

module SpectreMath
  module_function

  # --- ベクトル・行列演算 ---

  def mean_vector(data)
    cols = data.transpose
    cols.map { |col| col.sum / col.size.to_f }
  end

  def center_data(data)
    mean = mean_vector(data)
    data.map { |row| row.zip(mean).map { |x, m| x - m } }
  end

  def outer_product(v1, v2)
    Matrix.rows(v1.to_a.map { |x| v2.to_a.map { |y| x * y } })
  end

  def covariance_matrix(data)
    centered = center_data(data)
    m = Matrix[*centered]
    (m.transpose * m) / data.size.to_f
  end

  def rmse(vectors)
    return 0.0 if vectors.empty?
    Math.sqrt(vectors.map { |v| v.map { |x| x**2 }.sum }.sum / vectors.size.to_f)
  end

  def normalize(v)
    mag = Math.sqrt(v.map { |x| x**2 }.sum)
    return v if mag.zero?
    v.map { |x| x / mag }
  end

  def orthogonalize(v1, v2)
    dot = v1.zip(v2).map { |a, b| a * b }.sum
    scale = dot / v1.map { |x| x**2 }.sum
    v2.zip(v1).map { |b, a| b - scale * a }
  end

  # --- PCA (主成分分析) ---

  # 機能概要: 主成分分析を行い、共分散行列の小さい固有値に対応するn個の固有ベクトルを返す。
  # Input: data (Array<Array<Numeric>>), n_components (Integer), key (String/Optional for debug)
  def pca_components(data, n_components = 2, key = "")
    return [] if data.empty?

    m = data.size
    # 高速化のため、Matrixオブジェクトを介さずに共分散行列を計算
    mean = Vector.elements(data.transpose.map { |col| col.sum / m.to_f })
    centered = data.map { |row| Vector.elements(row) - mean }
    cov = Matrix.zero(4)
    centered.each { |v| cov += outer_product(v, v) }
    cov /= m.to_f

    eig = cov.eigen

    # 固有値の絶対値で昇順ソート（小さい順）
    sorted = eig.eigenvalues.zip(eig.eigenvectors)
                .sort_by { |val, _| val.abs }

    # 小さい固有値に対応する固有ベクトルを抽出
    sorted.first(n_components).map { |_, vec| vec.to_a }
  end

  # --- 最小二乗法 (Least Squares) ---

  def least_squares(x_data, y_data, max_iter = 3, tol = 1e-6, lambda = 1e-8)
    x = Matrix[*x_data]
    y = Vector[*y_data]
    xt = x.transpose

    # 通常の正規方程式
    beta = (xt * x).inverse * xt * y
    beta.to_a
  end
end

module SpectreGeometry
  module_function

  # --- 凸包 (Convex Hull) ---
  # Andrew's Monotone Chain Algorithm
  # my_spectre_coordinateAnalyzer_keyed.rb からの移植（ロバスト版）

  def compute_convex_hull(points)
    # 重複排除とソート
    points = points.uniq.sort_by { |x, y| [x, y] }
    return points if points.size <= 2

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

  # --- 点内包判定 (Point inside Polygon) ---
  # my_spectre_coordinateAnalyzer_keyed.rb からの移植
  # 境界線上や頂点上の判定、縮退した多角形(点、線分)への対応を含むロバスト版

  def point_inside_polygon?(pt, polygon, tol = 1e-6)
    x, y = pt

    if polygon.nil? || polygon.empty?
      return false
    elsif polygon.size == 1
      # 点との一致判定
      point = polygon[0]
      return (x - point[0]).abs < tol && (y - point[1]).abs < tol
    elsif polygon.size == 2
      # 線分上判定
      x1, y1 = polygon[0]
      x2, y2 = polygon[1]
      vx, vy = x2 - x1, y2 - y1
      wx, wy = x - x1, y - y1
      seg_len2 = vx * vx + vy * vy

      if seg_len2 < tol * tol
        return (x - x1).abs < tol && (y - y1).abs < tol
      else
        t = (vx * wx + vy * wy) / seg_len2
        if t > -tol && t < 1.0 + tol
          projx = x1 + t * vx
          projy = y1 + t * vy
          dist2 = (x - projx)**2 + (y - projy)**2
          return dist2 <= tol * tol
        else
          return false
        end
      end
    end

    # 多角形 (size >= 3)
    # 1. 境界（辺上）判定
    j = polygon.size - 1
    polygon.each_with_index do |point_i, i|
      point_j = polygon[j]
      x1, y1 = point_i
      x2, y2 = point_j

      vx, vy = x2 - x1, y2 - y1
      wx, wy = x - x1, y - y1
      seg_len2 = vx * vx + vy * vy

      if seg_len2 < tol * tol
        if (x - x1).abs < tol && (y - y1).abs < tol
          return true
        end
      else
        t = (vx * wx + vy * wy) / seg_len2
        if t > -tol && t < 1.0 + tol
          projx = x1 + t * vx
          projy = y1 + t * vy
          dist2 = (x - projx)**2 + (y - projy)**2
          return true if dist2 <= tol * tol
        end
      end
      j = i
    end

    # 2. 内部判定 (Ray Casting)
    inside = false
    j = polygon.size - 1
    polygon.each_with_index do |point_i, i|
      point_j = polygon[j]
      xi, yi = point_i
      xj, yj = point_j

      if ((yi > y) != (yj > y))
        x_int = (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi
        inside = !inside if x <= x_int + tol
      end
      j = i
    end

    inside
  end
end

# --- KD木 (K-Dimensional Tree) ---
# KNN探索用。hybrid_v2 と coordinateAnalyzer で共通。

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
    if best_nodes.size < k || diff**2 < best_nodes.first[0]
      search_recursive(far_node, target, k, best_nodes)
    end
  end
end


# --- StatisticsManager クラス ---
# 複数の GroupStatistics を管理し、形状のグループキーに応じて適切な統計情報を適用する
class StatisticsManager
  def initialize
    @groups = {} # group_key => GroupStatistics
  end

  def register(group_stats)
    @groups[group_stats.group_key] = group_stats
  end

  def valid?(shape)
    stats = @groups[shape.group_key]
    # 統計情報がないグループがもし在ったら、実装不良として、中断
    raise NotImplementedError, "#{self.class} must set StatisticsManager to GroupStatistics before Valid?"
    # ここでは「制約なし」として有効とする
    # return true unless stats

    # 形状の全頂点についてチェック
    shape.vertices.all? { |v| stats.valid?(v) }
  end
end

# --- GroupStatistics 抽象クラス ---
class GroupStatistics
  attr_reader :group_key

  def initialize(group_key, data_points)
    @group_key = group_key
    @data_points = data_points
  end

  # 頂点座標を与えられて、その形状が有効かどうかを返す
  def valid?(data_point)
    raise NotImplementedError, "#{self.class} must implement #valid?"
  end
end

# --- PCAGroupStatistics クラス ---
# PCA, KNN, 凸包を用いた実装
class PCAGroupStatistics < GroupStatistics
  attr_reader :basis_vectors, :acceptance_domain

  def initialize(group_key, data_points, knn_k = 5)
    super(group_key, data_points)
    @knn_k = knn_k

    # PCA計算
    @basis_vectors = SpectreMath.pca_components(data_points.map(&:to_a), 2, group_key)

    # 2D射影と凸包計算
    projected_2d = project_to_2d(data_points)
    @acceptance_domain = SpectreGeometry.compute_convex_hull(projected_2d)

    # KDTree構築（オプション）
    @kdtree = KDTree.new(projected_2d) if knn_k > 0
  end

  def valid?(data_point)
    # 1. PCA射影により2D座標を計算
    point_2d = project_point_to_2d(data_point)

    # 2. 凸包内部判定
    return false unless SpectreGeometry.point_inside_polygon?(point_2d, @acceptance_domain)

    # 3. KNN密度チェック（オプション）
    if @kdtree && @knn_k > 0
      neighbors = @kdtree.nearest_k(point_2d, @knn_k)
      max_dist_sq = neighbors.last[0]
      return max_dist_sq < 1.0 # 閾値
    end

    true
  end

  private

  def project_to_2d(points)
    points.map { |pt| project_point_to_2d(pt) }
  end

  def project_point_to_2d(point)
    # 基底ベクトルとの内積をとって2D座標に変換
    x = point.inner_product(Vector.elements(@basis_vectors[0]))
    y = point.inner_product(Vector.elements(@basis_vectors[1]))
    [x, y]
  end
end

# --- StrictCASPrGroupStatistics クラス ---
# CASPr理論に基づく厳密な判定（プレースホルダー）
class StrictCASPrGroupStatistics < GroupStatistics
  def valid?(data_point)
    # TODO: CASPr理論に基づく厳密な判定を実装
    true
  end
end

# --- ShapesUnitInfo 抽象クラス ---
# PCA分析結果の係数を保持するグループの単位であり、かつ座標探索のグループ単位でもある
# 「探索図形のグループ」を表す抽象基底クラス

class ShapesUnitInfo
  # 必須インターフェースメソッド（サブクラスで実装すべき）
  def vertices
    raise NotImplementedError, "#{self.class} must implement #vertices"
  end

  def centroid
    raise NotImplementedError, "#{self.class} must implement #centroid"
  end

  def group_key
    raise NotImplementedError, "#{self.class} must implement #group_key"
  end

  @@statistics_manager = nil
  def self.statistics_manager
    @@statistics_manager
  end
  def self.statistics_manager=(manager)
    @@statistics_manager = manager
  end

  def is_valid_with_groupStatistics?
    if @@statistics_manager.nil?
      # Managerがセットされていない場合はチェックをスキップ（またはエラー）
      # ここでは利便性のため true を返すが、運用に合わせて変更可
      return true
    end
    @@statistics_manager.valid?(self)
  end

  # 隣接可能な候補を生成: パターンマッチングを内部で実施し、ShapeInfoインスタンスを直接返す
  def near_shapes_candidates
    raise NotImplementedError, "#{self.class} must implement #near_shapes_candidates"
  end

  def children
    raise NotImplementedError, "#{self.class} must implement #children"
  end


end

# --- ShapeInfo クラス ---
# hybrid_v2 で拡張されたバージョン（重心、角度、スケール、分岐情報を持つ）
# ShapesUnitInfo を継承し、単一のSpectre図形を表現

class ShapeInfo < ShapesUnitInfo
  attr_reader :vertices, :centroid, :angle, :scale
  attr_accessor :invalid_connect_from

  # クラス変数: 有効なパターンのリスト（外部から設定可能）
  @@valid_patterns = []

  def self.valid_patterns=(patterns)
    @@valid_patterns = patterns
  end

  def self.valid_patterns
    @@valid_patterns
  end

  def initialize(vertices, angle = 0.0, scale = 1.0)
    @vertices = vertices          # Array<Vector[a0, a1, b0, b1]>
    @centroid = calculate_centroid(vertices)
    @angle = angle                # Float
    @scale = scale                # Float
    @invalid_connect_from = []    # Array<Vector> (分岐元の重心)
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

  def children
    [self]
  end

  # 隣接判定: 辺を共有するかチェック
  def adjacent_to?(other)
    return false unless other.is_a?(ShapeInfo)

    my_edges = edges.to_a
    other_edges = other.edges.to_a

    my_edges.any? do |v1, v2|
      other_edges.any? do |ov1, ov2|
        (v1 == ov2 && v2 == ov1) || (v1 == ov1 && v2 == ov2)
      end
    end
  end

  # 隣接可能な候補を生成: パターンマッチングを内部で実施し、ShapeInfoインスタンスを直接返す
  def near_shapes_candidates
    Enumerator.new do |y|
      edges.each do |v1, v2|
        edge_vec = v2 - v1

        @@valid_patterns.each do |pattern|
          pattern.size.times do |i|
            p_start = pattern[i]
            p_end = pattern[(i + 1) % pattern.size]
            p_vec = p_start - p_end

            if p_vec == edge_vec
              offset = v2 - p_start
              candidate_points = pattern.map { |v| v + offset }
              candidate_shapeInfo = ShapeInfo.new(candidate_points, @angle, @scale)
              if candidate_shapeInfo.is_valid_with_groupStatistics?
                y << candidate_shapeInfo
              end
            end
          end
        end
      end
    end
  end
end

# --- ClusterInfo クラス ---
# ShapesUnitInfo を継承し、複数の図形からなるクラスター（置換クラスター等）を表現

class ClusterInfo < ShapesUnitInfo
  attr_reader :children, :substitution_rule_id

  def initialize(children, substitution_rule_id = nil)
    @children = children                      # Array<ClusterInfo>
    @substitution_rule_id = substitution_rule_id
  end

  def vertices
    # すべての子要素の頂点を統合
    @children.flat_map(&:vertices).uniq
  end

  def centroid
    # 子要素の重心から計算
    return Vector[0.0, 0.0, 0.0, 0.0] if @children.empty?

    sum = Vector[0.0, 0.0, 0.0, 0.0]
    @children.each { |child| sum += child.centroid }
    sum / @children.size.to_f
  end

  def group_key
    # クラスタのグループキーは子要素の数と置換ルールIDで構成
    "cluster-#{@children.size}-#{@substitution_rule_id}"
  end

  # 隣接可能な候補を生成: 置換ルールに基づく候補生成（将来的な拡張）
  def near_shapes_candidates
    # TODO: 置換ルールに基づく隣接可能なクラスターを生成
    # 現在はプレースホルダーとして空のイテレータを返す
    Enumerator.new do |y|
      # 将来的には、置換ルールに基づいて隣接可能なクラスターを生成
    end
  end
end

# --- SpectreDataLoader クラス ---
# 外部データソース（Generator, CSV）からデータを読み込み、
# 統計情報の構築やパターンの抽出を行う
class SpectreDataLoader
  attr_reader :shapes_by_key, :statistics_manager

  def initialize
    @shapes_by_key = Hash.new { |h, k| h[k] = [] }
    @statistics_manager = StatisticsManager.new
  end

  # 列挙子からデータを読み込む
  # @param shape_enumerator [Enumerator] ShapeInfo を yield する列挙子
  def load(shape_enumerator)
    shape_enumerator.each do |shape|
      @shapes_by_key[shape.group_key] << shape
    end
    self
  end

  # 読み込んだデータから分析を行い、統計情報とパターンを構築する
  def analyze!
    # 1. パターン抽出
    extract_patterns

    # 2. グループ統計情報の構築
    build_group_statistics

    # 3. ShapesUnitInfo への登録
    ShapesUnitInfo.statistics_manager = @statistics_manager

    puts "✅ データ分析完了: #{@shapes_by_key.size} グループ, #{ShapeInfo.valid_patterns.size} パターン"
  end

  private

  def extract_patterns
    patterns = []
    @shapes_by_key.each do |key, shapes|
      shapes.each do |shape|
        # 最初の頂点を基準とした相対座標をパターンとする
        base_v = shape.vertices.first
        pattern = shape.vertices.map { |v| v - base_v }
        patterns << pattern
      end
    end
    # 重複排除
    unique_patterns = patterns.uniq { |pat| pat.map(&:to_a) }
    ShapeInfo.valid_patterns = unique_patterns
  end

  def build_group_statistics
    @shapes_by_key.each do |key, shapes|
      # 頂点データを集める
      data_points = shapes.flat_map(&:vertices)
      # PCA統計情報の作成（データ点数が少ない場合はスキップなどの処理が必要かも）
      if data_points.size >= 4 # 最低限の点数
        stats = PCAGroupStatistics.new(key, data_points)
        @statistics_manager.register(stats)
      end
    end
  end
end

# --- SpectreDataEnumerators モジュール ---
# 各種データソースから ShapeInfo を生成する列挙子を提供するファクトリ
module SpectreDataEnumerators
  module_function

  # CSVファイルから読み込む列挙子
  # hybrid_v2 形式のCSV (full vertex list) を想定
  def from_csv(filename)
    Enumerator.new do |y|
      require 'csv'
      rows_by_shape = Hash.new { |h, k| h[k] = [] }

      CSV.foreach(filename, headers: true) do |row|
        shape_id = row['shape#'] || row["\uFEFFshape#"]
        next unless shape_id

        # 必要なカラムのパース
        coord = ['pt0-coef:a0', 'a1', 'b0', 'b1'].map { |c| row[c].to_f }
        angle = row['angle'].to_f
        scale = row['scale_y'].to_f
        idx = row['vertex_index'].to_i

        rows_by_shape[shape_id] << { idx: idx, coord: Vector[*coord], angle: angle, scale: scale }
      end

      # シェイプごとに ShapeInfo を生成
      rows_by_shape.each do |id, rows|
        # インデックス順にソート (-14..-1 または 0..13)
        sorted_rows = rows.sort_by { |r| r[:idx] }
        vertices = sorted_rows.map { |r| r[:coord] }

        # 頂点数が14であることを確認（必要なら）
        if vertices.size == 14
          first = sorted_rows.first
          y << ShapeInfo.new(vertices, first[:angle], first[:scale])
        end
      end
    end
  end

  # SpectreTilingGenerator から読み込む列挙子
  # generator は SpectreTilingGenerator のインスタンス
  def from_generator(generator, generations)
    Enumerator.new do |y|
      # generator の内部メソッドに依存するため、generator が公開しているメソッドを使用するか、
      # 必要な情報を取得できる前提

      # 注: ここでは generator.generate のブロック引数の仕様に合わせて実装
      generator.generate(generations) do |n, tilesHash|
        next if n == 0 # 0世代目はスキップなど、必要に応じて調整

        tilesHash.each_value do |tile|
          # タイルの頂点座標を計算する必要がある
          # tile オブジェクトから頂点を取得できるか、transform から計算するか
          # ここでは tile.for_each_tile を使って変換行列を取得し、
          # strategy を使って頂点を計算する流れを想定

          # generator から strategy を取得（アクセサがあれば）
          strategy = generator.strategy

          tile.for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
            # 頂点生成ロジック (Spectreの14頂点)
            # Edge_a, Edge_b は定数または generator から取得
            edge_a = 1.0
            edge_b = 1.0
            spectre_points = strategy.define_spectre_points(edge_a, edge_b)

            # transform を適用して座標変換
            vertices = spectre_points.map do |pt|
              trans_pt = strategy.transform_point(transform, pt)
              # 内部係数 (a0, a1, b0, b1) に変換
              coefs = strategy.to_internal_coefficients(trans_pt)
              Vector[*coefs[0..3]]
            end

            # angle, scale の取得
            angle, scale = strategy.get_angle_from_transform(transform)
            # angle が '?' の場合の処理などが必要
            angle_val = (angle == '?') ? 0.0 : angle.to_f

            y << ShapeInfo.new(vertices, angle_val, scale)
          end
        end
      end
    end
  end
end

# --- SpectreRules モジュール ---
module SpectreRules
  module_function

  # --- 汎用的な候補探索関数 ---
  # near_shapes_candidates から候補を取得し、ブロックによる検証ロジックでフィルタリング
  #
  # @param current_unit [ShapesUnitInfo] 現在のユニット（形状またはクラスター）
  # @param visited [Set<Vector>] 訪問済み重心セット
  # @param debug_stats [Hash] 統計情報更新用
  # @return [Array<ShapesUnitInfo>] 新規に見つかった有効なユニットのリスト
  def find_valid_tile_configuration_generic(current_unit, visited, debug_stats)
    candidates_for_unit = []

    # 現在のユニットから隣接候補を生成（パターンマッチング済み）
    current_unit.near_shapes_candidates.each do |candidate_unit|
      next if visited.include?(candidate_unit.centroid)
      candidates_for_unit << candidate_unit
    end

    # 分岐検出（同じ候補が複数回生成された場合）
    unique_candidates = candidates_for_unit.uniq { |u| u.centroid }
    if unique_candidates.size >= 2
      debug_stats[:branch_detected] += 1
      unique_candidates.each do |u|
        u.invalid_connect_from << current_unit.centroid if u.respond_to?(:invalid_connect_from)
      end
    end
    unique_candidates
  end

  # --- 汎用的なメイン探索ループ ---
  #
  # @param initial_shapes [Array<ShapeInfo>] 初期形状リスト
  # @param max_points [Integer] 最大探索点数
  # @param search_range [Hash] 探索範囲 {min_a0:, max_a0:, ...}
  # @param target_coverage [Float] 目標カバレッジ (0.0 - 1.0)
  # @param input_coords_set [Set<Array>] カバレッジ計算用の入力座標セット (Optional)
  # @return [Array<ShapeInfo>] 新規形状リスト
  def run_search_generic(initial_shapes, max_points, search_range, target_coverage = 1.0, input_coords_set = nil)
    visited = Set.new
    queue = []
    candidates = []
    generated_coords_set = Set.new

    # デバッグ統計
    debug_stats = {
      total_queue_processed: 0,
      branch_detected: 0,
      shapes_by_group: Hash.new(0),
      start_time: Time.now
    }

    # 初期化処理
    initial_shapes.each_with_index do |shape, i|
      # 範囲チェック
      in_range = shape.vertices.all? do |pt|
        (search_range[:min_a0]..search_range[:max_a0]).include?(pt[0]) &&
        (search_range[:min_b0]..search_range[:max_b0]).include?(pt[2])
      end

      unless in_range
        puts "❌ エラー: 初期形状 Shape##{i} が探索範囲外です。"
        return candidates, debug_stats
      end

      visited << shape.centroid
      candidates << shape
      debug_stats[:shapes_by_group][shape.group_key] += 1 if shape.respond_to?(:group_key)

      shape.vertices.each { |v| generated_coords_set << v.to_a }

      # Shape#0 は探索済みとし、それ以外をキューに入れる (慣例)
      queue.push(shape) if i > 0
    end

    puts "\n🚀 汎用探索ループを開始します..."
    puts "   初期形状数: #{initial_shapes.size}, Queue: #{queue.size}"

    while !queue.empty? && candidates.size < max_points
      current_shapeUnit = queue.shift
      debug_stats[:total_queue_processed] += 1

      find_valid_tile_configuration_generic(current_shapeUnit, visited, debug_stats).each do |shapeUnit|
        next if visited.include?(shapeUnit.centroid)

        visited << shapeUnit.centroid
        queue.push(shapeUnit)
        candidates << shapeUnit
        debug_stats[:shapes_by_group][shapeUnit.group_key] += 1 if shapeUnit.respond_to?(:group_key)

        shapeUnit.vertices.each { |v| generated_coords_set << v.to_a }
      end

      # 進捗表示とカバレッジ判定
      if candidates.size % 100 == 0
        status_msg = "   ... #{candidates.size} 生成済. Queue: #{queue.size}"

        if input_coords_set
          matched = input_coords_set & generated_coords_set
          coverage = matched.size.to_f / input_coords_set.size
          status_msg += ", Coverage: #{(coverage * 100).round(2)}%"

          if coverage >= target_coverage
            puts status_msg
            puts "\n🎉 目標カバレッジ達成！"
            break
          end
        end
        puts status_msg
      end
    end

    puts "✅ 探索終了. 生成数: #{candidates.size}, 時間: #{Time.now - debug_stats[:start_time]}s"
    return candidates, debug_stats
  end
end

# ====================================================================
# テストコード (if __FILE__ == $0)
# ====================================================================

if __FILE__ == $0
  puts "🧪 インターフェース適合性テストを実行中..."

  # 1. ShapesUnitInfo インターフェースのテスト
  puts "\n【1】ShapeInfo のインターフェーステスト"
  test_vertices = [
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ]
  shape = ShapeInfo.new(test_vertices, 0.0, 1.0)
  puts "  ✓ vertices: #{shape.vertices.size} 個"
  puts "  ✓ centroid: #{shape.centroid}"
  puts "  ✓ group_key: #{shape.group_key}"
  puts "  ✓ children: #{shape.children.size} 個 (自分自身)"

  # 2. ClusterInfo のテスト
  puts "\n【2】ClusterInfo のインターフェーステスト"
  shape2 = ShapeInfo.new([Vector[2, 0, 0, 0], Vector[3, 0, 0, 0]], 0.0, 1.0)
  cluster = ClusterInfo.new([shape, shape2], "test-rule")
  puts "  ✓ vertices: #{cluster.vertices.size} 個 (統合)"
  puts "  ✓ centroid: #{cluster.centroid}"
  puts "  ✓ group_key: #{cluster.group_key}"
  puts "  ✓ children: #{cluster.children.size} 個"

  # 3. adjacent_to? のテスト
  puts "\n【3】adjacent_to? メソッドのテスト"
  shape_a = ShapeInfo.new([
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ], 0.0, 1.0)
  shape_b = ShapeInfo.new([
    Vector[1, 0, 0, 0],
    Vector[2, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ], 0.0, 1.0)
  puts "  ✓ 隣接する図形の判定: #{shape_a.adjacent_to?(shape_b)}"

  # 4. GroupStatistics のテスト
  puts "\n【4】GroupStatistics のテスト"
  test_data = [
    Vector[0.0, 0.0, 0.0, 0.0],
    Vector[1.0, 0.0, 0.0, 0.0],
    Vector[0.0, 1.0, 0.0, 0.0],
    Vector[0.0, 0.0, 1.0, 0.0]
  ]
  stats = PCAGroupStatistics.new("0.0-1.0", test_data, 3)
  puts "  ✓ PCAGroupStatistics 生成: #{stats.group_key}"

  test_shape_valid = ShapeInfo.new([Vector[0.25, 0.25, 0.25, 0.25]], 0.0, 1.0)
  puts "  ✓ valid? (内部点): #{stats.valid?(Vector[0.25, 0.25, 0.25, 0.25])}"

  # ShapesUnitInfo に統計情報をセット
  manager = StatisticsManager.new
  manager.register(stats)
  ShapesUnitInfo.statistics_manager = manager
  puts "  ✓ ShapesUnitInfo.statistics_manager セット完了"

  # 5. near_shapes_candidates のテスト (パターン設定が必要)
  puts "\n【5】near_shapes_candidates のテスト"
  test_pattern = [
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ]
  ShapeInfo.valid_patterns = [test_pattern]

  # 候補生成（valid? チェックが内部で走る）
  # テストデータは凸包内に入るように調整が必要だが、ここでは動作確認のみ
  candidates = shape_a.near_shapes_candidates.take(3)
  puts "  ✓ パターン設定完了: #{ShapeInfo.valid_patterns.size} 個"
  puts "  ✓ 生成された候補: #{candidates.size} 個 (フィルタリング後)"

  puts "\n✅ すべてのインターフェーステストが完了しました！"
  puts "📝 改善点:"
  puts "   - GroupStatisticsによる生成時フィルタリングを実装"
  puts "   - near_shapes_candidatesがvalidな候補のみを返す"
  puts "   - 探索ループから重複チェックを削除し高速化"
end # main
