# symbolic_strategy.rb
# GeometryStrategyを実装する、シンボリック係数クラスを使った計算戦略。

require 'complex'
# 独自係数クラスのファイルを読み込みます
# このファイルは別途用意されている必要があります。
require './myComplex2Coef'
require './my_geometryStrategy_interface'

class SymbolicCoefStrategy
  include GeometryStrategy

  begin
    # 回転行列をメモ化するためのハッシュ
    no_move_point = Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)))
    @@trot_memo = {
       0  => [Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), no_move_point],
      60  => [Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0)), no_move_point],
      120 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)), Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(-1, 0)), no_move_point],
      180 => [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(-2, 0)), no_move_point],
      240 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)), Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), no_move_point],
      30  => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(1, 0)), Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)), no_move_point],
      # scectre模様の描画には不要だが、検証コードには必要な回転角
      90  => [Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), no_move_point],
      150 => [Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0)), Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)), no_move_point],
      210 => [Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(-1, 0)), Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1)), no_move_point],
      270 => [Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(-2, 0)), Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), no_move_point],
      300 => [Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0,-1)), Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(1, 0)), no_move_point],
      330 => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), no_move_point],
      # 回転角を　逐次0から330に正規化したことにより不要となった角度
      # -30 => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), no_move_point],
      # -60 => [Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0,-1)), Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(1, 0)), no_move_point],
      # -90 => [Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(-2, 0)), Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), no_move_point],
      # -120=> [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)), Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), no_move_point],
      # -150=> [Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(-1, 0)), Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1)), no_move_point],
    }
    # p "@@trot_memo="
    # @@trot_memo.each{|angle, value| p "#{angle} => #{value[0].to_s}, #{[value[0].real.to_f, value[0].imag.to_f]} ,#{(Math.atan2(value[0].imag.to_f,value[0].real.to_f ) / Math::PI * 180).round}, #{(Math.atan2(-value[1].real.to_f,value[1].imag.to_f ) / Math::PI * 180).round}"}
  end

  def initialize
  end

  # === Point/Matrix生成メソッド ===

  def define_spectre_points(a, b)
    # グローバルな係数を設定
    MyNumeric2Coef.A = a
    MyNumeric2Coef.B = b

    # 3番目のコードのSPECTRE_POINTSの定義と全く同じです
    [
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(0, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(4, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))),
      Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)))
    ]
  end

  def define_mystic_points(spectre_points)
    spectre_points.map do |c|
      Complex(MyNumeric2Coef.new(c.real.xy, c.real.uv), MyNumeric2Coef.new(c.imag.xy, c.imag.uv))
    end
  end

  # === アフィン変換メソッド ===

  def identity_transform
    rotation_transform(0)
  end

  def rotation_transform(angle_deg)
    return @@trot_memo[angle_deg] if @@trot_memo.key?(angle_deg)
    @@trot_memo[angle_deg] or raise "未定義の角度です: #{angle_deg}"
  end

  def create_transform(angle_deg, move_point, scale_y = 1)
    transform = rotation_transform(angle_deg)
    [transform[0], transform[1] , move_point]
  end

  # def reflection_transform
  #   no_move_point = rotation_transform(0)[2]
  #   [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), no_move_point]
  # end

  def compose_transforms(matrix_a, matrix_b)
     p ["debug at enter compose_transforms", [get_angle_from_transform(matrix_a), to_coef(matrix_a[2]), matrix_a[2].to_s], [get_angle_from_transform(matrix_b), to_coef(matrix_b[2]), matrix_b[2].to_s]] if debug?
    transform =[
      Complex(matrix_a[0].real * matrix_b[0].real + matrix_a[1].real * matrix_b[0].imag, matrix_a[0].imag * matrix_b[0].real + matrix_a[1].imag * matrix_b[0].imag),
      Complex(matrix_a[0].real * matrix_b[1].real + matrix_a[1].real * matrix_b[1].imag, matrix_a[0].imag * matrix_b[1].real + matrix_a[1].imag * matrix_b[1].imag),
      Complex(matrix_a[0].real * matrix_b[2].real + matrix_a[1].real * matrix_b[2].imag + matrix_a[2].real,
              matrix_a[0].imag * matrix_b[2].real + matrix_a[1].imag * matrix_b[2].imag + matrix_a[2].imag)
    ]
    p ["debug at leaves compose_transforms", [angles=get_angle_from_transform(transform), to_coef(transform[2]), transform[2].to_s]] if debug?
    # angle_x, scale_x, angle_diff_x = angles
    # angle_x %= 360
    # angle_a, scale_a,angle_diff_a = get_angle_from_transform(matrix_a)
    # angle_b, scale_b,angle_diff_b = get_angle_from_transform(matrix_b)
    # p ["debug at leaves angles", [angle_a, angle_b, angle_x], [scale_a, scale_b, scale_x],[angle_diff_a, angle_diff_b, angle_diff_x],  [(angle_a + angle_b) % 360 == angle_x, (angle_a - angle_b) % 360 == angle_x],
    # (angle_a == 0 || angle_b == 0 ? "zero" : "nonZero"),(angle_b == 30 ? "change_axis" : "no_change_axis") , (angle_x - angle_a - angle_b) % 360]
    transform
  end

  def reflect_transform(trsf_b)
    transform = [ # [Complex(-1.0, 0), Complex(0, 1.0), no_move_point]
      Complex(-trsf_b[0].real, trsf_b[0].imag),
      Complex(-trsf_b[1].real, trsf_b[1].imag),
      Complex(-trsf_b[2].real, trsf_b[2].imag)
    ]
    p ["debug at leaves reflect_transform", [get_angle_from_transform(trsf_b), to_coef(trsf_b[2]), trsf_b[2].to_s], [get_angle_from_transform(transform), to_coef(transform[2]), transform[2].to_s]] if debug?
    transform
  end

  def transform_point(transform, point)
    # 元のコードのtransPt関数のロジック
    transformed_point = Complex(point.real * transform[0].real + point.imag * transform[1].real,
            point.real * transform[0].imag + point.imag * transform[1].imag) + transform[2]
    p ["debug at leaves transform_point" , [get_angle_from_transform(transform), to_coef(transform[2]), transform[2].to_s], [to_coef(point), point.to_s], [to_coef(transformed_point), transformed_point.to_s] ] if debug?
    transformed_point
  end

  # === データ変換・解析メソッド ===

  def get_angle_from_transform(transform)
    xvec = transform[0]
    yvec = transform[1]

    # x軸ベクトルから回転角度を算出 (cos,sin)
    deg_x = (Math.atan2(xvec.imag.to_f, xvec.real.to_f) / Math::PI * 180).round % 360

    # y軸ベクトルから角度を算出（比較用）(-sin,cos)
    deg_y = (Math.atan2(yvec.imag.to_f, yvec.real.to_f) / Math::PI * 180).round % 360

    # xvec と yvec の関係から scale_y を判定
    angle_between = (deg_y - deg_x) % 360

    scale_y = case angle_between
            when 90, 210 then 1
            when 270, 150 then -1
            else
              raise "反転判定エラー: xvecとyvecが直交していません（差=#{angle_between}°）\n" \
                    "xvec: #{xvec.to_s} → 角度=#{deg_x}°\n" \
                    "yvec: #{yvec.to_s} → 角度=#{deg_y}°"
            end
    [deg_x, scale_y]
  end

  def point_to_svg_coords(w)
    # 独自係数クラスをFloatに変換
    return [w.real.to_f, w.imag.to_f] if w.is_a?(Complex)
    return [w[2].real.to_f, w[2].imag.to_f] if w.is_a?(Array) && w[2].is_a?(Complex)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

  def point_to_symbolic_str(w)
    # 独自係数クラスを数式に変換
    return w.to_s if w.is_a?(Complex)
    return w[2].to_s if w.is_a?(Array) && w[2].is_a?(Complex)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

  def to_internal_coefficients(w)
    return to_coef(w) if  w.is_a?(Complex) && w.real.is_a?(MyNumeric2Coef) && w.imag.is_a?(MyNumeric2Coef)
    return to_coef(w[2]) if  w.is_a?(Array) && w[2].is_a?(Complex) && w[2].real.is_a?(MyNumeric2Coef) && w[2].imag.is_a?(MyNumeric2Coef)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end
end

require 'matrix'

if __FILE__ == $0
  # 回転戦略インスタンス
  strategy = SymbolicCoefStrategy.new
  strategy.set_debug(true)
  # スケール設定
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
        effective_angle = effective_angle > 270 ? effective_angle - 360 : effective_angle
        transform = strategy.rotation_transform(effective_angle)
        transform = strategy.reflect_transform(transform) if reflection_scale == -1

        rotated = strategy.transform_point(transform, point)
        rotated_float = strategy.point_to_svg_coords(rotated)
        norm = Math.sqrt(rotated_float[0]**2 + rotated_float[1]**2)
        raise "Normalize Error #{norm} #{rotated_float} coef: #{strategy.to_internal_coefficients(rotated)} from #{strategy.to_internal_coefficients(point)}" unless (norm - 1.0).abs <= 1e-6
        recovered_angle_float_i = (Math.atan2(rotated_float[1], rotated_float[0]) / Math::PI * 180).round
        recovered_angle_float_i %= 360

        expected_angle = reflection_scale < 0 ? 180 - effective_angle : effective_angle
        expected_angle %= 360

        recovered_angle, recovered_reflection = strategy.get_angle_from_transform(transform)
        recovered_angle %= 360

        ok_logic = (recovered_angle - expected_angle) % 360 == 0 ? 'OK' : 'NG'
        ok_float = (recovered_angle_float_i - expected_angle) % 360 == 0 ? 'OK' : 'NG'

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
