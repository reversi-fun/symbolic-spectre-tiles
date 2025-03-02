#!/usr/bin/ruby
require 'matrix'
require 'complex'

## configlation
# * increase this number for larger tilings.
N_ITERATIONS = 3
# * shape Edge_ration tile(Edge_a, Edge_b)
Edge_a = 10.0 # 20.0 / (Math.sqrt(3) + 1.0)
Edge_b = 10.0 # 20.0 - Edge_a
## end of configilation.

def get_spectre_points(edge_a, edge_b)
  a = edge_a
  a_sqrt3_d2 = a * Math.sqrt(3) / 2 # a*sin(60 deg)
  a_d2 = a * 0.5 # a* cos(60 deg)

  b = edge_b
  b_sqrt3_d2 = b * Math.sqrt(3) / 2 # b*sin(60 deg)
  b_d2 = b * 0.5 # b* cos(60 deg)

  Vector[
      Complex(0, 0), # // 1: - b
      Complex(a, 0), # // 2: + a
      Complex(a +     a_d2, 0 - a_sqrt3_d2), # // 3: + ~a
      Complex(a +     a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +         b_d2), # // 4: + ~b
      Complex(a +     a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +     b + b_d2), # // 5: + b
      Complex(a + a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +     b + b_d2), # // 6: + a
      Complex(a + a + a +    b_sqrt3_d2,                      b + b_d2), # // 7: + ~a
      Complex(a + a + a, b + b), # // 8: - ~b
      Complex(a + a + a    - b_sqrt3_d2,                  b + b - b_d2), # // 9: - ~b
      Complex(a + a + a_d2 - b_sqrt3_d2,     a_sqrt3_d2 + b + b - b_d2), # // 10: +~a
      Complex(a +     a_d2 - b_sqrt3_d2,     a_sqrt3_d2 + b + b - b_d2), # // 11: -a
      Complex(a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), # // 12: -a
      Complex(0 - b_sqrt3_d2, b + b - b_d2), # // 13: -~a
      Complex(0, b) # // 14: +~b
  ]
  # p spectre_points
end

SPECTRE_POINTS = get_spectre_points(Edge_a, Edge_b) # tile(Edge_a, Edge_b)
NoMovePoint = SPECTRE_POINTS[0].dup
SPECTRE_QUAD = [3, 5, 7, 11].map { |idx| SPECTRE_POINTS[idx] }
Mystic_SPECTRE_POINTS = get_spectre_points(Edge_b, Edge_a) # tile(Edge_b, Edge_a)

print("coef A = #{Edge_a}\t\tRatio(#{(Edge_a / (Edge_a + Edge_b)).round(4)})\n")
print("coef B = #{Edge_b}\t\tRatio(#{(Edge_b / (Edge_a + Edge_b)).round(4)})\n")
[['SPECTRE_POINTS =', SPECTRE_POINTS], ['Mystic_SPECTRE_POINTS =', Mystic_SPECTRE_POINTS]].each do |vName, v|
  print("#{vName} [\n")
  v.each { |c| print("\t\t\t(#{c.real.to_f.round(4)} + #{c.imag.to_f.round(4)}*i),\n") }
  print("]\n")
end



# Rotation matrix for Affine transform
# pre-computed rotation matrices for common angles in the Trot_memo hash,
# to avoid recomputing them. The trot function looks up or computes the rotation matrix for a given angle.
Trot_memo = {
  #  -30=> [Complex(Math.sqrt(3)/2, 0.5),   Complex(-0.5, Math.sqrt(3)/2 ), Complex(0.0)],
  0 => [Complex(1, 0), Complex(0, 1), NoMovePoint],
  30 => [Complex(Math.sqrt(3) / 2, 0.5),   Complex(-0.5, Math.sqrt(3) / 2), NoMovePoint],
  60 => [Complex(0.5, Math.sqrt(3) / 2),   Complex(-Math.sqrt(3) / 2,  0.5), NoMovePoint],
  120 => [Complex(-0.5, Math.sqrt(3) / 2), Complex(-Math.sqrt(3) / 2, -0.5), NoMovePoint],
  180 => [Complex(-1.0, 0.0), Complex(0.0, -1.0), NoMovePoint],
  240 => [Complex(-0.5, -Math.sqrt(3) / 2), Complex(Math.sqrt(3) / 2, -0.5), NoMovePoint]
}
def trot(degAngle)
  # """
  # degAngle: integer degree angle
  # """
  unless  Trot_memo.has_key? degAngle
    ang = (degAngle * Math::PI / 180)
    c = Math.cos(ang)
    s = Math.sin(ang)
    Trot_memo[degAngle] = [Complex(c, s), Complex(-s, c), Complex(0, 0)]
    p "trot_memo[#{degAngle}]=#{Trot_memo[degAngle]}"
  end
  Trot_memo[degAngle]
end

IDENTITY =    [Complex(1.0, 0), Complex(0, 1.0), Complex(0)] # == trot(0)
ReverseTrsf = [Complex(-1.0, 0), Complex(0, 1.0), 0] # @TODO: Not trot(180).  Instead of rotating 180 degrees, get a mirror image.

# The trot_inv function takes a rotation matrix and derives the angle it represents,
#  by calculating the inverse trigonometric functions on the matrix elements.
def trot_inv(t)
  # T: rotation matrix for Affine transform
  # p ["trot_inv(t)", t]
  degAngle1 = (Math.atan2(t[0].imag.to_f, t[0].real.to_f) / Math::PI * 180).round.to_i
  degAngle1 += 360 if degAngle1 <= -180
  degAngle2 = (Math.atan2(-t[1].real.to_f, t[1].imag.to_f) / Math::PI * 180).round.to_i
  if degAngle1 == degAngle2 # self validate angle
    scaleY = 1
  elsif degAngle1 == (-degAngle2)
    scaleY = -1
  elsif (degAngle1 == (180 - degAngle2)) or (degAngle2 == (180 - degAngle1))
    scaleY = -1
  elsif (degAngle1 == (degAngle2 - 180)) or (degAngle2 == (degAngle1 - 180))
    scaleY = -1
  else
    scaleY = -1
    p ["ValueError at trot_inv: degAngle1=#{degAngle1}, degAngle2=#{degAngle2}", [t[0].to_s, t[1].to_s],
       [[t[0].real.to_f, t[0].imag.to_f], [t[1].real.to_f, t[1].imag.to_f]]]
    raise('ValueError at trot_inv: degAngle1.abs != degAngle2.abs')
  end

  [degAngle1, scaleY]
end

TROT_REPLACE_ARR = [-1, -0.8660254037844386, -0.5, 0, 0.5, 0.8660254037844386, 1]
def trot_refine(trsf)
  # trsf: transformation matrix
  trsf_flatten = [trsf[0].real, trsf[0].imag, trsf[1].real, trsf[1].imag]
  idx = trsf_flatten.map { |x| TROT_REPLACE_ARR.map { |y| (x - y).abs }.each_with_index.min[1] }
  trsf[0].real, trsf[0].imag, trsf[1].real, trsf[1].imag = TROT_REPLACE_ARR.values_at(*idx)
  trsf
end

# Matrix * point
# transPt applies a transformation matrix to a point (represented as a Complex number) using matrix multiplication.
def transPt(trsf, quad)
  Complex(quad.real * trsf[0].real + quad.imag * trsf[1].real,
          quad.real * trsf[0].imag + quad.imag * trsf[1].imag) + trsf[2]
  # p ["transPt",trsf ,quad,trPt]
end

# Affine 2-matrix multiply
# mul functions multiplies two transformation matrices to combine multiple transforms.
def mul(trsfA, trsfB)
  [
    Complex(
      trsfA[0].real * trsfB[0].real + trsfA[1].real * trsfB[0].imag,
      trsfA[0].imag * trsfB[0].real + trsfA[1].imag * trsfB[0].imag
    ),
    Complex(
      trsfA[0].real * trsfB[1].real + trsfA[1].real * trsfB[1].imag,
      trsfA[0].imag * trsfB[1].real + trsfA[1].imag * trsfB[1].imag
    ),
    Complex(
      trsfA[0].real * trsfB[2].real + trsfA[1].real * trsfB[2].imag + trsfA[2].real,
      trsfA[0].imag * trsfB[2].real + trsfA[1].imag * trsfB[2].imag + trsfA[2].imag
    )
  ]
  # p ["mul trsfA=", trsfA.to_s]
  # p ["mul trsfA.arg =", trot_inv(trsfA)]
  # p ["mul trsfB=", trsfB.to_s]
  # p ["mul trsfB.arg =", trot_inv(trsfB)]
  # p ["mul trsfAB =", trsfAB.to_s]
  # p ["mul trsfAB.arg =", trot_inv(trsfAB)]
end

class Tile
  attr_reader :label, :quad

  def initialize(label)
    # _: NO list of Tile coordinate points
    # label: Tile type used for shapes coloring
    # quad: Tile quad points
    @label = label
    @quad = SPECTRE_QUAD.dup
  end

  def forEachTile(tile_transformation, parentInfo, &drawer)
    # print("at Tile.drawPolygon #{@label} quad=#{@quad}")
    drawer.call(tile_transformation, @label, parentInfo)
  end
end

class MetaTile
  attr_reader :label, :quad, :tiles, :transformations

  def initialize(label, tiles, transformations, quad = SPECTRE_QUAD.dup)
    # """
    # label: Tiles type used for shapes coloring
    # tiles: list of Tiles(No points)
    # transformations: list of transformation matrices
    # quad: MetaTile quad points
    # """
    @label = label
    @tiles = tiles
    @transformations = transformations
    @quad = quad
  end

  def forEachTile(transformation, parentInfo, &drawer)
    # """
    # recursively expand MetaTiles down to Tiles and draw those
    # """
    clusterInfo = (@label == 'Gamma') && (@tiles[0].label == 'Gamma1') ? parentInfo : (parentInfo + [@label])
    # TODO: parallelize?
    @tiles.zip(@transformations).each do |tile, trsf|
      tile.forEachTile(mul(transformation, trsf), clusterInfo, &drawer)
    end
    nil
  end
end

TILE_NAMES = %w[Gamma Delta Theta Lambda Xi Pi Sigma Phi Psi]

def buildSpectreBase
  tiles = {}
  TILE_NAMES.each do |label|
    tiles[label] = case label
                   when 'Gamma'
                     # special rule for Mystic == Gamma == Gamma1 + Gamma2"
                     MetaTile.new(label,
                                  [
                                    Tile.new('Gamma1'),
                                    Tile.new('Gamma2')
                                  ],
                                  [
                                    IDENTITY.dup,
                                    mul(
                                      [IDENTITY[0], IDENTITY[1], SPECTRE_POINTS[8]],
                                      trot(30)
                                    )
                                  ],
                                  SPECTRE_QUAD.dup)
                   else
                     Tile.new(label)
                   end
  end
  # print("tiles[Gamma]=#{tiles["Gamma"].transformations}\n")
  tiles
end

def buildSupertiles(input_tiles)
  # """
  # iteratively build on current system of tiles
  # input_tiles = current system of tiles, initially built with buildSpectreBase()
  # """
  # First, use any of the nine-unit tiles in "tiles" to obtain a
  # list of transformation matrices for placing tiles within supertiles.
  quad = input_tiles['Delta'].quad

  total_angle = 0
  rotation =  trot(total_angle) # IDENTITY.copy() #
  transformations =  [rotation] # [IDENTITY.copy()]
  transformed_quad = quad.dup
  # p "at buildSupertiles transformed_quad = quad", transformed_quad
  [[60, 3, 1],
   [0, 2, 0],
   [60, 3, 1],
   [60, 3, 1],
   [0, 2, 0],
   [60, 3, 1],
   [-120, 3, 3]].each do |angle, from, to|
    if angle != 0
      total_angle += angle
      rotation = trot(total_angle)
      transformed_quad = quad.map { |quad1| transPt(rotation, quad1) } # + trot[:,2]
    end
    # p "total_angle=#{total_angle} transformed_quad=#{transformed_quad} rotation=#{rotation} quad=#{quad}"
    ttrans = [IDENTITY[0].dup, IDENTITY[1].dup, transPt(transformations[-1], quad[from]) - transformed_quad[to]]
    # p "total_angle=#{total_angle} ttrans=#{ttrans} transformations[-1]=#{transformations[-1]}  quad[_from]=#{quad[from]} transformed_quad[_to,:]=#{transformed_quad[to]}"
    transformations.append(mul(ttrans, rotation))
  end

  transformations = # @TODO: Instead of rotating 180 degrees, get a mirror image.
    transformations.map do |trsf|
      mul(ReverseTrsf, trsf)
    end
  # p "transformations=#{[6,5,3,0].map{|i| transformations[i]}}"
  # p "quad=#{[2,1].map{|i| quad[i]}}"
  # @TODO: TOBE auto update svg transform.translate scaleY. failed by (SvgContens_drowSvg_transform_scaleY=spectreTiles["Delta"].transformations[0][0,0])

  # Now build the actual supertiles, labeling appropriately.
  super_quad = [
    transPt(transformations[6], quad[2]),
    transPt(transformations[5], quad[1]),
    transPt(transformations[3], quad[2]),
    transPt(transformations[0], quad[1])
  ]
  # p "transformations=#{[6,5,3,0].map{|i| transformations[i]}}"
  # p "quad=#{[2,1].map{|i| quad[i]}}"
  # print("super_quad=#{super_quad}\n")

  tiles = {}
  [
    ['Gamma', ['Pi', 'Delta', nil, 'Theta', 'Sigma', 'Xi', 'Phi', 'Gamma']],
    ['Delta',  %w[Xi Delta Xi Phi Sigma Pi Phi Gamma]],
    ['Theta',  %w[Psi Delta Pi Phi Sigma Pi Phi Gamma]],
    ['Lambda', %w[Psi Delta Xi Phi Sigma Pi Phi Gamma]],
    ['Xi',     %w[Psi Delta Pi Phi Sigma Psi Phi Gamma]],
    ['Pi',     %w[Psi Delta Xi Phi Sigma Psi Phi Gamma]],
    ['Sigma',  %w[Xi Delta Xi Phi Sigma Pi Lambda Gamma]],
    ['Phi',    %w[Psi Delta Psi Phi Sigma Pi Phi Gamma]],
    ['Psi',    %w[Psi Delta Psi Phi Sigma Psi Phi Gamma]]
  ].each do |label, substitutions|
    tiles[label] = MetaTile.new(
      label,
      substitutions.filter { |subst| subst }.map { |subst| input_tiles[subst] },
      substitutions.zip(transformations).filter { |subst, _| subst }.map { |_subst, trsf| trsf },
      super_quad
    )
  end
  tiles
end

#### main process ####
def buildSpectreTiles(n_ITERATIONS)
  tiles = buildSpectreBase
  print("  init quad\n")
  tiles['Delta'].quad.each_with_index do |quad1, i|
    print("   quad[#{i}] = #{quad1}\t(#{quad1.real.to_f})+(#{quad1.imag.to_f})*i\n")
  end
  n_ITERATIONS.times do |n|
    tiles = buildSupertiles(tiles)
    print("  #{n + 1} Iterationed transformations[\"Delta\"][[6,5,3,0]]\n")
    [6, 5, 3, 0].each do |i|
      trsf1 = tiles['Delta'].transformations[i]
      angle, = trot_inv(trsf1)
      print("   transformations[#{i}] = { angle: #{angle},\t moveTo: (#{trsf1[2].real}) + (#{trsf1[2].imag})*i }\n")
    end
    print("  #{n + 1} Iterationed quad[\"Delta\"]\n")
    tiles['Delta'].quad.each_with_index do |quad1, i|
      print("   quad[#{i}] = #{quad1}\t(#{quad1.real.to_f})+(#{quad1.imag.to_f})*i\n")
    end
  end
  tiles
end

### drawing parameter data

Trot_inv_prof = {
  # -180=> 0,
  -150 => 0, # Gamma2
  -120 => 0,
  -90 => 0, # Gamma2
  -60 => 0,
  -30 => 0, # Gamma2
  0 => 0,
  30 => 0, # Gamma2
  60 => 0,
  90 => 0, # Gamma2
  120 => 0,
  150 => 0, # Gamma2
  180 => 0,
  360 => 0 # Gamma2 total
}
def print_trot_inv_prof
  print('transformation rotation profile(angle: count)={')
  p Trot_inv_prof
  Trot_inv_prof
end

COLOR_MAP_monocolor = {
  'Gamma' => [255, 255, 255],
  'Gamma1' => [150, 150, 150],
  'Gamma2' => [64,  64,  64],
  'Delta' => [255, 255, 255],
  'Theta' => [255, 255, 255],
  'Lambda' => [255, 255, 255],
  'Xi' => [255, 255, 255],
  'Pi' => [255, 255, 255],
  'Sigma' => [255, 255, 255],
  'Phi' => [255, 255, 255],
  'Psi' => [255, 255, 255]
}

def get_color_array_byLabel(_tile_transformation, label, _parentInfo, color_map = COLOR_MAP_monocolor)
  # p [parentInfo, label]
  color_map[label]
end

# ref https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/aperiodic-spectre/#four-colouring

COLOR_MAP_four_color = [
  [64, 64, 255], # tile color for Gamma2
  [255, 64, 64],
  [64, 255, 64],
  [220, 220, 64],
  [96, 96, 96], # tile color for invalid
  [255, 255, 255] # tile color for invalid
]

Color_Index_2d = [ # level 0 cluster color pattern
  [3, 2, 3, 1, 3, 1, 2, 1, 0] #               substitution[0,1,2,3]
  # [3, 1, 3, 2, 3, 2, 1, 2, 0], #               substitution[0,2,1,3]
  # [3, 1, 3, 2, 3, 2, 1, 2, 0], # except Gamma  substitution[0,2,1,3]
  # [3, 2, 3, 1, 3, 1, 2, 1, 0], #               substitution[0,1,2,3]
  # [3, 1, 3, 2, 3, 2, 1, 2, 0], #               substitution[0,2,1,3]
  # [3, 1, 3, 2, 3, 2, 1, 2, 0], #               substitution[0,2,1,3]
  # [3, 2, 3, 1, 3, 1, 2, 1, 0], # Gamma1        substitution[0,1,2,3]
  # [2, 1, 2, 3, 2, 3, 1, 3, 0]  # Gamma2        substitution[0,3,1,2]
]

Color_Index_substitution_lv = [
  [ # even level clusters 0,2,4
    [0, 1, 2, 3],
    [0, 2, 1, 3],
    [0, 2, 1, 3],  # except Gamma
    [0, 1, 2, 3],
    [0, 2, 1, 3],
    [0, 2, 1, 3],
    [0, 1, 2, 3],  # Gamma1
    [0, 3, 1, 2] # Gamma2
  ],
  [ # odd level clusters 1,3,5
    [0, 1, 2, 3],
    [0, 1, 3, 2],
    [0, 2, 1, 3],  # except Gamma
    [0, 2, 3, 1],
    [0, 2, 1, 3],
    [0, 3, 2, 1],
    [0, 3, 1, 2],  # Gamma1
    [0, 2, 3, 1] # Gamma2
  ]
]

$color_child_index = 0
$color_parent_index_byLevel = [0]
$color_get_count = 0
def get_color_array_fourColor(_tile_transformation, _label, parentInfo)
  $color_get_count += 1

  color_index_subst = $color_parent_index_byLevel.map.with_index.reduce(Color_Index_2d[0][$color_child_index]) do |subColer, (place, levelNo)|
    # p ["Color_Index_substitution_lv[levelNo][place][subColer]",levelNo, place, subColer, Color_Index_substitution_lv[levelNo % 2][place][subColer] ]
    Color_Index_substitution_lv[levelNo % 2][place][subColer]
  end
  # p [$color_get_count, parentInfo, label, $color_parent_index_byLevel, $color_child_index, color_index_subst]
  rgb = COLOR_MAP_four_color[color_index_subst]

  $color_child_index += 1
  if ($color_child_index == 2) && ($color_parent_index_byLevel[0] == 7) # (parentInfo[-1] == 'Gamma')
    $color_child_index += 1
  elsif $color_child_index >= (Color_Index_2d[0].length)
    $color_child_index = 0
    carry = 1
    placeIndex = 0
    while (placeIndex < parentInfo.length) && (carry > 0)
      $color_parent_index_byLevel[placeIndex] = ($color_parent_index_byLevel[placeIndex] || 0) + carry
      carry = 0
      if ($color_parent_index_byLevel[placeIndex] == 2) && ($color_parent_index_byLevel[placeIndex + 1] == 7) # (parentInfo[-2 - placeIndex] == 'Gamma')
        $color_parent_index_byLevel[placeIndex] += 1
      elsif $color_parent_index_byLevel[placeIndex] >= (Color_Index_substitution_lv[0].length)
        $color_parent_index_byLevel[placeIndex] = 0
        carry = 1
      end
      placeIndex += 1
    end
  end

  rgb
end

# get color array by angle

def get_color_array_by_angle(tile_transformation, label, _parentInfo)
  angle, _scale = trot_inv(tile_transformation)
  return [64, 64, 64] if label == 'Gamma2'

  rgb = {
    -180 => [255, 0, 0],
    -120 => [229, 0, 0],
    -60 => [229, 102, 102],
    0 => [255, 0, 0],
    60 => [102, 102, 229],
    120 => [0, 204, 229],
    180 => [0, 0, 255]
  }[angle]
  return rgb if rgb

  p ['Inalid color {rgb} {label}, {tile_transformation}', rgb, label, tile_transformation, angle]

  [128, 128, 128]
end

start_time1 = Time.now
transformation_min_X = Float::INFINITY
transformation_min_Y = Float::INFINITY
transformation_max_X = -Float::INFINITY
transformation_max_Y = -Float::INFINITY
num_tiles = 0
tiles = buildSpectreTiles(N_ITERATIONS)
tiles['Delta'].forEachTile(IDENTITY, []) do |tile_transformation, label, _|
  angle, = trot_inv(tile_transformation) # validate trasform rotation.
  Trot_inv_prof[angle] += 1
  Trot_inv_prof[360] += 1 if label == 'Gamma2'
  transformation_min_X = [transformation_min_X, tile_transformation[2].real.to_f].min
  transformation_min_Y = [transformation_min_Y, tile_transformation[2].imag.to_f].min
  transformation_max_X = [transformation_max_X, tile_transformation[2].real.to_f].max
  transformation_max_Y = [transformation_max_Y, tile_transformation[2].imag.to_f].max
  num_tiles += 1
end
print("* #{N_ITERATIONS} Iterations, generated #{num_tiles} tiles\n")


transformation_min_X = (transformation_min_X - Edge_a * 3 - Edge_b * 3).to_i
transformation_min_Y = (transformation_min_Y - Edge_a * 3 - Edge_b * 3).to_i
transformation_max_X = (transformation_max_X + Edge_a * 3 + Edge_b * 3).to_i
transformation_max_Y = (transformation_max_Y + Edge_a * 3 + Edge_b * 3).to_i
print("buildSpectreTiles process #{Time.now - start_time1}sec.\n")

start_time2 = Time.now
svgContens_drowSvg_transform_scaleY = N_ITERATIONS.even? ? 1 : -1
svgFileName = "spectre-tile#{Edge_a.truncate(1)}-#{Edge_b.truncate(1)}-#{N_ITERATIONS}-#{num_tiles}tiles-float.svg"

File.open(svgFileName, 'w') do |file|
  viewWidth = transformation_max_X - transformation_min_X
  viewHeight = transformation_max_Y - transformation_min_Y
  file.puts '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'
  file.puts " width=\"#{viewWidth}\" height=\"#{viewHeight}\" viewBox=\"#{transformation_min_X} #{transformation_min_Y} #{viewWidth} #{viewHeight}\">"
  file.puts '<defs>'
  file.puts '<path id="d0" d="M' +
            SPECTRE_POINTS.map { |pt2| pt2.real.to_f.to_s + ',' + pt2.imag.to_f.to_s }.inject { |pts, pt1| pts + ' L' + pt1 } +
            ' Z" stroke="gray" stroke-width="1.2"/>'
  file.puts '<path id="d1" d="M' +
            Mystic_SPECTRE_POINTS.map { |pt2| pt2.real.to_f.to_s + ',' + pt2.imag.to_f.to_s }.inject { |pts, pt1| pts + ' L' + pt1 } +
            ' Z" stroke="gray" stroke-width="1.2"/>'
  file.puts '</defs>'

  tiles['Delta'].quad.each_with_index do |quad1, _i|
    file.puts "<rect x=\"#{quad1.real.to_f}\" y=\"#{quad1.imag.to_f}\"" +
              " width=\"#{(Edge_a + Edge_b) / 1.1}\" height=\"#{(Edge_a + Edge_b) / 1.1}\"" +
              ' r="8" fill="rgb(0,222,0)" fill-opacity="90%" />'
  end

  seq = 0
  tiles['Delta'].forEachTile(IDENTITY, []) do |tile_transformation, label, adjacentID|
    trsf = tile_transformation
    degAngle = trot_inv(trsf)[0]
    if degAngle == degAngle
      file.puts '<circle cx="' + trsf[2].real.to_f.to_s + '" cy="' + trsf[2].imag.to_f.to_s +
                '" r="4" fill="' + (label == 'Gamma2' ? 'rgb(128,8,8)' : 'rgb(66,66,66)') + '" fill-opacity="90%" />'
      file.puts '<use xlink:href="#' + (label != 'Gamma2' ? 'd0' : 'd1') + '" x="0" y="0" ' +
                " transform=\"translate(#{trsf[2].real.to_f},#{trsf[2].imag.to_f}) rotate(#{degAngle}) scale(1,#{svgContens_drowSvg_transform_scaleY})\"" +
                ' fill="' + 'rgb(' + get_color_array_by_angle(trsf, label, adjacentID).join(',') + ')' +
                '" fill-opacity="50%" stroke="black" stroke-weight="0.1" />'
      file.puts '<text x="' + Edge_a.to_s + '" y="' + (Edge_b * 0.5).to_s + '"' +
                " transform=\"translate(#{trsf[2].real.to_f},#{trsf[2].imag.to_f}) rotate(#{degAngle - 15}) " +
                '" font-size="8">' +
                label +
                #  (seq+= 1).to_s +
                '</text>'
    end
  end
  file.puts '</svg>'
end
print(" each angle's tile count =\t#{Trot_inv_prof}\n")
p "svg file write process #{Time.now - start_time2}sec"

p "total process time #{Time.now - start_time1}sec"
p 'save filename=', svgFileName
