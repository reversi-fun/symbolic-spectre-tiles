#!/usr/bin/ruby
# run_spectre_generator_symbolic_fourcolor.rb
# Spectreタイリングをシンボリック計算戦略と4色カラーリング戦略を用いて生成・描画する

require './my_geometryStrategy_interface'
require './my_SymbolicCoef_strategy'
require './my_coloring_strategies'
require './my_spectre_generator_generic'

# --- 設定 ---
N_ITERATIONS = 4
EDGE_A = 20.0 / (Math.sqrt(3) + 2.0)
EDGE_B = 20.0 - EDGE_A

# --- 1. 戦略とジェネレータの初期化 ---
start_time = Time.now

# 使用するジオメトリ戦略をインスタンス化
strategy = SymbolicCoefStrategy.new
# ジェネレータに戦略を渡して初期化
generator = SpectreTilingGenerator.new(strategy, N_ITERATIONS, EDGE_A, EDGE_B)

# --- ★★★ カラーリング戦略の選択 ★★★ ---
# ここで使う戦略を切り替えることができます
# color_strategy = ByAngleStrategy.new(strategy)
# color_strategy = ByLabelStrategy.new({'Gamma1' => [255,0,0], 'Delta' => [0,255,0], ...})
color_strategy = FourColorStrategy.new


# --- 2. タイリング生成の実行 ---
puts "* タイリング生成を開始します (N=#{N_ITERATIONS})"
generator.generate
root_tile = generator.root_tile
puts "* タイル生成完了: #{Time.now - start_time}秒"

# --- 3. 描画領域とタイル数の計算 (第1パス) ---
# メモリを節約するため、タイル情報を配列に保存せず、都度計算します。
# このパスでは、全体の描画範囲と総タイル数を把握します。
puts "* 描画領域とタイル数を計算中 (第1パス)..."
min_x, min_y = Float::INFINITY, Float::INFINITY
max_x, max_y = -Float::INFINITY, -Float::INFINITY
num_tiles = 0

root_tile.for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
  coords = strategy.point_to_svg_coords(transform[2])
  min_x = [min_x, coords[0]].min
  min_y = [min_y, coords[1]].min
  max_x = [max_x, coords[0]].max
  max_y = [max_y, coords[1]].max
  num_tiles += 1
end

puts "* #{N_ITERATIONS}回の反復で #{num_tiles} 個のタイルを生成しました"

margin = EDGE_A * 3 + EDGE_B * 3
min_x -= margin; min_y -= margin
max_x += margin; max_y += margin

# --- 4. SVGファイルの描画 (第2パス) ---
svg_filename = svg_filename = "spectre-#{strategy.name}_#{color_strategy.name}_Tile-#{EDGE_A.truncate(1)}-#{EDGE_B.truncate(1)}-#{N_ITERATIONS}-#{num_tiles}tiles.svg"
puts "* SVGファイルを描画中 (第2パス): #{svg_filename}"
svg_time = Time.now

# 描画前にカラーリング戦略の状態をリセット
color_strategy.reset

File.open(svg_filename, 'w') do |file|
  view_width = max_x - min_x - 1
  view_height = max_y - min_y - 1
  file.puts %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"\n width="#{view_width.to_i}" height="#{view_height.to_i}" viewBox="#{min_x.to_i} #{min_y.to_i} #{view_width.to_i} #{view_height.to_i}">)

  # 図形のパス定義
  spectre_points = strategy.define_spectre_points(EDGE_A, EDGE_B)
  mystic_points = strategy.define_mystic_points(spectre_points)
  path_d0 = spectre_points.map { |p| strategy.point_to_svg_coords(p).join(',') }.join(' L')
  path_d1 = mystic_points.map { |p| strategy.point_to_svg_coords(p).join(',') }.join(' L')
  file.puts '<defs>'
  file.puts %(<path id="d0" d="M#{path_d0} Z" stroke="gray" stroke-width="1.2"/>)
  file.puts %(<path id="d1" d="M#{path_d1} Z" stroke="gray" stroke-width="1.2"/>)
  file.puts '</defs>'

  # ルートタイルのquad特徴点を描画
  root_tile.quad.each_with_index do |quad1, _i|
    file.puts "<rect x=\"#{quad1.real.to_f}\" y=\"#{quad1.imag.to_f}\"" +
              " width=\"#{(EDGE_A + EDGE_B) / 1.1}\" height=\"#{(EDGE_A + EDGE_B) / 1.1}\"" +
              ' r="8" fill="rgb(0,222,0)" fill-opacity="90%" />'
  end

  # 各タイルの描画
  scale_y = N_ITERATIONS.even? ? 1 : -1
  tile_index = 0
  root_tile.for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
    trsf = transform

    angle, = strategy.get_angle_from_transform(trsf)
    pos = strategy.point_to_svg_coords(trsf[2])

    # 戦略オブジェクトから色を取得
    color_array = color_strategy.get_color(transform: trsf, label: label, parent_info: parent_info)
    color = color_array.join(',')

    file.puts %(<use xlink:href="#{label != 'Gamma2' ? '#d0' : '#d1'}" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="rgb(#{color})" fill-opacity="47%" stroke="black" stroke-weight="0.1" />)
    # file.puts %(<text x="#{EDGE_A}" y="#{EDGE_B * 0.5}" transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle - 15}) " font-size="8">#{tile_index + 1}</text>)
    tile_index += 1
  end
  file.puts '</svg>'
end
puts "* SVG描画完了: #{Time.now - svg_time}秒"

# --- 5. CSVファイルの出力 (第3パス) ---
csv_filename = svg_filename + '.csv'
puts "* CSVファイルを出力中 (第3パス): #{csv_filename}"
csv_time = Time.now

# CSV出力
File.open(csv_filename, 'w', encoding: 'UTF-8') do |file|
  file.puts "\uFEFF" + "label,\"transform  {A:#{EDGE_A}, B:#{EDGE_B}}\",angle,transform[0].x,transform[0].y,transform[1].x,transform[1].y,transform[2].x,transform[2].y,pt0-coef:a0,a1,b0,b1"
  root_tile.for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
    trsf = transform
    angle, = strategy.get_angle_from_transform(trsf)
    pos = strategy.point_to_svg_coords(trsf[2])
    trsf0 = strategy.point_to_svg_coords(trsf[0])
    trsf1 = strategy.point_to_svg_coords(trsf[1])

    file.puts "\"#{label}\",\"#{trsf[2]}\",#{angle},#{trsf0[0]},#{trsf0[1]},#{trsf1[0]},#{trsf1[1]},#{pos[0]},#{pos[1]}, #{to_coef(trsf[2]).join(', ')}"
  end
end
puts "* CSV出力完了: #{Time.now - csv_time}秒"

coef_filename = svg_filename + '.coef'
puts "* coefファイルを出力中 (第3パス): #{coef_filename}"
coef_time = Time.now

  root_tile.for_each_tile(strategy.identity_transform, [], root_tile) do |transform, label, parent_info, parent_tile, cur_tile|
    trsf = transform
    angle, = strategy.get_angle_from_transform(trsf)
    coef = to_coef(trsf[2])
    p [cur_tile.id, label,angle, coef, parent_tile.id, parent_tile.label, parent_info]
    # file.puts "#{tile_index},\"#{label}\",\"#{trsf[2]}\",#{angle},#{trsf0[0]},#{trsf0[1]},#{trsf1[0]},#{trsf1[1]},#{pos[0]},#{pos[1]}, #{coef.join(', ')}"
  end
puts "* coef出力完了: #{Time.now - coef_time}秒"

puts "* 全処理時間: #{Time.now - start_time}秒"
