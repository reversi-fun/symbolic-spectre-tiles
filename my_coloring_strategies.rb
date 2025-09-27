# coloring_strategies.rb
# Spectreタイルの色付けアルゴリズムを戦略として定義するファイル

# =============================================================================
# 1. 共通インターフェースの定義
# =============================================================================

# 各カラーリング戦略クラスが実装すべき共通のインターフェース
module ColoringStrategy
  # タイルの情報に基づいてRGBカラー配列 [r, g, b] を返す
  # @param transform [MatrixObject] タイルのアフィン変換オブジェクト
  # @param label [String] タイルのラベル名 (e.g., 'Delta', 'Gamma1')
  # @param parent_info [Array<String>] 親の階層情報
  # @return [Array<Integer>] RGB値の配列 [r, g, b]
  def get_color(transform:, label:, parent_info:)
    raise NotImplementedError, "#{self.class}##{__method__} が実装されていません"
  end

  # 内部状態を持つ戦略のために、描画開始前に状態をリセットする
  def reset
    # 状態を持たない戦略では、このメソッドは空でよい
  end

  def name
    self.class.name.gsub(/Strategy$/, '').gsub(/::/, '_')
  end
end


# =============================================================================
# 2. 具体的な戦略クラスの実装
# =============================================================================

# --- 戦略A: タイルのラベルに基づいて色を決定する ---
class ByLabelStrategy
  include ColoringStrategy

  # @param color_map [Hash] ラベル名をキー、RGB配列を値とするハッシュ
  def initialize(color_map)
    @color_map = color_map
  end

  def get_color(transform:, label:, parent_info:)
    @color_map[label] || [128, 128, 128] # 未定義の場合はグレー
  end
end


# --- 戦略B: タイルの最終的な回転角度に基づいて色を決定する ---
class ByAngleStrategy
  include ColoringStrategy

  # @param geometry_strategy [GeometryStrategy] 角度の計算に必要
  def initialize(geometry_strategy)
    @geometry_strategy = geometry_strategy
    @color_map = {
      -180 => [255, 0, 0],   -120 => [229, 0, 0],   -60 => [229, 102, 102],
      0    => [255, 0, 0],   60   => [102, 102, 229], 120 => [0, 204, 229],
      180  => [0, 0, 255]
    }
  end

  def get_color(transform:, label:, parent_info:)
    return [64, 64, 64] if label == 'Gamma2'

    angle, = @geometry_strategy.get_angle_from_transform(transform)
    @color_map[angle] || [128, 128, 128] # 未定義の場合はグレー
  end
end

# 戦略C: 親と子のラベルの組み合わせで色をブレンドする
# 戦略E: 親と子のラベルの組み合わせで、RGB値をビット単位で合成（OR演算）する
class ByParentChildBitwiseStrategy
  include ColoringStrategy

  # 自ラベル（子）に対する基本色（主に上位ビットを使用）
  # 発生頻度の低いTheta, Lambdaに純粋な原色を割り当てる
  CHILD_COLORS = {
    # 特別なグレースケール
    'Gamma1' => [224, 224, 224], # 0xE0E0E0
    'Gamma2' => [64, 64, 64],    # 0x404040
    # 発生頻度が最も低い => 明るい原色 (Red, Green)
    'Theta'  => [240, 0, 0],     # 0xF00000
    'Lambda' => [0, 240, 0],     # 0x00F000
    'Delta'  => [0, 0, 240],     # 0x0000F0
    # 比較的頻度が低い => 明るい原色 (Blue), 二次色 (Cyan, Magenta, Yellow)
    'Pi'     => [0, 240, 240],    # 0x00F0F0
    'Xi'     => [240, 0, 240],    # 0xF000F0
    'Psi'    => [240, 240, 0],    # 0xF0F000
    # 発生頻度が高い => やや落ち着いた三次色 (Orange, Purple)
    'Sigma'  => [240, 128, 0],   # 0xF08000
    'Phi'    => [128, 0, 240],   # 0x8000F0
  }.freeze

  # 親ラベルに対する調整色（主に下位ビットを使用）
  # 子の色に「ティント（色合い）」として加算される
  PARENT_COLORS = {
    'Gamma'  => [15, 15, 15],     # 0x0F0F0F (White tint)
    'Theta'  => [63, 0, 0],      # 0x3F0000 (Red tint)
    'Lambda' => [0, 63, 0],      # 0x003F00 (Green tint)
    'Delta'  => [0, 0, 63],      # 0x00003F (Blue tint)
    'Pi'     => [0, 63, 63],     # 0x003F3F (Cyan tint)
    'Xi'     => [63, 0, 63],     # 0x3F003F (Magenta tint)
    'Psi'    => [63, 63, 0],     # 0x3F3F00 (Yellow tint)
    'Sigma'  => [63, 31, 0],     # 0x3F1F00 (Orange tint)
    'Phi'    => [31, 0, 63],     # 0x1F003F (Purple tint)
  }.freeze

  DEFAULT_COLOR = [0, 0, 0].freeze # Black for errors

  def get_color(transform:, label:, parent_info:)
    child_color = CHILD_COLORS.fetch(label, DEFAULT_COLOR)

    # ルート直下の場合は子の色をそのまま使用
    return child_color if parent_info.empty?

    parent_label = parent_info.last

    # 親がGammaの場合、子のGamma1/Gamma2は色を変えない（構造を明確にするため）
    return child_color if parent_label == 'Gamma' && (label == 'Gamma1' || label == 'Gamma2')

    parent_color = PARENT_COLORS.fetch(parent_label, [0,0,0])

    # RGBの各成分をビット単位のOR演算で合成
    [
      child_color[0] | parent_color[0],
      child_color[1] | parent_color[1],
      child_color[2] | parent_color[2]
    ]
  end
end

class ClusterHueShiftStrategy
  include ColoringStrategy

  require 'matrix'

  # HSV → RGB 変換（0〜360のHue, 0〜1のSaturation/Value）
  def hsv_to_rgb(h, s, v)
    h = h % 360
    c = v * s
    x = c * (1 - ((h / 60.0) % 2 - 1).abs)
    m = v - c

    r, g, b = case h
              when 0...60 then [c, x, 0]
              when 60...120 then [x, c, 0]
              when 120...180 then [0, c, x]
              when 180...240 then [0, x, c]
              when 240...300 then [x, 0, c]
              else [c, 0, x]
              end

    [(r + m) * 255, (g + m) * 255, (b + m) * 255].map(&:to_i)
  end

  # 基本色（Hueベース、SaturationとValueは固定）
  BASE_HUES = {
    'Phi'    => 0,    # Red
    'Psi'    => 120,  # Green
    'Delta'  => 60,   # Yellow
    'Sigma'  => 180,  # Cyan
    'Pi'     => 300,  # Magenta
    'Xi'     => 30,   # Orange
    'Theta'  => 240,  # Blue
    'Lambda' => 270,  # Indigo
  }.freeze

  DEFAULT_COLOR = [0, 0, 0].freeze

  def get_color(transform:, label:, parent_info:)
    # Gamma系は固定グレースケール
    return [224, 224, 224] if label == 'Gamma1'
    return [64, 64, 64]   if label == 'Gamma2'

    base_hue = BASE_HUES.fetch(label, 0)
    depth = parent_info.length

    # クラスタ階層に応じてHueをずらす（15度ずつ回転）
    shifted_hue = base_hue + depth * 15

    # 彩度と明度は固定（見やすさ重視）
    hsv_to_rgb(shifted_hue, 0.8, 0.9)
  end
end

# --- 戦略D: 4色問題に基づいた複雑なアルゴリズムで色を決定する ---
class FourColorStrategy
  include ColoringStrategy

  COLOR_MAP = [[64, 64, 255], [255, 64, 64], [64, 255, 64], [220, 220, 64], [96, 96, 96], [255, 255, 255]]
  INDEX_2D = [[3, 2, 3, 1, 3, 1, 2, 1, 0]]
  SUBSTITUTION_LV = [
    [[0, 1, 2, 3], [0, 2, 1, 3], [0, 2, 1, 3], [0, 1, 2, 3], [0, 2, 1, 3], [0, 2, 1, 3], [0, 1, 2, 3], [0, 3, 1, 2]],
    [[0, 1, 2, 3], [0, 1, 3, 2], [0, 2, 1, 3], [0, 2, 3, 1], [0, 2, 1, 3], [0, 3, 2, 1], [0, 3, 1, 2], [0, 2, 3, 1]]
  ]

  def initialize
    reset
  end

  def reset
    @child_index = 0
    @parent_index_by_level = [0]
  end

  def get_color(transform:, label:, parent_info:)
    color_index_subst = INDEX_2D[0][@child_index]
    @parent_index_by_level.each_with_index do |place, level_no|
      color_index_subst = SUBSTITUTION_LV[level_no % 2][place][color_index_subst]
    end

    rgb = COLOR_MAP[color_index_subst]

    # 状態の更新
    @child_index += 1
    if (@child_index == 2) && (@parent_index_by_level[0] == 7) # Gammaタイルの特殊ルール
      @child_index += 1
    elsif @child_index >= (INDEX_2D[0].length)
      @child_index = 0
      carry = 1
      place_index = 0
      while (place_index < parent_info.length) && (carry > 0)
        @parent_index_by_level[place_index] = (@parent_index_by_level[place_index] || 0) + carry
        carry = 0
        if (@parent_index_by_level[place_index] == 2) && (@parent_index_by_level[place_index + 1] == 7)
          @parent_index_by_level[place_index] += 1
        elsif @parent_index_by_level[place_index] >= (SUBSTITUTION_LV[0].length)
          @parent_index_by_level[place_index] = 0
          carry = 1
        end
        place_index += 1
      end
    end

    return rgb
  end
end

class MonoChromeStrategy
  include ColoringStrategy

  def get_color(transform:, label:, parent_info:)
    case label
    when 'Gamma1'
      [127, 127, 127]  # グレー（ハッチング用）
    when 'Gamma2'
      [0, 0, 0]        # 黒
    else
      [255, 255, 255]  # 白（または塗りなし）
    end
  end
end
