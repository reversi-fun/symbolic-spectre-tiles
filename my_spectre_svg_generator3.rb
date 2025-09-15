# spectre_svg_generator.rb
# SpectreタイルのSVG描画コード

## configlation
# * increase this number for larger tilings.
N_ITERATIONS = 3
# * shape Edge_ration tile(Edge_a, Edge_b)
Edge_a = 20.0 / (Math.sqrt(3) + 2.0)
Edge_b = 20.0 - Edge_a
## end of configilation.

require './myComplex2Coef.rb'
require './my_complex3.rb'
require './my_tiling_elements3.rb'
require './my_subdivision_rules3.rb'


MyNumeric2Coef.A = Edge_a
MyNumeric2Coef.B = Edge_b

# --- 各タイルの頂点座標を定義 ---
# これらの座標は、PDFの図から相対的な位置関係を推定したものです。
# AとBは辺の長さ（my_complex.rbで定義済み）
# 各頂点は MyComplex オブジェクトで表現されます。
TILE_VERTICES = {
  gamma: [
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))), # pt(0, 0), // 1: -b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))), # pt(a, 0.0), // 2:  + a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(0, 0))), # pt(a + a_d2, 0 - a_sqrt3_d2), // 3: + ~a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0))), # pt(a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b_d2), // 4: + ~b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))), # pt(a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b + b_d2), // 5: + b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))), # # pt(a + a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b + b_d2), // 6: + a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), # pt(a + a + a + b_sqrt3_d2, b + b_d2), // 7: + ~a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(4, 0))), # pt(a + a + a, b + b),// 8: (3.0, 2.0), // 8: -~b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), # pt(a + a + a - b_sqrt3_d2, b + b - b_d2), // 9: -~b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), # pt(a + a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 10: +~b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), # pt(a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 11: -b
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), #    pt(a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 12: -a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), #    pt(0 - b_sqrt3_d2, b + b - b_d2), // 13: -a
      MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0))) #    pt(0.0, b) // +b
  ],
  # delta: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ],
  # theta: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))
  # ],
  # lambda: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ],
  # xi: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(2,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)))
  # ],
  # pi: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ],
  # sigma: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ],
  # phi: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ],
  # psi: [
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0,0), MyNumeric1Coef.new(0,0))),
  #   MyComplex.new(MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)), MyNumeric2Coef.new(MyNumeric1Coef.new(2,0), MyNumeric1Coef.new(0,0)))
  # ]
}

# SpectreタイルのSVGを生成する関数
# @param iterations [Integer] 置換の反復回数
# @param initial_tile_type [Symbol] 最初のタイルの種類
def generate_spectre_svg(iterations, initial_tile_type)
  start_time = Time.now

  initial_tile = MyTile.new(initial_tile_type)
  final_tiles = Subdivision.build_spectre_tiles(iterations, initial_tile)
  num_tiles = final_tiles.size

  puts "* #{iterations} Iterations, generated #{num_tiles} tiles"
  puts "buildSpectreTiles process #{Time.now - start_time}sec."

  min_x, max_x, min_y, max_y = Float::INFINITY, -Float::INFINITY, Float::INFINITY, -Float::INFINITY

  final_tiles.each do |item|
    tile_type = item[:tile].shape_type
    transform = item[:transform]

    if TILE_VERTICES.key?(tile_type)
      TILE_VERTICES[tile_type].each do |vertex|
        # 頂点に変換を適用
        rotated_point = vertex.rotate(transform.rotation)
        transformed_point = rotated_point + transform.translation

        x = transformed_point.real.to_f
        y = transformed_point.imag.to_f

        min_x = [min_x, x].min
        max_x = [max_x, x].max
        min_y = [min_y, y].min
        max_y = [max_y, y].max
      end
    end
  end

  svg_file_name = "spectre-tile-subst-#{iterations}-#{num_tiles}tiles.svg"

  File.open(svg_file_name, 'w') do |file|
    view_width = max_x - min_x
    view_height = max_y - min_y

    file.puts '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'
    file.puts " width=\"#{view_width}\" height=\"#{view_height}\" viewBox=\"#{min_x} #{min_y} #{view_width} #{view_height}\">"
    file.puts '<defs>'

    TILE_VERTICES.each do |type, vertices|
      path_data = vertices.map do |vertex|
        "#{vertex.real.to_f},#{vertex.imag.to_f}"
      end.join(' L')
      file.puts "<path id=\"#{type}\" d=\"M#{path_data} Z\" stroke=\"black\" stroke-width=\"0.5\"/>"
    end

    file.puts '</defs>'

    final_tiles.each_with_index do |item, i|
      tile_type = item[:tile].shape_type
      transform = item[:transform]

      translate_x = transform.translation.real.to_f
      translate_y = transform.translation.imag.to_f
      rotate_deg = transform.rotation * 60

      file.puts "<use xlink:href=\"##{tile_type}\" " +
                "transform=\"translate(#{translate_x}, #{translate_y}) rotate(#{rotate_deg})\" " +
                "fill=\"hsl(#{(i*20) % 360}, 70%, 50%)\" fill-opacity=\"0.7\" />"
    end

    file.puts '</svg>'
  end

  puts "SVGファイル生成プロセス #{Time.now - start_time}sec"
  puts "保存先ファイル名: #{svg_file_name}"
end

#################################################################

# --- 実行例 ---
# イテレーション回数を指定して実行
generate_spectre_svg(N_ITERATIONS, :gamma)
