# float_strategy.rb
# GeometryStrategyインターフェースを実装し、
# 標準のComplexクラスとFloatを用いて幾何学計算を行う戦略クラス。

require 'complex'
require './my_geometryStrategy_interface'

class FloatStrategy
  include GeometryStrategy

  begin
    no_move_point = Complex(0, 0)
    # 回転行列の計算結果をメモ化するためのハッシュ
    @@trot_memo = { # @@trot_memo[angle_deg] = [Complex(cos(angle), sin(angle)), Complex(-sin(angle), cos(angle)), no_move_point]
      #  -30=> [Complex(Math.sqrt(3)/2, 0.5),   Complex(-0.5, Math.sqrt(3)/2 ), Complex(0.0)],
      0 => [Complex(1, 0), Complex(0, 1), no_move_point],
      30 => [Complex(Math.sqrt(3) / 2, 0.5),   Complex(-0.5, Math.sqrt(3) / 2), no_move_point],
      60 => [Complex(0.5, Math.sqrt(3) / 2),   Complex(-Math.sqrt(3) / 2,  0.5), no_move_point],
      120 => [Complex(-0.5, Math.sqrt(3) / 2), Complex(-Math.sqrt(3) / 2, -0.5), no_move_point],
      180 => [Complex(-1.0, 0.0), Complex(0.0, -1.0), no_move_point],
      # 240 => [Complex(-0.5, -Math.sqrt(3) / 2), Complex(Math.sqrt(3) / 2, -0.5), no_move_point]
    }
  end

  def initialize
  end

  # @see GeometryStrategy#define_spectre_points
  def define_spectre_points(a, b)
    a_sqrt3_d2 = a * Math.sqrt(3) / 2.0
    a_d2 = a * 0.5
    b_sqrt3_d2 = b * Math.sqrt(3) / 2.0
    b_d2 = b * 0.5

    [
      Complex(0, 0),
      Complex(a, 0),
      Complex(a + a_d2, -a_sqrt3_d2),
      Complex(a + a_d2 + b_sqrt3_d2, -a_sqrt3_d2 + b_d2),
      Complex(a + a_d2 + b_sqrt3_d2, -a_sqrt3_d2 + b + b_d2),
      Complex(a + a + a_d2 + b_sqrt3_d2, -a_sqrt3_d2 + b + b_d2),
      Complex(a + a + a + b_sqrt3_d2, b + b_d2),
      Complex(a + a + a, b + b),
      Complex(a + a + a - b_sqrt3_d2, b + b - b_d2),
      Complex(a + a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2),
      Complex(a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2),
      Complex(a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2),
      Complex(0 - b_sqrt3_d2, b + b - b_d2),
      Complex(0, b)
    ]
  end

  def define_mystic_points(spectre_points)
    a = spectre_points[1].real
    b = spectre_points.last.imag
    return define_spectre_points(b,a)
  end

  # @see GeometryStrategy#identity_transform
  def identity_transform
    no_move_point = Complex(0, 0)
    [Complex(1.0, 0), Complex(0, 1.0), no_move_point]
  end

  # @see GeometryStrategy#reflection_transform
  # def reflection_transform
  #   no_move_point = Complex(0, 0)
  #   [Complex(-1.0, 0), Complex(0, 1.0), no_move_point]
  # end

  # @see GeometryStrategy#rotation_transform
  def rotation_transform(angle_deg)
    return @@trot_memo[angle_deg] if @@trot_memo.key?(angle_deg)

    rad = (angle_deg * Math::PI / 180)
    c = Math.cos(rad)
    s = Math.sin(rad)
    no_move_point = Complex(0, 0)

    @@trot_memo[angle_deg] = [Complex(c, s), Complex(-s, c), no_move_point]
  end

  def create_transform(angle_deg, move_point, scale_y = 1)
    transform = rotation_transform(angle_deg)
    [transform[0], transform[1] , move_point]
  end

  # @see GeometryStrategy#get_angle_from_transform
  def get_angle_from_transform(transform)
    t = transform
    deg_angle1 = (Math.atan2(t[0].imag, t[0].real) / Math::PI * 180).round.to_i
    deg_angle1 += 360 if deg_angle1 <= -180

    # Y軸スケールを簡易的に判定
    scale_y = (t[0].real * t[1].imag - t[0].imag * t[1].real) > 0 ? 1 : -1

    [deg_angle1, scale_y]
  end

  # @see GeometryStrategy#compose_transforms
  def compose_transforms(trsf_a, trsf_b)
    [
      Complex(
        trsf_a[0].real * trsf_b[0].real + trsf_a[1].real * trsf_b[0].imag,
        trsf_a[0].imag * trsf_b[0].real + trsf_a[1].imag * trsf_b[0].imag
      ),
      Complex(
        trsf_a[0].real * trsf_b[1].real + trsf_a[1].real * trsf_b[1].imag,
        trsf_a[0].imag * trsf_b[1].real + trsf_a[1].imag * trsf_b[1].imag
      ),
      Complex(
        trsf_a[0].real * trsf_b[2].real + trsf_a[1].real * trsf_b[2].imag + trsf_a[2].real,
        trsf_a[0].imag * trsf_b[2].real + trsf_a[1].imag * trsf_b[2].imag + trsf_a[2].imag
      )
    ]
  end

  def reflect_transform(trsf_b)
    [ # [Complex(-1.0, 0), Complex(0, 1.0), no_move_point]
      Complex(-trsf_b[0].real, trsf_b[0].imag),
      Complex(-trsf_b[1].real, trsf_b[1].imag),
      Complex(-trsf_b[2].real, trsf_b[2].imag)
    ]
  end

  # @see GeometryStrategy#transform_point
  def transform_point(transform, point)
    Complex(
      point.real * transform[0].real + point.imag * transform[1].real,
      point.real * transform[0].imag + point.imag * transform[1].imag
    ) + transform[2]
  end

  # @see GeometryStrategy#point_to_svg_coords
  def point_to_svg_coords(w)
    return [w.real.to_f, w.imag.to_f] if w.is_a?(Complex)
    return [w[2].real.to_f, w[2].imag.to_f] if w.is_a?(Array) && w[2].is_a?(Complex)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

   def point_to_symbolic_str(w)
    real, imag = point_to_svg_coords(w)
    return "#{real} + #{imag}i"
  end


  def to_internal_coefficients(point)
    return [point.real.to_f, point.imag.to_f] if point.is_a?(Complex)
    return [point[2].real.to_f, point[2].imag.to_f] if point.is_a?(Array) && point[2].is_a?(Complex)
    p ["NotImplementedError", w.class.name, w]
    raise NotImplementedError
  end

end
