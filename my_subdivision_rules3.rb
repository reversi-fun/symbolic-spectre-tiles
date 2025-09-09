# subdivision.rb
require 'matrix'
require './my_complex3.rb'
require './my_tiling_elements3.rb'

##
# 幾何学的変換（Affine Transform）を表現するクラス
# 回転と並進（translation）を保持
##
# 幾何学的変換（Affine Transform）を表現するクラス
# 回転と並進（translation）を保持
class AffineTransform
  attr_accessor :rotation, :translation

  # @param rotation [Integer] 60度単位の回転数
  # @param translation [MyComplex] 並進ベクトル
  def initialize(rotation, translation)
    @rotation = rotation % 6
    @translation = translation
  end

  # 別の変換を合成する
  def compose(other)
    # other の並進ベクトルを self の回転で回転させる
    rotated_translation = other.translation.rotate(self.rotation)

    # 変換を合成
    new_translation = self.translation + rotated_translation

    AffineTransform.new(@rotation + other.rotation, new_translation)
  end
end

##
# タイルを表現するクラス
class MyTile
  attr_reader :shape_type

  # @param shape_type [Symbol] タイルの種類 (例: :gamma, :delta)
  def initialize(shape_type)
    @shape_type = shape_type
  end
end

##
# タイルの置換ルールを定義し、再帰的に展開するアルゴリズム
class Subdivision

  RULES = {
    gamma: [
      { tile: :xi,    transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi,    transform: AffineTransform.new(1, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi,   transform: AffineTransform.new(2, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi,   transform: AffineTransform.new(3, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(4, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :xi,    transform: AffineTransform.new(5, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :theta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi,   transform: AffineTransform.new(1, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi,   transform: AffineTransform.new(2, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    delta: [
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    theta: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    lambda: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    xi: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    pi: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    sigma: [
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :xi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :lambda, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    phi: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :pi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ],
    psi: [
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :delta, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :sigma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :psi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :phi, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) },
      { tile: :gamma, transform: AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))) }
    ]
  }

  def self.subdivide(tile, transform, depth, &block)
    if depth == 0 || !RULES.key?(tile.shape_type)
      yield tile, transform
      return
    end

    rule = RULES[tile.shape_type]
    rule.each do |sub_rule|
      new_tile_type = sub_rule[:tile]
      new_transform = transform.compose(sub_rule[:transform])

      new_tile = MyTile.new(new_tile_type)

      subdivide(new_tile, new_transform, depth - 1, &block)
    end
  end

  def self.build_spectre_tiles(iterations, initial_tile)
    result_set = []
    initial_transform = AffineTransform.new(0, MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))))

    subdivide(initial_tile, initial_transform, iterations) do |tile, transform|
      result_set << { tile: tile, transform: transform }
    end

    result_set
  end
end

# # --- 使用例 ---
# puts "Spectreタイル生成アルゴリズムの実行"
# iterations = 2
# initial_tile = MyTile.new(:gamma)

# final_tiles = Subdivision.build_spectre_tiles(iterations, initial_tile)

# puts "\n生成されたタイルセット（#{iterations}回イテレーション後）:"
# puts "合計タイル数: #{final_tiles.size}\n\n"

# final_tiles.each_with_index do |item, i|
#   transform = item[:transform]
#   puts "タイル #{i+1}: タイプ=#{item[:tile].shape_type}, 回転=#{transform.rotation * 60}度, 並進ベクトル=#{transform.translation.to_s}"
# end
