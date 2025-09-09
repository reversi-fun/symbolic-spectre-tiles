# my_tiling_elements.rb

# 前のステップで定義された MyComplex クラスを読み込む
require './my_complex3.rb'

# 辺の種類を定数として定義
module EdgeType
  ALPHA = :alpha
  BETA  = :beta
  GAMMA = :gamma
  DELTA = :delta
  EPSILON = :epsilon
  ZETA  = :zeta
  THETA = :theta
  ETA   = :eta
end

# 頂点の種類を定数として定義
module VertexType
  P = :p
  Q = :q
  S = :s
end

##
# 辺（Edge）を表現するクラス
# 辺の種類と向き（回転）を保持
class MyEdge
  attr_accessor :type, :rotation, :direction

  # @param type [Symbol] 辺の種類 (例: EdgeType::ALPHA)
  # @param rotation [Integer] 60度回転の回数 (r^m)
  # @param direction [Integer] 向き (+1 or -1)
  def initialize(type, rotation, direction = 1)
    @type = type
    @rotation = rotation % 6
    @direction = direction
  end

  # r^m をかける操作
  def rotate(m)
    MyEdge.new(@type, @rotation + m, @direction)
  end

  def inspect
    "MyEdge(type: #{@type}, rotation: r^#{@rotation}, direction: #{@direction})"
  end

  # == と hash を定義して、集合やハッシュのキーとして使えるようにする
  def ==(other)
    other.is_a?(MyEdge) && @type == other.type && @rotation == other.rotation && @direction == other.direction
  end

  def hash
    [@type, @rotation, @direction].hash
  end
  alias_method :eql?, :==
end

##
# 頂点（Vertex）を表現するクラス
# 頂点の種類と向き（回転）を保持
class MyVertex
  attr_accessor :type, :rotation

  # @param type [Symbol] 頂点種類 (例: VertexType::P)
  # @param rotation [Integer] 60度回転の回数
  def initialize(type, rotation)
    @type = type
    @rotation = rotation % 6
  end

  def rotate(m)
    MyVertex.new(@type, @rotation + m)
  end

  def inspect
    "MyVertex(type: #{@type}, rotation: r^#{@rotation})"
  end
end

##
# 面（Face）/ メタタイルを表現するクラス
# 辺と頂点のリストを保持
class MyFace
  attr_accessor :shape_type, :edges, :vertices

  # @param shape_type [Symbol] タイルの種類 (例: :gamma, :delta)
  # @param edges [Array<MyEdge>] 辺のリスト
  # @param vertices [Array<MyVertex>] 頂点のリスト
  def initialize(shape_type, edges, vertices)
    @shape_type = shape_type
    @edges = edges
    @vertices = vertices
  end

  # 指定された回転数で面全体を回転させる
  def rotate(m)
    rotated_edges = @edges.map { |e| e.rotate(m) }
    rotated_vertices = @vertices.map { |v| v.rotate(m) }
    MyFace.new(@shape_type, rotated_edges, rotated_vertices)
  end

  def inspect
    "MyFace(type: #{@shape_type}, edges: ..., vertices: ...)"
  end
end
