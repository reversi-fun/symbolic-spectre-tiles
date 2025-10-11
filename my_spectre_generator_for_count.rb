#!/usr/bin/ruby
# my_spectre_generator_for_count.rb

require './my_geometryStrategy_interface'

class CountPoint
  def -(other)
     self
  end
  # def to_s; self.class.name; end
end

# --- CountTransform: ダミー変換 ---
class CountTransform
  # ダミーの移動ベクトル（SpectreTilingGeneratorの要求を満たすため）
  # 内部でCountPointのダミーインスタンスを保持
  @@dummy_point = CountPoint.new
  # 新しいコードが参照する to_point メソッド
  def to_point
    @@dummy_point
  end
end

# --- SpectreTilingGeneratorの初期化要求を満たすダミーメソッド ---
class CountStrategy
  include GeometryStrategy
  @@dummy_transform = CountTransform.new

  # --- 幾何学データはすべてダミー値を返す ---
  def define_spectre_points(_a, _b)
    [CountPoint.new] * 14
  end
  def transform_point(transform, point)
    CountPoint.new
  end

  # 幾何学的変換は行わないため、常に同じダミー変換を返す
  def identity_transform; @dummy_transform; end
  def rotation_transform(_angle_deg); @dummy_transform; end
  def create_transform(_angle_deg, _move_point, _scale_y = 1); @dummy_transform; end
  def reflect_transform(transform); transform; end
  def compose_transforms(trans_a, trans_b); @dummy_transform; end
end


if __FILE__ == $0
  # --- Configuration ---
  N_ITERATIONS = 8 # 最大世代数。　8世代位までが、待ち切れる限界。
  # end of Configuration ---

  require './my_spectre_generator_generic'
  # 回転戦略インスタンス
  start_time = Time.now
  strategy = CountStrategy.new
  # 生成器インスタンス
  generator = SpectreTilingGenerator.new(strategy, 1, 1)
  # タイリングの生成
  generator.generate(N_ITERATIONS) do |n, tiles|
    current_counts = Hash.new(0)
    if n == 0
      current_counts['Delta'] = 1
    else
      tiles['Delta'].for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
        current_counts[label] += 1
      end
    end
    current_counts['_Total'] = current_counts.values.reduce(:+)
    p [n, current_counts]
  end
  puts "* spectre tile count end: #{Time.now - start_time}秒"
end
