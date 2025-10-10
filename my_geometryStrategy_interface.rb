# GeometryStrategy: 幾何学的な計算戦略を定義するインターフェース（モジュール）
# このモジュールを include するクラスは、以下のメソッドをすべて実装する必要があります。

module GeometryStrategy
  # === Point/Matrix生成メソッド ===

  # 図形の基本となる頂点座標の配列を生成して返す
  # @param a [Float] Spectreタイルの辺Aの長さ
  # @param b [Float] Spectreタイルの辺Bの長さ
  # @return [Array<Point>] 頂点座標の配列
  def define_spectre_points(a, b)
    raise NotImplementedError
  end

  # mystic_pointsの頂点座標の配列を生成して返す。
  # Complex(Float)型での係数計算のように、整数項と無理数項の区別がない場合は、define_spectre_pointsを使うべきで、当メソッドを実装する必要は無い
  # @param spectre_points [Array<Point>] Spectreタイルの頂点座標の配列
  # @return [Array<Point>] 点群の頂点座標の配列
  def define_mystic_points(spectre_points)
    raise NotImplementedError
  end

  # === アフィン変換メソッド ===

  # 単位行列（変換なし）のアフィン変換オブジェクトを返す
  # @return [MatrixObject]
  def identity_transform
    raise NotImplementedError
  end

  # 指定された角度の「純粋な回転」を表すアフィン変換オブジェクトを返す
  # @param angle_deg [Integer] 角度（度数法）
  # @return [MatrixObject]
  def rotation_transform(angle_deg)
    raise NotImplementedError
  end

  # 指定された角度の「純粋な回転」を表すアフィン変換オブジェクトを返す
  # @param angle_deg [Integer] 角度（度数法）
  # @param move_point [Point] 移動する点
  # @return [MatrixObject]
  def create_transform(angle_deg, move_point, scale_y = 1)
    raise NotImplementedError
  end
  # Y軸反転を表すアフィン変換オブジェクトを返す
  # @return [MatrixObject]
  # def reflection_transform
  #   raise NotImplementedError
  # end

  # 2つのアフィン変換を合成（乗算）する
  # @param matrix_a [MatrixObject]
  # @param matrix_b [MatrixObject]
  # @return [MatrixObject] 合成されたアフィン変換オブジェクト
  def compose_transforms(matrix_a, matrix_b)
    raise NotImplementedError
  end

  # y軸について反転したアフィン変換を合成（乗算）する
  def reflect_transform(matrix_b)
    raise NotImplementedError
  end

  # 指定された点にアフィン変換を適用する
  # @param transform [MatrixObject] 変換オブジェクト
  # @param point [Point] 変換前の点
  # @return [Point] 変換後の点
  def transform_point(transform, point)
    raise NotImplementedError
  end

  # === データ変換・解析メソッド ===

  # アフィン変換オブジェクトから回転角度とY軸スケールを抽出する
  # @param transform [MatrixObject]
  # @return [Array<Integer, Integer>] [角度, Y軸スケール]
  def get_angle_from_transform(transform)
    raise NotImplementedError
  end

  # 内部表現の点オブジェクトを、SVG描画用の[Float, Float]に変換する
  # @param point [Point]
  # @return [Array<Float, Float>] [x座標, y座標]
  def point_to_svg_coords(point)
    raise NotImplementedError
  end

  def to_internal_coefficients(point)
    raise NotImplementedError
  end

  def set_debug(flag)
    @debug = flag
  end

  def debug?
    @debug
  end
  def name
    self.class.name.gsub(/Strategy$/, '').gsub(/::/, '_')
  end
end
