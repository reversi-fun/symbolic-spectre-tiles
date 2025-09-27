# symbolic_strategy.rb
# GeometryStrategyを実装する、シンボリック係数クラスを使った計算戦略。

require 'complex'
# 独自係数クラスのファイルを読み込みます
# このファイルは別途用意されている必要があります。
require './myComplex2Coef'

class SymbolicCoefStrategy
  include GeometryStrategy

  def initialize
    # 回転行列をメモ化するためのハッシュ
    no_move_point = Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)))
    @trot_memo = {
      -30 => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), no_move_point],
       0  => [Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), no_move_point],
      30  => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(1, 0)), Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)), no_move_point],
      60  => [Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0)), no_move_point],
      120 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)), Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(-1, 0)), no_move_point],
      180 => [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(-2, 0)), no_move_point],
      240 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)), Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), no_move_point]
    }
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
    return @trot_memo[angle_deg] if @trot_memo.key?(angle_deg)
    @trot_memo[angle_deg] or raise "未定義の角度です: #{angle_deg}"
  end

  def reflection_transform
    no_move_point = rotation_transform(0)[2]
    [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), no_move_point]
  end

  def compose_transforms(matrix_a, matrix_b)
    # 元のコードのmul関数のロジック
    [
      Complex(matrix_a[0].real * matrix_b[0].real + matrix_a[1].real * matrix_b[0].imag, matrix_a[0].imag * matrix_b[0].real + matrix_a[1].imag * matrix_b[0].imag),
      Complex(matrix_a[0].real * matrix_b[1].real + matrix_a[1].real * matrix_b[1].imag, matrix_a[0].imag * matrix_b[1].real + matrix_a[1].imag * matrix_b[1].imag),
      Complex(matrix_a[0].real * matrix_b[2].real + matrix_a[1].real * matrix_b[2].imag + matrix_a[2].real, matrix_a[0].imag * matrix_b[2].real + matrix_a[1].imag * matrix_b[2].imag + matrix_a[2].imag)
    ]
  end

  def transform_point(transform, point)
    # 元のコードのtransPt関数のロジック
    Complex(point.real * transform[0].real + point.imag * transform[1].real,
            point.real * transform[0].imag + point.imag * transform[1].imag) + transform[2]
  end

  # === データ変換・解析メソッド ===

  def get_angle_from_transform(transform)
    # 元のコードのtrot_inv関数のロジック
    t = transform
    deg_angle1 = (Math.atan2(t[0].imag.to_f, t[0].real.to_f) / Math::PI * 180).round.to_i
    deg_angle1 += 360 if deg_angle1 <= -180
    deg_angle2 = (Math.atan2(-t[1].real.to_f, t[1].imag.to_f) / Math::PI * 180).round.to_i
    deg_angle2 += 360 if deg_angle2 <= -180

    scale_y = if deg_angle1 == deg_angle2
                1
              elsif deg_angle1 == (-deg_angle2) || (deg_angle1 == (180 - deg_angle2)) || (deg_angle2 == (180 - deg_angle1)) || (deg_angle1 == (deg_angle2 - 180)) || (deg_angle2 == (deg_angle1 - 180))
                -1
              else
                raise "角度の計算エラー: deg1=#{deg_angle1}, deg2=#{deg_angle2}"
              end
    [deg_angle1, scale_y]
  end

  def point_to_svg_coords(point)
    # 独自係数クラスをFloatに変換
    [point.real.to_f, point.imag.to_f]
  end
end
