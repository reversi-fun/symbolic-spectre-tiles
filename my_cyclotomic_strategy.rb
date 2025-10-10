
require 'matrix' # Ruby標準のMatrixライブラリを使用

# ref https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/aperiodic-spectre/

# GeometryStrategyモジュールは別途定義されているものとします
# module GeometryStrategy; end
# 論文の形式 (a₀, a₁, b₀, b₁) で座標を表現するクラス (a,bスケール対応)

class CyclotomicPoint
  attr_reader :a0, :a1, :b0, :b1, :dominant_axis

  @@scale_a = 1.0
  @@scale_b = 1.0
  def self.set_scale(a, b)
     @@scale_a = a.to_f
     @@scale_b = b.to_f
  end

  def initialize(a0, a1, b0, b1, dominant_axis = :spectre)
    @a0, @a1, @b0, @b1 = a0.to_i, a1.to_i, b0.to_i, b1.to_i
    @dominant_axis = [@a0, @a1, @b0, @b1].all?{|e| e.zero?} ? :zero_spectre_mystic : dominant_axis
  end

  def +(other)
    raise ArgumentError.new("座標系が一致しません") unless (@dominant_axis == other.dominant_axis) || (@dominant_axis == :zero_spectre_mystic) || (other.dominant_axis == :zero_spectre_mystic)
    CyclotomicPoint.new(@a0 + other.a0, @a1 + other.a1, @b0 + other.b0, @b1 + other.b1,
     self.dominant_axis != :zero_spectre_mystic ? self.dominant_axis : other.dominant_axis)
  end

  def -(other)
    raise ArgumentError.new("座標系が一致しません") unless (@dominant_axis == other.dominant_axis) || (@dominant_axis == :zero_spectre_mystic) || (other.dominant_axis == :zero_spectre_mystic)
    CyclotomicPoint.new(@a0 - other.a0, @a1 - other.a1, @b0 - other.b0, @b1 - other.b1,
     @dominant_axis != :zero_spectre_mystic ? @dominant_axis : other.dominant_axis)
  end

  def vector
    Vector[@a0, @a1, @b0, @b1]
  end
  def to_vec
    [@a0, @a1, @b0, @b1]
  end

  def to_coef
      [@a0, @a1, @b0, @b1, @dominant_axis]
  end

  # SVG描画のために通常のXY座標 (Float) に変換
  # [8	-7	-3	6] -> ((4.5)*A + (3.0)*B*√3)-((3.5)*A*√3)*i
  # [7	-5	1	4] -> ((4.5)*A + (2.0)*B*√3)+((3.0)*B + (-2.5)*A*√3)*i
  def to_svg_coords
    if @dominant_axis == :spectre
     # 実数部(x軸)の計算
      real_r = 2 * @a0 + @a1
      real_s = 0
      real_x = 0
      real_y = @b1
     # 虚数部(y軸)の計算
      imag_r = 0
      imag_s = @a1
      imag_x = 2 * @b0 + @b1
      imag_y = 0
    elsif @dominant_axis == :mystic
     # 実数部(x軸)の計算
      real_r = 0
      real_s = @b1
      real_x = 2 * @a0 + @a1
      real_y = 0
     # 虚数部(y軸)の計算
      imag_r = 2 * @b0 + @b1
      imag_s = 0
      imag_x = 0
      imag_y = @a1
    elsif @dominant_axis == :zero_spectre_mystic
      return [0.0, 0.0]
    else
      raise ArgumentError.new("未知の座標系です: #{@dominant_axis.inspect}")
    end

    sqrt3_div2 = Math.sqrt(3) / 2
    x = @@scale_a * (real_r * 0.5 + real_s * sqrt3_div2) + @@scale_b * (real_x * 0.5 + real_y * sqrt3_div2)
    y = @@scale_a * (imag_r * 0.5 + imag_s * sqrt3_div2) + @@scale_b * (imag_x * 0.5 + imag_y * sqrt3_div2)
    [x, y]
  end

  def to_s
    return "0+0i" if @dominant_axis == :zero_spectre_mystic

    # 軸ごとの係数抽出
    real_r = (2 * @a0 + @a1) * 0.5
    real_s = @b1 * 0.5
    imag_r = (2 * @b0 + @b1) * 0.5
    imag_s = @a1 * 0.5

    if @dominant_axis == :spectre
      real_label_r, real_label_s = "A", "B*√3"
      imag_label_r, imag_label_s = "B", "A*√3"
      imag_total = imag_r * @@scale_b + imag_s * @@scale_a * Math.sqrt(3)
    elsif @dominant_axis == :mystic
      real_label_r, real_label_s = "B", "A*√3"
      imag_label_r, imag_label_s = "A", "B*√3"
      imag_total = imag_r * @@scale_a + imag_s * @@scale_b * Math.sqrt(3)
    else
      raise ArgumentError.new("未知の座標系です: #{@dominant_axis.inspect}")
    end
    # 虚部構築（符号反転対応）
    imag_sign = imag_total < 0 ? "-" : "+"

    # 実部構築
    real_terms = []
    real_terms << "(#{real_r})*#{real_label_r}" unless real_r.zero?
    real_terms << "(#{real_s})*#{real_label_s}" unless real_s.zero?
    real_str = real_terms.empty? ? "0" : "(#{real_terms.join(' + ')})"

    imag_terms = []
    imag_terms << "(#{imag_total < 0 ? - imag_r : imag_r})*#{imag_label_r}" unless imag_r.zero?
    imag_terms << "(#{imag_total < 0 ? - imag_s : imag_s})*#{imag_label_s}" unless imag_s.zero?
    imag_str = imag_terms.empty? ? "0i" : "(#{imag_terms.join(' + ')})*i"

    # 結合
    "#{real_str}#{imag_sign}#{imag_str}"
   end
end

# 変換を行列とベクトルで表現するクラス
class CyclotomicTransform
  attr_reader  :info, :to_point, :scale_y
  @@reflection_info = { scale_y: -1, matrix: Matrix[[-1, -1, 0, 0], [0, 1, 0, 0], [0, 0, 1, 1], [0, 0, 0, -1]] }

  begin
    @@trot_memo = {
      # Spectre軸回転
      0   => { angle: 0,   change_axis: 1, matrix: Matrix[[ 1, 0, 0, 0], [ 0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]] },
      60  => { angle: 60,  change_axis: 1, matrix: Matrix[[ 0, 1, 0, 0], [-1, 1, 0, 0], [0, 0, 1,-1], [0, 0, 1, 0]] },
      120 => { angle: 120, change_axis: 1, matrix: Matrix[[-1, 1, 0, 0], [-1, 0, 0, 0], [0, 0, 0,-1], [0, 0, 1,-1]] },
      180 => { angle: 180, change_axis: 1, matrix: Matrix[[-1, 0, 0, 0], [ 0,-1, 0, 0], [0, 0,-1, 0], [0, 0, 0,-1]] },
      240 => { angle: 240, change_axis: 1, matrix: Matrix[[ 0,-1, 0, 0], [ 1,-1, 0, 0], [0, 0,-1, 1], [0, 0,-1, 0]] },
      300 => { angle: 300, change_axis: 1, matrix: Matrix[[ 1,-1, 0, 0], [ 1, 0, 0, 0], [0, 0, 0, 1], [0, 0,-1, 1]] },

      # Mystic軸回転
      30  => { angle: 30,  change_axis: -1, matrix: Matrix[[0, 0, 0, 1], [0, 0, 1, 0], [-1, 1, 0, 0], [ 0, 1, 0, 0]] },
      90  => { angle: 90,  change_axis: -1, matrix: Matrix[[0, 0, 1, 0], [0, 0, 1,-1], [-1, 0, 0, 0], [-1, 1, 0, 0]] },
      150 => { angle: 150, change_axis: -1, matrix: Matrix[[0, 0, 1,-1], [0, 0, 0,-1], [ 0,-1, 0, 0], [-1, 0, 0, 0]] },
      210 => { angle: 210, change_axis: -1, matrix: Matrix[[0, 0, 0,-1], [0, 0,-1, 0], [ 1,-1, 0, 0], [ 0,-1, 0, 0]] },
      270 => { angle: 270, change_axis: -1, matrix: Matrix[[0, 0,-1, 0], [0, 0,-1, 1], [ 1, 0, 0, 0], [ 1,-1, 0, 0]] },
      330 => { angle: 330, change_axis: -1, matrix: Matrix[[0, 0,-1, 1], [0, 0, 0, 1], [ 0, 1, 0, 0], [ 1, 0, 0, 0]] }
    }
    @@trot_memo.freeze
  end

  def initialize(angle_deg, to_point, scale_y = 1)
    @info = @@trot_memo[angle_deg] or raise "未定義の角度です: #{angle_deg}"
    raise ArgumentError.new("第2引数はCyclotomicPointである必要があります(#{to_point.class}: #{to_point})") unless to_point.is_a?(CyclotomicPoint)

    @scale_y = scale_y
    @to_point = to_point
  end

  def angle
    @scale_y == -1 ? (180 - @info[:angle]) % 360 : @info[:angle]
  end
  def matrix
    @info[:matrix]
  end

  def self.reflect_matlix
    @@reflection_info[:matrix]
  end

  def reflect
    new_angle = @info[:angle] # (180 - @info[:angle]) % 360
    # diff_angle = (new_angle - @info[:angle]) % 360
    new_point_vector = CyclotomicTransform.reflect_matlix * @to_point.vector
    new_point = CyclotomicPoint.new(*new_point_vector.to_a, @to_point.dominant_axis)
    transform = CyclotomicTransform.new(new_angle,  new_point, -@scale_y) # 反転+0度回転
    # transform = CyclotomicTransform.new(@info[:angle],  @to_point, -@scale_y) # 反転+0度回転
  end

end

# cyclotomic_strategy_ab.rb
require 'matrix'
require './my_geometryStrategy_interface' # インターフェース定義ファイル #
# require './cyclotomic_point' # 上記の補助クラスファイル
class CyclotomicStrategy
  include GeometryStrategy
  def initialize
  end
  def define_spectre_points(a, b) # 最初にCyclotomicPointクラスにスケール係数を設定
    CyclotomicPoint.set_scale(a, b)
    points = [ # a0 , (a1 / 2 + a1 / 2 * sqrt(3) * i), b0, (b1 / 2 + b1 / 2 * sqrt(3) * i)
    [0, 0, 0, 0],
    [1, 0, 0, 0],
    [2, -1, 0, 0],
    [2, -1, 0, 1],
    [2, -1, 1, 1],
    [3, -1, 1, 1],
    [3, 0, 1, 1],
    [3, 0, 2, 0],
    [3, 0, 2, -1],
    [2, 1, 2, -1],
    [1, 1, 2, -1],
    [0, 1, 2, -1],
    [0, 0, 2, -1],
    [0, 0, 1, 0] ].map { |a0, a1, b0, b1| CyclotomicPoint.new(a0, a1, b0, b1) }
    points
  end
  def define_mystic_points(spectre_points)
    return spectre_points.map { |p| CyclotomicPoint.new( p.a0, p.a1, p.b0, p.b1, :mystic) }
    # rotation = rotation_transform(30) # spectre_points.map do |p|
    # rotated = transform_point(rotation, p)
    # CyclotomicPoint.new(rotated.b0, rotated.b1, rotated.a0, rotated.a1, :mystic)
    # end
  end

  @@no_move_point = CyclotomicPoint.new(0, 0, 0, 0, :zero_spectre_mystic).freeze
  def rotation_transform(angle_deg)
    transform = CyclotomicTransform.new(angle_deg, @@no_move_point)
    transform
  end

  def create_transform(angle_deg, move_point, scale_y = 1)
    transform = CyclotomicTransform.new(angle_deg, move_point, scale_y)
  end

  def identity_transform
    rotation_transform(0)
  end
  def get_angle_from_transform(transform)
     [transform.angle, transform.scale_y]
  end
  def compose_transforms(trans_a, trans_b)
    raise ArgumentError.new("第1引数はCyclotomicTransformである必要があります") unless trans_a.is_a?(CyclotomicTransform)
    raise ArgumentError.new("第2引数はCyclotomicTransformである必要があります") unless trans_b.is_a?(CyclotomicTransform)
    p ["debug at enter compose_transforms", [[trans_a.angle, trans_a.scale_y], trans_a.to_point.to_coef, trans_a.to_point.to_s], [[trans_b.angle, trans_b.scale_y], trans_b.to_point.to_coef, trans_b.to_point.to_s]] if debug?

    # 合成スケール（反転の有無）
    new_scale_y = trans_a.scale_y * trans_b.scale_y

    # 座標の合成（trans_bの座標をtrans_aで変換）
    # new_translation = transform_point(trans_a, trans_b.to_point)
    rotated_vec = (trans_a.matrix.transpose * trans_b.to_point.vector)
    rotated_vec = CyclotomicTransform.reflect_matlix * rotated_vec if trans_a.scale_y == -1
    rotated_vec += trans_a.to_point.vector

    # 軸判定
    axis_a = trans_a.to_point.dominant_axis
    axis_b = trans_b.to_point.dominant_axis
    new_dominant_axis =
      if axis_a == :zero_spectre_mystic
        axis_b
      elsif axis_b == :zero_spectre_mystic
        axis_a
      elsif axis_a != axis_b
        axis_b == :spectre ? :mystic : :spectre
      else
        axis_b
      end

    # new_dominant_axis = trans_a.to_point.dominant_axis
    # # ゼロベクトルでなく、かつ軸変換が指定されている場合のみ軸を切り替える
    # if trans_b.info[:change_axis] == -1 && trans_a.to_point.dominant_axis != :zero_spectre_mystic
    #   new_dominant_axis = (trans_a.to_point.dominant_axis == :spectre ? :mystic : :spectre)
    # end

    # 合成角度（反転を考慮した有効角度）
    new_angle = trans_a.angle + (trans_a.scale_y * trans_b.angle)
    new_angle = 180 - new_angle if new_scale_y == -1 # 表示用の有効角度new_angleを、new_scale_yによって内部表現値に変換する
    new_angle %= 360

    # 新しい座標と変換を構築
    transformed_point = CyclotomicPoint.new(rotated_vec[0], rotated_vec[1], rotated_vec[2], rotated_vec[3], new_dominant_axis)
    new_transform = CyclotomicTransform.new(new_angle, transformed_point, new_scale_y)
    p ["debug at leaves compose_transforms", [angles=get_angle_from_transform(new_transform), new_transform.to_point.to_coef, new_transform.to_point.to_s]] if debug?
    new_transform
  end
  def reflect_transform(transform)
    raise ArgumentError.new("第1引数はCyclotomicTransformである必要があります(#{transform.class}: #{transform})") unless transform.is_a?(CyclotomicTransform)
    new_transform = transform.reflect() # 反転+0度回転
    p ["debug at leaves reflect_transform", [get_angle_from_transform(transform), transform.to_point.to_coef, transform.to_point.to_s], [get_angle_from_transform(new_transform), new_transform.to_point.to_coef, new_transform.to_point.to_s]] if debug?
    new_transform
  end
  def transform_point(transform, point)
    raise ArgumentError.new("第1引数はCyclotomicTransformである必要があります(#{transform.class}: #{transform})") unless transform.is_a?(CyclotomicTransform)
    raise ArgumentError.new("第2引数はCyclotomicPointである必要があります(#{point.class}: #{point})") unless point.is_a?(CyclotomicPoint)
    raise ArgumentError.new("座標系が一致しません") unless transform.to_point.dominant_axis == point.dominant_axis || transform.to_point.dominant_axis == :zero_spectre_mystic || point.dominant_axis == :zero_spectre_mystic
    rotated_vec = (transform.matrix.transpose * point.vector)
    rotated_vec = CyclotomicTransform.reflect_matlix * rotated_vec if transform.scale_y == -1
    rotated_vec += transform.to_point.vector

    axis_a = transform.to_point.dominant_axis
    axis_b = point.dominant_axis
    new_dominant_axis =
      if transform.info[:change_axis] < 0  # 30度系の回転 → 軸切り替え
        axis_b == :spectre ? :mystic : :spectre
      elsif axis_a == :zero_spectre_mystic
        axis_b
      elsif axis_b == :zero_spectre_mystic
        axis_a
      else
        axis_b
      end

    transformed_point = CyclotomicPoint.new(rotated_vec[0], rotated_vec[1], rotated_vec[2], rotated_vec[3], new_dominant_axis)
    p ["debug at leaves transform_point" , [get_angle_from_transform(transform), transform.to_point.to_coef, transform.to_point.to_s], [point.to_coef, point.to_s], [transformed_point.to_coef, transformed_point.to_s]] if debug?
    transformed_point
  end
  def point_to_svg_coords(w)
    # CyclotomicPointのインスタンスメソッドを呼び出す
    # これにより、設定済みの a,b スケールが適用される
    return w.to_svg_coords if w.is_a?(CyclotomicPoint)
    return w.to_point.to_svg_coords if w.is_a?(CyclotomicTransform)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

  def point_to_symbolic_str(w)
    # 独自係数クラスを数式に変換
    return w.to_s if w.is_a?(CyclotomicPoint)
    return w.to_point.to_s if w.is_a?(CyclotomicTransform)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

  def to_internal_coefficients(w)
    if w.is_a?(CyclotomicPoint)
      return w.to_coef
    elsif w.is_a?(CyclotomicTransform)
      return w.to_point.to_coef
    else
      p ["NotImplementedError", w.class.name, w]
      raise NotImplementedError
    end
  end
end
if __FILE__ == $0
  # 回転戦略インスタンス
  strategy = CyclotomicStrategy.new # スケール設定（任意）
  strategy.set_debug(true)
  CyclotomicPoint.set_scale(1.0, 1.0) # 初期点（代数的座標）
  point = CyclotomicPoint.new(1, 0, 0, 0) # スケール設定
  spectre_points=strategy.define_spectre_points(1.0, 1.0)
  mystic_points=strategy.define_mystic_points(spectre_points)
  mystic_rotate30degree_points = mystic_points.map{|point| strategy.transform_point(strategy.rotation_transform(30), point)}

  # 図形のパス表示
  puts "# spectre_points = ["
  spectre_points.each_with_index{|point,i| p [i, strategy.to_internal_coefficients(point), strategy.point_to_svg_coords(point), strategy.point_to_symbolic_str(point) ]}
  puts "]"
  puts "# mystic_points = ["
  mystic_points.each_with_index{|point,i| p  [i, strategy.to_internal_coefficients(point), strategy.point_to_svg_coords(point),  strategy.point_to_symbolic_str(point) ]}
  puts "]"
  puts "# mystic rotates 30 degree points = ["
  mystic_rotate30degree_points.each_with_index{|point,i| p  [i, strategy.to_internal_coefficients(point), strategy.point_to_svg_coords(point),  strategy.point_to_symbolic_str(point) ]}
  puts "]"

  # 初期点（代数的座標）
  [ spectre_points[1], mystic_points[1]].each do | point|
    [1, -1].each do |reflection_scale|
      coef=strategy.to_internal_coefficients(point)
      name=coef[4]
      puts "\n=== テスト対象:coef: #{coef}, 初期点: #{point.to_s}=#{strategy.point_to_svg_coords(point)}, 反転(reflection_scale): #{reflection_scale} ==="
      [0, 60, 120, 180, 240].each do |angle|
        effective_angle = name == :mystic ? angle + 30 : angle
        effective_angle %= 360
        transform = strategy.rotation_transform(effective_angle)
        transform = strategy.reflect_transform(transform) if reflection_scale == -1

        rotated = strategy.transform_point(transform, point)
        rotated_float = strategy.point_to_svg_coords(rotated)
        norm = Math.sqrt(rotated_float[0]**2 + rotated_float[1]**2)
        # raise "Normalize Error #{norm} #{rotated_float} coef: #{strategy.to_internal_coefficients(rotated)} from #{strategy.to_internal_coefficients(point)}" unless (norm - 1.0).abs <= 1e-6
        recovered_angle_float_i = (Math.atan2(rotated_float[1] / norm, rotated_float[0] / norm) / Math::PI * 180)
        if recovered_angle_float_i.nan?
          raise "NaN Error #{rotated.to_s} #{rotated_float} coef: #{strategy.to_internal_coefficients(rotated)} from #{strategy.to_internal_coefficients(point)} "
        end
        recovered_angle_float_i = recovered_angle_float_i.round
        recovered_angle_float_i %= 360

        expected_angle = reflection_scale < 0 ? 180 - effective_angle : effective_angle
        expected_angle %= 360

        recovered_angle, recovered_reflection = strategy.get_angle_from_transform(transform)
        recovered_angle %= 360

        ok_logic = (recovered_angle - expected_angle) % 360 == 0 ? 'OK' : "NG(#{(recovered_angle - expected_angle)})"
        ok_float = (recovered_angle_float_i - expected_angle) % 360 == 0 ? 'OK' : "NG(#{(recovered_angle_float_i - expected_angle)})"

        puts "#{reflection_scale == -1 ? '180-' : ''}#{effective_angle}°\t→ #{rotated.to_s.ljust(30)}\t座標: [#{rotated_float.map { |v| v.round(6) }.join(', ')}] * #{recovered_reflection} \t coef: #{strategy.to_internal_coefficients(rotated)} \t逆計算: 有理数=#{recovered_angle}° #{ok_logic}, 実数=#{recovered_angle_float_i}° #{ok_float}"
      end
    end
  end

  [spectre_points, mystic_points].each_with_index do | points, i|
    [1, -1].each do |reflection_scale|
      (30..330).step(30).each do |angle|
        transform = strategy.rotation_transform(angle)
        transform = strategy.reflect_transform(transform) if reflection_scale == -1
        rotated_points = points.map{|point| strategy.transform_point(transform, point)}

        raw_a = []
        raw_b = []
        rotated_points.each_with_index do |rotated_point, j|
          inCoef = strategy.to_internal_coefficients(points[j])
          outCoef= strategy.to_internal_coefficients(rotated_point)
          rotated_float = strategy.point_to_svg_coords(rotated_point)
          symblic_str = rotated_point.to_s
          p [i,  angle, j, inCoef, outCoef, rotated_float, symblic_str]
          if inCoef[0..3].any?{|e| e != 0} && outCoef[0..3].any?{|e| e != 0}
            raw_a << inCoef[0..3]
            raw_b << outCoef[0..3]
          end
        end
        a_data = Matrix.rows(raw_a)
        b_data = Matrix.rows(raw_b)
        # p ["a_data", a_data]
        # p ["b_data", b_data]
        # p ["a_data.transpose * a_data", a_data.transpose * a_data]
        # p ["b_data.transpose * b_data", b_data.transpose * b_data]
        p  [i, (reflection_scale == -1 ? "180-#{angle}" : angle),
            x = ((a_data.transpose * a_data).inverse * a_data.transpose * b_data).map{|e| e.to_i}
            # x = (b_data * ((a_data.transpose * a_data).inverse * a_data.transpose)).map{|e| e.to_i}
           ]
        p ["a_data * x", a_data * x]
        # p ["x * a_data", x * a_data]
      end
    end
  end

end
