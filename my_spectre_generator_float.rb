#!/usr/bin/ruby
# run_spectre_generator_float.rb
# Spectreタイリングを浮動小数点数計算戦略と角度によるカラーリング戦略を
# 用いて生成・描画する。

require './my_geometryStrategy_interface'

require './my_floatCoef_strategy'
require './my_coloring_strategies'
require './my_spectre_generator_generic'

# --- 設定 ---
N_ITERATIONS = 4
# EDGE_A = 10.0
# EDGE_B = 10.0
EDGE_A = 10.0 # 20.0 / (Math.sqrt(3) + 2.0)
EDGE_B = 10.0 # 20.0 - EDGE_A

# --- 1. 戦略とジェネレータの初期化 ---
start_time = Time.now

# 使用するジオメトリ戦略をインスタンス化
strategy = FloatStrategy.new
# ジェネレータに戦略を渡して初期化
generator = SpectreTilingGenerator.new(strategy, EDGE_A, EDGE_B)

# --- ★★★ カラーリング戦略の選択 ★★★ ---
# spectre-tiles_float.rb相当の「角度による色付け」戦略を選択
# color_strategy = ByAngleStrategy.new(strategy)
# 親と子のラベルの組み合わせで色をブレンドする
# color_strategy = ByParentChildBitwiseStrategy.new()
# color_strategy = ClusterHueShiftStrategy.new()
# color_strategy = FourColorStrategy.new
color_strategy = MonoChromeStrategy.new

# --- 2. タイリング生成の実行 ---
puts "* タイリング生成を開始します (N=#{N_ITERATIONS})"
generator.generate(N_ITERATIONS)
root_tile = generator.root_tile
puts "* タイル生成完了: #{Time.now - start_time}秒"

# --- 3. 描画領域とタイル数の計算 (第1パス) ---
# メモリを節約するため、タイル情報を配列に保存せず、都度計算します。
# このパスでは、全体の描画範囲と総タイル数を把握しますputs "* 描画領域とタイル数を計算中 (第1パス)..."
min_x, min_y = Float::INFINITY, Float::INFINITY
max_x, max_y = -Float::INFINITY, -Float::INFINITY
num_tiles = 0

root_tile.for_each_tile(strategy.identity_transform, []) do |transform, _, _|
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
# ファイル名にジオメトリ戦略とカラーリング戦略のクラス名を含める
svg_filename = "spectre-#{strategy.name}_#{color_strategy.name}_Tile-#{EDGE_A.truncate(1)}-#{EDGE_B.truncate(1)}-#{N_ITERATIONS}-#{num_tiles}tiles.svg"
puts "* SVGファイルを描画中 (第2パス): #{svg_filename}"
svg_time = Time.now

# 描画前にカラーリング戦略の状態をリセット
color_strategy.reset
spectre_points = strategy.define_spectre_points(EDGE_A, EDGE_B)
mystic_points = strategy.define_spectre_points(EDGE_B, EDGE_A) # strategy.define_mystic_points(spectre_points)

File.open(svg_filename, 'w') do |file|
  view_width = max_x - min_x - 1
  view_height = max_y - min_y - 1
  file.puts %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"\n width="#{view_width.to_i}" height="#{view_height.to_i}" viewBox="#{min_x.to_i} #{min_y.to_i} #{view_width.to_i} #{view_height.to_i}">)

  # 図形のパス定義
  path_d0 = spectre_points.map { |p| strategy.point_to_svg_coords(p).join(',') }.join(' L')
  path_d1 = mystic_points.map { |p| strategy.point_to_svg_coords(p).join(',') }.join(' L')
  file.puts '<defs>'
  file.puts %(<path id="d0" d="M#{path_d0} Z" stroke="gray" stroke-width="1.2"/>)
  file.puts %(<path id="d1" d="M#{path_d1} Z" stroke="gray" stroke-width="1.2"/>)
  if color_strategy.name == 'MonoChrome'
    # file.puts '<pattern id="hatch50" patternUnits="userSpaceOnUse" width="4" height="4">'
    # file.puts '  <path d="M0,0 l4,4" stroke="gray" stroke-width="1" />'
    # file.puts '</pattern>'
    file.puts '<pattern id="triangle60" patternUnits="userSpaceOnUse" width="4" height="7">' # さらに強い錯視を狙うなら、パターンのサイズを少し大きくして、視線が動く余地を作る
    file.puts '  <polygon points="2.0,3.2 3.9,0 0.1,0" fill="black"/>' # 中央の三角形の位置を少し下げて、接してないのに「つながって見える」錯視を強調。
    file.puts '  <polygon points="1.6,3.8 0,3.6 0,7" fill="black"/>' # 左右の三角形の角度や位置を微調整して、中央に向かう「仮想の線」が浮かび上がるように。
    file.puts '  <polygon points="2.4,3.8 4,3.6 4,7" fill="black"/>'
    file.puts '</pattern>'
  end
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
    stroke_color = (label == 'Gamma1' || label == 'Gamma2') ? 'black' : 'gray'
    stroke_width = (label == 'Gamma1' || label == 'Gamma2') ? '0.6' : '0.1'
    fill_opacity = ((color_strategy.name && label == 'Gamma2') && (label == 'Gamma1' || label == 'Gamma2')) ? '80%' : '57%'
    # file.puts '<circle cx="' + trsf[2].real.to_f.to_s + '" cy="' + trsf[2].imag.to_f.to_s +
    #             '" r="4" fill="' + (label == 'Gamma2' ? 'rgb(128,8,8)' : 'rgb(66,66,66)') + '" fill-opacity="90%" />'
    if color_strategy.name == 'MonoChrome'
      if label == 'Gamma1'  # ハッチング模様（SVGパターン参照）＋明灰色
        file.puts %(<use xlink:href="#d0" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="url(#triangle60)" fill-opacity="#{fill_opacity}" stroke="#{stroke_color}" stroke-width="#{stroke_width}" />)
      elsif label == 'Gamma2' # 黒で塗りつぶし
        file.puts %(<use xlink:href="#d1" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="rgb(#{color})" fill-opacity="#{fill_opacity}" stroke="#{stroke_color}" stroke-width="#{stroke_width}" />)
      else  # その他は（塗りつぶしなし）
        file.puts %(<use xlink:href="#d0" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="rgb(#{color})" fill-opacity="#{fill_opacity}" stroke="#{stroke_color}" stroke-width="#{stroke_width}" />)
      end
    else
     # file.puts %(<use xlink:href="#{label != 'Gamma2' ? '#d0' : '#d1'}" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="rgb(#{color})" fill-opacity="47%" stroke="black" stroke-weight="0.1" />)
        file.puts %(<use xlink:href="#{label != 'Gamma2' ? '#d0' : '#d1'}" x="0" y="0"  transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle}) scale(1,#{scale_y})" fill="rgb(#{color})" fill-opacity="#{fill_opacity}" stroke="#{stroke_color}" stroke-width="#{stroke_width}" />)
    end
    # file.puts %(<text x="#{EDGE_A}" y="#{EDGE_B * 0.5}" transform="translate(#{pos[0]},#{pos[1]}) rotate(#{angle - 15}) " font-size="8">#{tile_index + 1}</text>)
    tile_index += 1
  end
  file.puts '</svg>'
end
puts "* SVG描画完了: #{Time.now - svg_time}秒"

# puts "* coefファイルを出力中 "
# coef_time = Time.now
# root_tile.for_each_tile(strategy.identity_transform, [], root_tile) do |transform, label, parent_info, parent_tile, cur_tile|
#     angle,scale_y = strategy.get_angle_from_transform(transform)
#     p [cur_tile.id, label,angle,scale_y, transform[2], parent_tile.id, parent_tile.label, parent_info]
# end
# puts "* coef出力完了: #{Time.now - coef_time}秒"

puts "* 全処理時間: #{Time.now - start_time}秒"
