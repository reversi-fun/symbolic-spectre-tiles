# my_complex.rb

require 'complex' # Ruby標準のComplexモジュールをインポート
# MyNumeric2Coef.rb は外部で定義されていると仮定（r, s, c係数を持つシンボリックな数値）

# 辺の変位に関連する定数（タイリングのスケールに依存）
# aとbはタイルの2種類の辺の長さ（Spectreでは a/b = 1）[cite: 87]
# 実際のSpectreの座標計算では、aとbの値自体もシンボリックに扱うことが望ましい。
# 例として、ここでは単に「係数」として参照する。

# MyNumeric2Coef がすでに定義されていると仮定し、そのインスタンスを実部・虚部として使用

# シンボリックな複素数クラス
class MyComplex
  attr_accessor :real, :imag

  def initialize(real, imag)
    unless real.is_a?(MyNumeric2Coef) && imag.is_a?(MyNumeric2Coef)
      raise ArgumentError, "実部と虚部は MyNumeric2Coef のインスタンスでなければなりません"
    end
    @real = real
    @imag = imag
  end

  # MyComplex と MyComplex の加算
  def +(other)
    unless other.is_a?(MyComplex)
      raise TypeError, "MyComplex + #{other.class} はサポートされていません"
    end
    MyComplex.new(@real + other.real, @imag + other.imag)
  end

  # MyComplex と MyComplex の減算
  def -(other)
    unless other.is_a?(MyComplex)
      raise TypeError, "MyComplex - #{other.class} はサポートされていません"
    end
    MyComplex.new(@real - other.real, @imag - other.imag)
  end

  # MyComplex と MyComplex の乗算
  def *(other)
    unless other.is_a?(MyComplex)
      raise TypeError, "MyComplex * #{other.class} はサポートされていません"
    end
    new_real = (@real * other.real) - (@imag * other.imag)
    new_imag = (@real * other.imag) + (@imag * other.real)
    MyComplex.new(new_real, new_imag)
  end

  # 60度単位の回転を適用するメソッド
  # 事前定義された定数配列から回転複素数を取得
  def rotate(m)
    rotation_complex = ROT_60_DEG[m % 6]
    # 計算結果を MyComplex の新しいインスタンスとして返す
    MyComplex.new(self.real * rotation_complex.real - self.imag * rotation_complex.imag,
                  self.real * rotation_complex.imag + self.imag * rotation_complex.real )
  end

  # 最終的な浮動小数点数に変換する
  def to_f
    to_c.to_f
  end

  # 標準の Complex に変換する
  def to_c
    Complex(@real.to_f, @imag.to_f)
  end

  def to_s
    "#{@real.to_s} + #{@imag.to_s}i"
  end

  def inspect
    "MyComplex(#{@real.inspect}, #{@imag.inspect})"
  end
end


# 浮動小数点数を使わず、係数を直接指定
  ROT_60_DEG = [
    # 0度: 1 + 0i
    Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)),
    # 60度: 1/2 + i*sqrt(3)/2
    Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)),
    # 120度: -1/2 + i*sqrt(3)/2
    Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)),
    # 180度: -1 + 0i
    Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)),
    # 240度: -1/2 - i*sqrt(3)/2
    Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)),
    # 300度: 1/2 - i*sqrt(3)/2
    Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1))
  ]

# 注釈:
# MyNumeric2Coef クラスの乗算 (*) は、すでに MyNumeric1Coef や Integer との乗算時に
# 浮動小数点演算 ( / 2.0 や * HALF) を使用しているため、厳密な整数演算構成にはなっていません。
# この MyComplex クラスは、その既存の MyNumeric2Coef の振る舞いを引き継ぎます。
# 厳密な整数演算を実現するには、MyNumeric2Coef クラスの乗算を修正し、
# 係数を有理数または整数ベクトル（シンボリックな基底、例: 1 と sqrt(3)）として保持する必要があります。
