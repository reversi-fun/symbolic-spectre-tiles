# Symbolic Computation, Computer Algebra System
# require 'mathn'

class MyNumericBase < Numeric
  CONST_EPSILON = Math.sqrt(Float::EPSILON)
  HALF = 0.5 # Rational(1, 2)
  SQRT3_HALF = Math.sqrt(3) / 2
end

class MyNumericCoef < MyNumericBase
  attr_accessor :r, :s, :c

  def initialize(r, s, c)
    @r, @s, @c = r, s, c
  end

  def to_f
    ((@r * @c) * HALF.to_f) + ((@s * @c) * SQRT3_HALF)
  end

  def +(other)
    case other
    when Integer
      MyNumericCoef.new(@r + other, @s, @c)
    when MyNumericCoef
      raise_invalid_argument('+', other) unless @c == other.c || other.zero? || self.zero?
      MyNumericCoef.new(@r + other.r, @s + other.s, @c)
    # when Float　無誤差演算を行うためには、Floatの加算は許可しない
    #   MyNumericCoef.new(@r + other, @s, @c)
    else
      raise_invalid_argument('+', other)
    end
  end

  def -(other)
    case other
    when Integer
      MyNumericCoef.new(@r - other, @s, @c)
    when MyNumericCoef
      raise_invalid_argument('-', other) unless @c == other.c
      MyNumericCoef.new(@r - other.r, @s - other.s, @c)
    else
      raise_invalid_argument('-', other)
    end
  end

  def *(other)
    case other
    when Integer
      return @c == 1 ? MyNumeric1Coef.new(@r * other, @s * other) : MyNumericCoef.new(@r * other, @s * other, @c)
    when MyNumeric2Coef
      return other * self if @c == 1 # coerce メソッドだけでは解決できない特定の状況に対処するために必要。
    when MyNumericCoef
      return raise_invalid_argument('*', other) unless (@c == 1) || (other.c == 1)
      u = ((@r * other.r) + (3 * (@s * other.s))) * HALF
      v = ((@r * other.s) + (@s * other.r)) * HALF
      c = @c * other.c
      return c == 1 ? MyNumeric1Coef.new(u, v) : MyNumericCoef.new(u, v, c)
    else
    end
    raise_invalid_argument('*', other)
  end

  def -@
    MyNumericCoef.new(-@r, -@s, @c)
  end

  def zero?
    (r.abs < CONST_EPSILON) && (s.abs < CONST_EPSILON)
  end

  def <=>(other)
    to_f <=> other.to_f
  end

  # 与えられたオブジェクトを、数学的操作において現在のオブジェクトと互換性を持つように強制変換します。
  # @param other [Object] 強制変換するオブジェクト。
  def coerce(other)
    if other.is_a?(Integer) || other.is_a?(MyNumeric2Coef)
      p ['coerce', other, self] # デバッグ用 強制型変換が呼ばれないことを期待
      [other, self]
    else
      raise_invalid_argument('coerce', other)
    end
  end

  def to_s
    return inspect unless @c == 1
    t = []
    t << "(#{@r / 2.0})" if @r != 0
    t << "(#{@s / 2.0})*√3" if @s != 0
    t.empty? ? '0' : '(' + t.join(' + ') + ')'
  end

  def inspect
    "MyNumericCoef(c:#{@c}, r:#{@r}, s: #{@s})"
  end

  private

  def raise_invalid_argument(op, other)
    p ['Invalid argument for operator ' + self.class.name + ' ' + op + ' ' + other.class.name, self, other]
    raise ArgumentError.new('Invalid argument for operator ' + self.class.name + ' ' + op + ' ' + other.class.name)
  end
end

class MyNumeric1Coef < MyNumericCoef
  def initialize(r, s)
    super(r, s, 1)
  end

  def -@
    MyNumeric1Coef.new(-@r, -@s)
  end

  def to_s
    t = []
    t << "(#{@r / 2.0})" if @r != 0
    t << "(#{@s / 2.0})*√3" if @s != 0
    t.empty? ? '0' : '(' + t.join(' + ') + ')'
  end

  def inspect
    "MyNumeric1Coef(c:#{@c}, r:#{@r}, s: #{@s})"
  end

  def check_consistency
    result = ((to_f - eval(to_s.gsub('√3', "#{Math.sqrt(3)}")).abs) < CONST_EPSILON)
    p ['check_consistency failed', to_f, eval(to_s.gsub('√3', "#{Math.sqrt(3)}"))] unless result
    result
  end
end

class MyNumeric2Coef < MyNumericBase
  attr_accessor :uv, :xy

  @@A = 1
  @@B = 1

  def self.A=(value) # attr_accessorはインスタンス変数用のゲッター/セッターを生成するため、クラス変数（@@）の操作には使えません。クラス変数を操作するには、現在のようなクラスメソッドが必要です。
    @@A = value
  end

  def self.B=(value)
    @@B = value
  end

  def initialize(uv, xy)
    @uv = uv.c == @@A ? uv : MyNumericCoef.new(uv.r, uv.s, @@A)
    @xy = xy.c == @@B ? xy : MyNumericCoef.new(xy.r, xy.s, @@B)
  end

  def to_f
    ((uv.r * @@A * HALF) + (uv.s * @@A * SQRT3_HALF)) + ((xy.r * @@B * HALF) + (xy.s * @@B * SQRT3_HALF))
  end

  def +(other)
    return self if other.zero?
    return MyNumeric2Coef.new(@uv + other.uv, @xy + other.xy) if other.is_a?(MyNumeric2Coef)
    raise_invalid_argument('+', other)
  end

  def -(other)
    return self if other.zero?
    return MyNumeric2Coef.new(@uv - other.uv, @xy - other.xy) if other.is_a?(MyNumeric2Coef)
    raise_invalid_argument('-', other)
  end

  def *(other)
    return MyNumeric2Coef.new(@uv * other, @xy * other) if other.is_a?(Integer)
    if other.is_a?(MyNumericCoef) && (other.c == 1)
      u = ((@uv.r * other.r) + (3 * (@uv.s * other.s))) * HALF
      v = ((@uv.r * other.s) + (@uv.s * other.r)) * HALF

      x = ((@xy.r * other.r) + (3 * (@xy.s * other.s))) * HALF
      y = ((@xy.r * other.s) + (@xy.s * other.r)) * HALF

      MyNumeric2Coef.new(MyNumericCoef.new(u, v, @@A), MyNumericCoef.new(x, y, @@B))
    elsif other.is_a?(MyNumeric2Coef) && other.uv.c == 1 && other.xy.c == 1 && (other.uv.zero? || other.xy.zero? )
      p ['*** not support MyNumeric2Coef * MyNumeric2Coef', self, other] # デバッグ用
            # (uA + vB) * (u'A + v'B) = (uu'AA + uv'AB + vu'BA + vv'BB)
      # ここで AA = -A + 2B, AB = A + B, BB = 2A + B
      # uA * u'A = (u*u')(-A + 2B) = -(u*u')A + 2(u*u')B
      # uA * v'B = (u*v')(A + B) = (u*v')A + (u*v')B
      # vB * u'A = (v*u')(A + B) = (v*u')A + (v*u')B
      # vB * v'B = (v*v')(2A + B) = 2(v*v')A + (v*v')B

      new_uv = (@uv * other.uv) * MyNumeric1Coef.new(-1, 0) +
               (@uv * other.xy) * MyNumeric1Coef.new(1, 0) +
               (@xy * other.uv) * MyNumeric1Coef.new(1, 0) +
               (@xy * other.xy) * MyNumeric1Coef.new(2, 0)

      new_xy = (@uv * other.uv) * MyNumeric1Coef.new(2, 0) +
               (@uv * other.xy) * MyNumeric1Coef.new(1, 0) +
               (@xy * other.uv) * MyNumeric1Coef.new(1, 0) +
               (@xy * other.xy) * MyNumeric1Coef.new(1, 0)

      MyNumeric2Coef.new(new_uv, new_xy)
    else
      raise_invalid_argument('*', other)
    end
  end

  def coerce(other)
    if other.is_a?(Integer) || other.is_a?(MyNumeric1Coef)
      p ['coerce', other, self] # デバッグ用 強制型変換が呼ばれないことを期待
      [other, self]
    else
      raise_invalid_argument('coerce', other)
    end
  end

  def -@
    MyNumeric2Coef.new(-@uv, -@xy)
  end

  def <=>(other)
    to_f <=> other.to_f
  end

  def zero?
    @uv.zero? && @xy.zero?
  end

  def to_s
    t = []
    t << "(#{@uv.r / 2.0})*A" if @uv.r != 0
    t << "(#{@xy.r / 2.0})*B" if @xy.r != 0
    t << "(#{@uv.s / 2.0})*A*√3" if @uv.s != 0
    t << "(#{@xy.s / 2.0})*B*√3" if @xy.s != 0
    t.empty? ? '0' : '(' + t.join(' + ') + ')'
  end

  def inspect
    "MyNumeric2Coef(uv:#{@uv.inspect}, xy:#{@xy.inspect})"
  end

  def to_vec
    [@uv.r.to_i, @uv.s.to_i, @xy.r.to_i, @xy.s.to_i]
  end

  def dominant_axis
    if self.zero?
      :zero_spectre_mystic
    elsif @uv.s.zero? && @xy.r.zero? # a_magnitude >= b_magnitude
      :spectre
    elsif @uv.r.zero? && @xy.s.zero? # a_magnitude < b_magnitude
      :mystic
    else
      raise ArgumentError.new("invalid dominant axis: [#{to_vec().join(', ')}]")
      :undetermined
    end
  end

  def check_consistency
    self_dominant_axis = dominant_axis()
    result = (self_dominant_axis == :spectre || self_dominant_axis == :mystic || self_dominant_axis == :zero_spectre_mystic) &&
       ((to_f - eval(to_s.gsub('A', "#{@@A}").gsub('B', "#{@@B}").gsub('√3', "#{Math.sqrt(3)}")).abs) < CONST_EPSILON)
    unless result
      p ['check_consistency failed', to_f, self_dominant_axis,eval(to_s.gsub('A', "#{@@A}").gsub('B', "#{@@B}").gsub('√3', "#{Math.sqrt(3)}"))]
    end
    result
  end

  private

  def raise_invalid_argument(op, other)
    p ['Invalid argument for operator ' + self.class.name + ' ' + op + ' ' + other.class.name, self, other]
    raise ArgumentError.new('Invalid argument for operator ' + self.class.name + ' ' + op + ' ' + other.class.name)
  end
end

def to_vec(v)
  vec = v.real.to_vec + v.imag.to_vec
  return  [vec, '8d']
  if vec[1].zero? && vec[2].zero? && vec[4].zero? && vec[7].zero?
    [vec[0], vec[3], vec[5], vec[6]]
  else
    [vec, '8d']
  end
end

def to_coef(w)
  # Early return for invalid input type
  return ['Invalid input to to_coef', w] unless w.is_a?(Complex) &&
         w.real.is_a?(MyNumeric2Coef) && w.imag.is_a?(MyNumeric2Coef)

  axis_real = w.real.dominant_axis
  axis_imag = w.imag.dominant_axis
  axis_imag = axis_imag == :spectre ? :mystic : axis_imag == :mystic ? :spectre : axis_imag

  if w.zero?
    [0, 0, 0, 0, :zero_spectre_mystic]
  elsif (w.real.uv.s.zero? && w.real.xy.r.zero? && w.imag.uv.r.zero? && w.imag.xy.s.zero?)
    a0 = ((w.real.uv.r - w.imag.uv.s) / 2.0).to_i
    a1 = w.imag.uv.s.to_i
    b0 = ((w.imag.xy.r - w.real.xy.s) / 2.0).to_i
    b1 = w.real.xy.s.to_i
    a_magnitude = a0.abs + a1.abs
    b_magnitude = b0.abs + b1.abs
    axis = (a_magnitude >= b_magnitude) ? :spectre : :mystic
    p ["invalid dominant axis: #{ [a0, a1, b0, b1, axis_real, axis_imag, axis, to_vec(w)]}"] if  (axis_real != :zero_spectre_mystic) && (axis_imag != :zero_spectre_mystic) && (axis_real != axis_imag) # || (axis != axis_real) ||
    [a0, a1, b0, b1, :spectre]
  elsif (w.real.uv.r.zero? && w.real.xy.s.zero? && w.imag.uv.s.zero? && w.imag.xy.r.zero?)
    b0 = ((w.imag.uv.r - w.real.uv.s) / 2.0).to_i
    b1 = w.real.uv.s.to_i
    a0 = ((w.real.xy.r - w.imag.xy.s) / 2.0).to_i
    a1 = w.imag.xy.s.to_i
    a_magnitude = a0.abs + a1.abs
    b_magnitude = b0.abs + b1.abs
    axis = (a_magnitude >= b_magnitude) ? :spectre : :mystic
    p ["invalid dominant axis: #{ [a0, a1, b0, b1, axis_real, axis]}"] if (axis_real != :zero_spectre_mystic) && (axis_imag != :zero_spectre_mystic) && (axis_real != axis_imag) # || (axis != axis_real) ||
    [a0, a1, b0, b1, :mystic]
  else
    [
      w.real.uv.r, w.real.uv.s, w.real.xy.r, w.real.xy.s,
      w.imag.uv.r, w.imag.uv.s, w.imag.xy.r, w.imag.xy.s,
      :unknown
    ]
  end
end

def from_coef(coef_array)
  # 入力チェック
  return ['Invalid input to from_coef', coef_array] unless coef_array.is_a?(Array) &&
         (coef_array.length == 4 || coef_array.length == 5) &&
         coef_array[0..3].all? { |x| x.is_a?(Numeric) }

  a0, a1, b0, b1 = coef_array[0..3]

  if coef_array.length == 4 || coef_array[4] == :spectre # Spectre系
    real_r = 2 * a0 + a1
    real_s = 0
    real_x = 0
    real_y = b1

    imag_r = 0
    imag_s = a1
    imag_x = 2 * b0 + b1
    imag_y = 0
  elsif coef_array[4] == :mystic
    # Mystic系：AとBの役割を入れ替える
    real_r = 2 * b0 + b1
    real_s = 0
    real_x = 0
    real_y = a1

    imag_r = 0
    imag_s = b1
    imag_x = 2 * a0 + a1
    imag_y = 0
  else
    return ['Invalid input to from_coef', coef_array]
  end

  Complex(
    MyNumeric2Coef.new(MyNumeric1Coef.new(real_r, real_s), MyNumeric1Coef.new(real_x, real_y)),
    MyNumeric2Coef.new(MyNumeric1Coef.new(imag_r, imag_s), MyNumeric1Coef.new(imag_x, imag_y))
  )
end
