# spectre_generator.rb
# 計算方法に依存しない、汎用的なSpectreタイリング生成クラス

# --- 再帰的なデータ構造：TileとMetaTile ---
# これらのクラスは、計算戦略(strategy)を渡されることで、
# 具体的な数値型に依存しない振る舞いをします。

class Tile
  attr_reader :label, :quad, :id
  @@id_counter = 1

  def initialize(label, initial_quad)
    @label = label
    @quad = initial_quad.dup
    @id = @@id_counter
    @@id_counter += 1
  end

  def for_each_tile(tile_transformation, parent_info = [], parent_tile = nil, &drawer)
    drawer.call(tile_transformation, @label, parent_info, parent_tile, self)
  end
end

class MetaTile
  attr_reader :label, :quad, :tiles, :transformations, :id
  @@id_counter = -1

  def initialize(label, tiles, transformations, quad, strategy)
    @label = label
    @tiles = tiles
    @transformations = transformations
    @quad = quad
    @strategy = strategy # 変換の合成にstrategyオブジェクトを使用
    @id = @@id_counter
    @@id_counter -= 1
  end

  def for_each_tile(transformation, parent_info = [], parent_tile = nil, &drawer)
    # 'Gamma'タイルは特別なクラスタ情報を持ちます
    cluster_info = (@label == 'Gamma' && @tiles[0]&.label == 'Gamma1') ? parent_info : (parent_info + [@label])

    @tiles.zip(@transformations).each do |tile, trsf|
      # 変換の合成には、strategyのメソッドを使用
      combined_transform = @strategy.compose_transforms(transformation, trsf)
      tile.for_each_tile(combined_transform, cluster_info, self, &drawer)
    end
  end
end


# --- タイリング生成の本体 ---

class SpectreTilingGenerator
  TILE_NAMES = %w[Gamma Delta Theta Lambda Xi Pi Sigma Phi Psi].freeze

  # 置換規則の定義
  SUBSTITUTION_RULES = [
    ['Gamma', ['Pi', 'Delta', nil, 'Theta', 'Sigma', 'Xi', 'Phi', 'Gamma']],
    ['Delta',  %w[Xi Delta Xi Phi Sigma Pi Phi Gamma]],
    ['Theta',  %w[Psi Delta Pi Phi Sigma Pi Phi Gamma]],
    ['Lambda', %w[Psi Delta Xi Phi Sigma Pi Phi Gamma]],
    ['Xi',     %w[Psi Delta Pi Phi Sigma Psi Phi Gamma]],
    ['Pi',     %w[Psi Delta Xi Phi Sigma Psi Phi Gamma]],
    ['Sigma',  %w[Xi Delta Xi Phi Sigma Pi Lambda Gamma]],
    ['Phi',    %w[Psi Delta Psi Phi Sigma Pi Phi Gamma]],
    ['Psi',    %w[Psi Delta Psi Phi Sigma Psi Phi Gamma]]
  ].freeze

  attr_reader :root_tile

  # 初期化時に、使用する計算戦略(strategy)を受け取ります
  def initialize(strategy, edge_a, edge_b)
    @strategy = strategy
    @edge_a = edge_a
    @edge_b = edge_b

    # 必要な初期値を戦略オブジェクトから取得します
    @spectre_points = @strategy.define_spectre_points(@edge_a, @edge_b)
    @spectre_quad = [3, 5, 7, 11].map { |idx| @spectre_points[idx].dup }
    @identity = @strategy.identity_transform
    # @reflection = @strategy.reflection_transform
    @root_tile = nil
  end

  # タイリング生成のメインプロセス
  def generate(iterations)
    tiles = build_spectre_base
    # tiles.each do |label, meta_tile|
    #     p ["* base tile",0, meta_tile.id, meta_tile.class.name, meta_tile.label, meta_tile.quad.map{|e| e.to_s}]
    # end

    puts "a_quad_coef = []"
    puts "a_transformations_coef = []"
    puts "a_super_quad_coef = []"

    iterations.times do |i|
      tiles = build_supertiles(tiles)
      # tiles.each do |label, meta_tile|
      #   p ["****tile",i+1, meta_tile.id, meta_tile.class.name, meta_tile.label, meta_tile.quad.map{|e| e.to_s}]
      #   p ["****sub_tiles\t"]
      #   meta_tile.tiles.zip(meta_tile.transformations).each do |tile, trsf|
      #      p [i+1,tile.id, tile.class.name, tile.label, [" transform angle & moveTo", @strategy.get_angle_from_transform(trsf)[0], trsf[2].to_s],
      #         "4 quad Points",tile.quad.map{|e| (e).to_s},
      #         "transformed 4 quad Points", tile.quad.map{|e| @strategy.transform_point(trsf,e).to_s}
      #       ]
      #   end
      # end
    end
    @root_tile = tiles['Delta'] # 最終的なルートタイルを設定
    return self
  end

  private

  # 最初の世代のタイル群を生成します
  def build_spectre_base
    tiles = {}
    TILE_NAMES.each do |label|
      tiles[label] = if label == 'Gamma'
        # GammaタイルはGamma1とGamma2から構成されるMetaTileです
        gamma2_transform = @strategy.create_transform(30, @spectre_points[8]) # 回転30度
         # @strategy.compose_transforms([@identity [0], @identity [1], @spectre_points[8]], @strategy.rotation_transform(30) ) # 回転
        MetaTile.new('Gamma',
          [Tile.new('Gamma1', @spectre_quad), Tile.new('Gamma2', @spectre_quad)],
          [@identity, gamma2_transform],
          @spectre_quad,
          @strategy)
      else
        Tile.new(label, @spectre_quad)
      end
    end
    tiles
  end

  # スーパータイルを構築する再帰的なステップです
  def build_supertiles(input_tiles)
    quad = input_tiles['Delta'].quad
    total_angle = 0

    rotation = @strategy.rotation_transform(total_angle)
    transformations = [rotation]
    transformed_quad = quad.dup

    # スーパータイル内の各タイルの配置を計算します
    [[60, 3, 1], [0, 2, 0], [60, 3, 1], [60, 3, 1], [0, 2, 0], [60, 3, 1], [-120, 3, 3]].each do |angle, from, to|
      if angle != 0
        total_angle += angle
        rotation = @strategy.rotation_transform(total_angle)
        transformed_quad = quad.map { |q| @strategy.transform_point(rotation, q) }
      end

      move_vec = @strategy.transform_point(transformations.last, quad[from]) - transformed_quad[to]
      translation = @strategy.create_transform(total_angle, move_vec) # [@identity [0], @identity [1], move_vec]

      transformations << translation # @strategy.compose_transforms(translation, rotation)

      # coef = @strategy.to_internal_coefficients(transformations.last[2])
      # delta = @strategy.to_internal_coefficients(transformations.last[2] - quad[from])
      # angle_deg = @strategy.get_angle_from_transform(transformations.last)[0]
      # puts "# a_trsf = [#{angle_deg}, #{coef.inspect}]"
      # puts "# a_translation - quad[#{from}] = #{delta.inspect}"
    end

    puts "# a_transformations = #{transformations.map { |e| [@strategy.get_angle_from_transform(e)[0], @strategy.to_internal_coefficients(e)] }.inspect}"
    # Y軸反転を適用します
    # transformations.map! { |trsf| @strategy.compose_transforms(@reflection, trsf) }
    transformations.map! { |trsf| @strategy.reflect_transform(trsf) }


    # 新しいスーパータイルの頂点座標を計算します
    super_quad = [
      @strategy.transform_point(transformations[6], quad[2]),
      @strategy.transform_point(transformations[5], quad[1]),
      @strategy.transform_point(transformations[3], quad[2]),
      @strategy.transform_point(transformations[0], quad[1])
    ]

    puts "a_quad_coef << #{quad.map { |e| @strategy.to_internal_coefficients(e) }.inspect}"
    puts "a_transformations_coef << #{transformations.map { |e| [@strategy.get_angle_from_transform(e)[0], @strategy.to_internal_coefficients(e)] }.inspect}"
    puts "a_super_quad_coef << #{super_quad.map { |e| @strategy.to_internal_coefficients(e) }.inspect}"

    # 置換規則に基づいて新しいMetaTileを生成します
    tiles = {}
    SUBSTITUTION_RULES.each do |label, substitutions|
      sub_tiles = substitutions.compact.map { |sub_label| input_tiles[sub_label] }
      sub_transforms = substitutions.zip(transformations).select { |s, _| s }.map { |_, t| t }

      tiles[label] = MetaTile.new(label, sub_tiles, sub_transforms, super_quad, @strategy)
    end
    tiles
  end
end
