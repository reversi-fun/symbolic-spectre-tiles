# Symbolic Computation, Computer Algebra System
# require 'mathn'

class MyNumericBase < Numeric
  CONST_EPSILON = Math.sqrt(Float::EPSILON)
  HALF = 0.5
  SQRT3_HALF = Math.sqrt(3) / 2
end

class MyNumericCoef < MyNumericBase
  attr_accessor :r, :s, :c

  def initialize(r, s, c)
    @r, @s, @c = r, s, c
  end

  def to_f
    (@r * @c * HALF) + (@s * @c * SQRT3_HALF)
  end

  def +(other)
    case other
    when Integer
      MyNumericCoef.new(@r + other, @s, @c)
    when MyNumericCoef
      raise_invalid_argument('+', other) unless @c == other.c
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
      @c == 1 ? MyNumeric1Coef.new(@r * other, @s * other) : MyNumericCoef.new(@r * other, @s * other, @c)
    when MyNumeric2Coef
      return other * self if @c == 1
    when MyNumericCoef
      return raise_invalid_argument('*', other) unless (@c == 1) || (other.c == 1)
      u = ((@r * other.r) + (3 * (@s * other.s))) / 2.0
      v = ((@r * other.s) + (@s * other.r)) / 2.0
      c = @c * other.c
      c == 1 ? MyNumeric1Coef.new(u, v) : MyNumericCoef.new(u, v, c)
    else
      raise_invalid_argument('*', other)
    end
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
    [self, other] if other.is_a?(Integer)
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
    else
      raise_invalid_argument('*', other)
    end
  end

  def coerce(other)
    [other, self] if other.is_a?(Integer) || other.is_a?(MyNumeric1Coef)
    [self, other] if other.is_a?(Integer) || other.is_a?(MyNumeric1Coef)
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

  def check_consistency
    result = ((to_f - eval(to_s.gsub('A', "#{@@A}").gsub('B', "#{@@B}").gsub('√3', "#{Math.sqrt(3)}")).abs) < CONST_EPSILON)
    unless result
      p ['check_consistency failed', to_f, eval(to_s.gsub('A', "#{@@A}").gsub('B', "#{@@B}").gsub('√3', "#{Math.sqrt(3)}"))]
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

  real, imag = w.real, w.imag

  # Check if the required components are zero
  return ['inValid coef', [
    real.uv.r, real.uv.s, real.xy.r, real.xy.s,
    imag.uv.r, imag.uv.s, imag.xy.r, imag.xy.s
  ]] unless real.uv.s.zero? && real.xy.r.zero? &&
               imag.uv.r.zero? && imag.xy.s.zero?

  # Calculate coefficients only if all conditions are met
  [
    ((real.uv.r - imag.uv.s) / 2.0).to_i, # First coefficient of Edge_a
    imag.uv.s.to_i,                        # Second coefficient of Edge_a
    ((imag.xy.r - real.xy.s) / 2.0).to_i, # First coefficient of Edge_b
    real.xy.s.to_i                         # Second coefficient of Edge_b
  ]
end
