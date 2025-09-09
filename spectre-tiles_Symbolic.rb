#!/usr/bin/ruby
# drow spectre tiles by symbolic coef complex class
require './myComplex2Coef'

## configlation
# * increase this number for larger tilings.
N_ITERATIONS = 4
# * shape Edge_ration tile(Edge_a, Edge_b)
Edge_a = 20.0 / (Math.sqrt(3) + 2.0)
Edge_b = 20.0 - Edge_a
## end of configilation.

MyNumeric2Coef.A = Edge_a
MyNumeric2Coef.B = Edge_b

SPECTRE_POINTS = [
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))), # pt(0, 0), // 1: -b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0))), # pt(a, 0.0), // 2:  + a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(0, 0))), # pt(a + a_d2, 0 - a_sqrt3_d2), // 3: + ~a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0))), # pt(a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b_d2), // 4: + ~b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))), # pt(a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b + b_d2), // 5: + b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(3, 0))), # # pt(a + a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 + b + b_d2), // 6: + a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), # pt(a + a + a + b_sqrt3_d2, b + b_d2), // 7: + ~a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(4, 0))), # pt(a + a + a, b + b),// 8: (3.0, 2.0), // 8: -~b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(6, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), # pt(a + a + a - b_sqrt3_d2, b + b - b_d2), // 9: -~b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(5, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), # pt(a + a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 10: +~b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(3, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), # pt(a + a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 11: -b
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(3, 0))), #    pt(a_d2 - b_sqrt3_d2, a_sqrt3_d2 + b + b - b_d2), // 12: -a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, -1)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(3, 0))), #    pt(0 - b_sqrt3_d2, b + b - b_d2), // 13: -a
  Complex(MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(0, 0)), MyNumeric2Coef.new(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0))) #    pt(0.0, b) // +b
]

NoMovePoint = SPECTRE_POINTS[0].dup
SPECTRE_QUAD = [3, 5, 7, 11].map { |idx| SPECTRE_POINTS[idx].dup }
Mystic_SPECTRE_POINTS = SPECTRE_POINTS.map do |c|
  Complex(MyNumeric2Coef.new(c.real.xy, c.real.uv), MyNumeric2Coef.new(c.imag.xy, c.imag.uv))
end

print("coef A = #{Edge_a}\t\tRatio(#{(Edge_a / (Edge_a + Edge_b)).round(4)})\n")
print("coef B = #{Edge_b}\t\tRatio(#{(Edge_b / (Edge_a + Edge_b)).round(4)})\n")
[['SPECTRE_POINTS =', SPECTRE_POINTS], ['Mystic_SPECTRE_POINTS =', Mystic_SPECTRE_POINTS]].each do |vName, v|
  print("#{vName} [\n")
  v.each { |c| print("\t#{c}, \t\t(#{c.real.to_f.round(4)} + #{c.imag.to_f.round(4)}*i),\n") }
  print("]\n")
end
# Rotation matrix for Affine transform
# pre-computed rotation matrices for common angles in the Trot_memo hash,
# to avoid recomputing them. The trot function looks up or computes the rotation matrix for a given angle.
Trot_memo = {
  -30 => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)),
          Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)), NoMovePoint],
  0 => [Complex(MyNumeric1Coef.new(2, 0), MyNumeric1Coef.new(0, 0)),
        Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), NoMovePoint],
  30 => [Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(1, 0)),
         Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)), NoMovePoint],
  60 => [Complex(MyNumeric1Coef.new(1, 0), MyNumeric1Coef.new(0, 1)),
         Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(1, 0)), NoMovePoint],
  120 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, 1)),
          Complex(MyNumeric1Coef.new(0, -1), MyNumeric1Coef.new(-1, 0)), NoMovePoint],
  180 => [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)),
          Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(-2, 0)), NoMovePoint],
  240 => [Complex(MyNumeric1Coef.new(-1, 0), MyNumeric1Coef.new(0, -1)),
          Complex(MyNumeric1Coef.new(0, 1), MyNumeric1Coef.new(-1, 0)), NoMovePoint]
}

def trot(degAngle)
  # """
  # degAngle: integer degree angle
  # """
  throw "Error at trot_memo not defind angle #{degAngle}" unless Trot_memo.has_key? degAngle
  Trot_memo[degAngle]
end

IDENTITY = trot(0)
ReverseTrsf = [Complex(MyNumeric1Coef.new(-2, 0), MyNumeric1Coef.new(0, 0)), Complex(MyNumeric1Coef.new(0, 0), MyNumeric1Coef.new(2, 0)), NoMovePoint] # @TODO: Not trot(180).  Instead of rotating 180 degrees, get a mirror image.

def trot_inValid(t)
  return "Error at trot_inValid type is not Array: #{t.class.name} #{t} " if t.class.name != 'Array'

  [0, 1].each do |i|
    if t[i].class.name != 'Complex'
      return "Error at trot_inValid element[#{i}] type is not Complex: #{t[i].class.name} #{t[i]} "
    end
    if ((tAbs = ((t[i].imag.to_f**2) + (t[i].real.to_f**2))) - 1).abs > MyNumericCoef::CONST_EPSILON
      return "ValueError at trot_inValid: (t[#{i}].abs ** 2) = #{tAbs} != 1  #{t[i]}"
    end
  end
  nil
end

# The trot_inv function takes a rotation matrix and derives the angle it represents,
#  by calculating the inverse trigonometric functions on the matrix elements.
def trot_inv(t)
  # T: rotation matrix for Affine transform
  # p ["trot_inv(t)", t]
  if trot_err1 = trot_inValid(t)
    p [trot_err1, t.to_s]
    throw trot_err1
  end
  degAngle1 = (Math.atan2(t[0].imag.to_f, t[0].real.to_f) / Math::PI * 180).round.to_i
  degAngle1 += 360 if degAngle1 <= -180
  degAngle2 = (Math.atan2(-t[1].real.to_f, t[1].imag.to_f) / Math::PI * 180).round.to_i
  if degAngle1 == degAngle2 # self validate angle
    scaleY = 1
  elsif degAngle1 == (-degAngle2)
    scaleY = -1
  elsif (degAngle1 == (180 - degAngle2)) || (degAngle2 == (180 - degAngle1))
    scaleY = -1
  elsif (degAngle1 == (degAngle2 - 180)) || (degAngle2 == (degAngle1 - 180))
    scaleY = -1
  else
    scaleY = -1
    p ["ValueError at trot_inv: degAngle1=#{degAngle1}, degAngle2=#{degAngle2}", [t[0].to_s, t[1].to_s],
       [[t[0].real.to_f, t[0].imag.to_f], [t[1].real.to_f, t[1].imag.to_f]]]
    throw('ValueError at trot_inv: degAngle1.abs != degAngle2.abs')
  end
  [degAngle1, scaleY]
end

# validate trot angle data
Trot_memo.each do |exceptAngle, value|
  # p ["verify trot",exceptAngle, value.class.name, value]
  actualAngle, = trot_inv(value)
  # @TODO ex. (exceptAngle=240 - 360) == (actualAngle=-120)

  next unless (exceptAngle != actualAngle) && ((exceptAngle - 360) != actualAngle)

  p ["Error at trot_memo not mutch angle #{exceptAngle} != #{actualAngle} "]
end

# Matrix * point
# transPt applies a transformation matrix to a point (represented as a Complex number) using matrix multiplication.
def transPt(trsf, quad)
  Complex(quad.real * trsf[0].real + quad.imag * trsf[1].real,
          quad.real * trsf[0].imag + quad.imag * trsf[1].imag) + trsf[2]
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
    ###
    # label: Tiles type used for shapes coloring
    # tiles: list of Tiles(No points)
    # transformations: list of transformation matrices
    # quad: MetaTile quad points
    ###
    @label = label
    @tiles = tiles
    @transformations = transformations
    @quad = quad
    trot_err1 = ''
    return unless transformations.any? { |t| trot_err1 = trot_inValid(t) }

    p [trot_err1, t.to_s, tiles, transformations, quad]
    throw trot_err1
  end

  def forEachTile(transformation, parentInfo, &drawer)
    ###
    # recursively expand MetaTiles down to Tiles and draw those
    ###
    clusterInfo = (@label == 'Gamma') && (@tiles[0].label == 'Gamma1') ? parentInfo : (parentInfo + [@label])
    # TODO: parallelize?
    # @transformations.size.times do |i| # validate travsform rotation
    #   next unless trot_err2 = trot_inValid(@transformations[i])
    #   p ["ERROR at MetaTile.forEachTile @transformations[#{i}] ", trot_err2, @transformations[i].to_s, @transformations[i]]
    #   p ['quad=', @quad]
    #   throw trot_err2
    # end
    # p [@tiles.class.name, @tiles.size, clusterInfo]
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
  ###
  # iteratively build on current system of tiles
  # input_tiles = current system of tiles, initially built with buildSpectreBase()
  ###
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
  transformations.size.times do |i| # validate travsform rotation
    trot_err2 = trot_inValid(transformations[i])
    next unless trot_err2

    p ["ERROR at travsformations[#{i}] ", trot_err2, transformations[i].to_s, transformations[i]]
    p ['quad=', quad]
    throw trot_err2
  end
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
# get color array by label
# Color map from Figure 5.3
COLOR_MAP_fig53 = {
  'Gamma' => [203, 157, 126],
  'Gamma1' => [203, 157, 126],
  'Gamma2' => [203, 157, 126],
  'Delta' => [163, 150, 133],
  'Theta' => [208, 215, 150],
  'Lambda' => [184, 205, 178],
  'Xi' => [211, 177, 144],
  'Pi' => [218, 197, 161],
  'Sigma' => [191, 146, 126],
  'Phi' => [228, 213, 167],
  'Psi' => [224, 223, 156]
}
COLOR_MAP_orig = {
  'Gamma' => [255, 255, 255],
  'Gamma1' => [255, 255, 255],
  'Gamma2' => [255, 255, 255],
  'Delta' => [220, 220, 220],
  'Theta' => [255, 191, 191],
  'Lambda' => [255, 160, 122],
  'Xi' => [255, 242, 0],
  'Pi' => [135, 206, 250],
  'Sigma' => [245, 245, 220],
  'Phi' => [0, 255, 0],
  'Psi' => [0, 255, 255]
}
COLOR_MAP_mystics = {
  'Gamma' => [196, 201, 169],
  'Gamma1' => [196, 201, 169],
  'Gamma2' => [156, 160, 116],
  'Delta' => [247, 252, 248],
  'Theta' => [247, 252, 248],
  'Lambda' => [247, 252, 248],
  'Xi' => [247, 252, 248],
  'Pi' => [247, 252, 248],
  'Sigma' => [247, 252, 248],
  'Phi' => [247, 252, 248],
  'Psi' => [247, 252, 248]
}
COLOR_MAP_pride = {
  'Gamma' => [255, 255, 255],
  'Gamma1' => [97,  57,  21],
  'Gamma2' => [64,  64,  64],
  'Delta' => [2, 129, 33],
  'Theta' => [0, 76, 255],
  'Lambda' => [118, 0, 136],
  'Xi' => [229, 0, 0],
  'Pi' => [255, 175, 199],
  'Sigma' => [115, 215, 238],
  'Phi' => [255, 141,   0],
  'Psi' => [255, 238,   0]
}
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
  # color_index_subst = $color_parent_index_byLevel.map.with_index.reduce(Color_Index_2d[0][$color_child_index]) do |subColer, (place, levelNo)|
  #   # p ["Color_Index_substitution_lv[levelNo][place][subColer]",levelNo, place, subColer, Color_Index_substitution_lv[levelNo % 2][place][subColer] ]
  #   Color_Index_substitution_lv[levelNo % 2][place][subColer]
  # end
  color_index_subst = Color_Index_2d[0][$color_child_index]
  $color_parent_index_byLevel.each_with_index do |place, levelNo|
    color_index_subst = Color_Index_substitution_lv[levelNo % 2][place][color_index_subst]
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
      $color_parent_index_byLevel[placeIndex] ||= 0
      $color_parent_index_byLevel[placeIndex] += carry
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

COLOR_power_in_cluster = {
  'Delta' => 0b001111111,
  'Theta' => 0b001000011,
  'Lambda' => 0b001000111,
  'Xi' => 0b001001001,
  'Pi' => 0b001001011,
  'Sigma' => 0b001001111,
  'Phi' => 0b001101001,
  'Psi' => 0b001100011
}
COLOR_MAP_4_clusterNo = [
  [0b00000101, 0b00000000, 0b00000000],
  [0b00000011, 0b00000011, 0b00000000],
  [0b00000111, 0b00000111, 0b00000000],
  [0b00000000, 0b00000101, 0b00000000],
  [0b00000000, 0b00000011, 0b00000011],
  [0b00000000, 0b00000111, 0b00000111],
  [0b00000000, 0b00000000, 0b00000101],
  [0b00000011, 0b00000000, 0b00000011],
  [0b00000111, 0b00000000, 0b00000111]
]

$color_cluster_no = 0

def get_color_array_by_cluster(_tile_transformation, label, parentInfo)
  # p [parentInfo, label, $color_cluster_no]
  rgb = if label == 'Gamma2'
          [0b11110000, 0b11110000, 0b11110000]
        elsif label == 'Gamma1'
          [0b01110000, 0b01110000, 0b01110000]
        else
          COLOR_MAP_4_clusterNo[$color_cluster_no].map { |c, _m| (c * COLOR_power_in_cluster[label]) }
        end
  if label == 'Gamma2' && (parentInfo[-1] == 'Gamma')
    $color_cluster_no = ($color_cluster_no + 1) % COLOR_MAP_4_clusterNo.length
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
  if trot_err1 = trot_inValid(tile_transformation)
    p [trot_err1, angle, tile_transformation]
    throw trot_err1
  end
end

print("* #{N_ITERATIONS} Iterations, generated #{num_tiles} tiles\n")
# tiles["Delta"].quad.each_with_index do |quad1, i|
#     print(" quad[#{i}] = #{quad1.to_s}\t(#{quad1.real.to_f})+(#{quad1.imag.to_f})*i\n")
# end
transformation_min_X = (transformation_min_X - Edge_a * 3 - Edge_b * 3).to_i
transformation_min_Y = (transformation_min_Y - Edge_a * 3 - Edge_b * 3).to_i
transformation_max_X = (transformation_max_X + Edge_a * 3 + Edge_b * 3).to_i
transformation_max_Y = (transformation_max_Y + Edge_a * 3 + Edge_b * 3).to_i
print("buildSpectreTiles process #{Time.now - start_time1}sec.\n")

start_time2 = Time.now
svgContens_drowSvg_transform_scaleY = N_ITERATIONS.even? ? 1 : -1
svgFileName = "spectre-tile#{Edge_a.truncate(1)}-#{Edge_b.truncate(1)}-#{N_ITERATIONS}-#{num_tiles}tiles.svg"
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
                ' fill="' + 'rgb(' + get_color_array_fourColor(trsf, label, adjacentID).join(',') + ')' +
                '" fill-opacity="47%" stroke="black" stroke-weight="0.1" />'
      file.puts '<text x="' + Edge_a.to_s + '" y="' + (Edge_b * 0.5).to_s + '"' +
                " transform=\"translate(#{trsf[2].real.to_f},#{trsf[2].imag.to_f}) rotate(#{degAngle - 15}) " +
                '" font-size="8">' +
                # (label) +
                (seq += 1).to_s +
                '</text>'
    end
  end
  file.puts '</svg>'
end
print(" each angle's tile count =\t#{Trot_inv_prof}\n")
p "svg file write process #{Time.now - start_time2}sec"
# csv file output for EXCEL UTF-8 with BOM
start_time3 = Time.now
File.open(svgFileName + '.csv', 'w', encoding: 'UTF-8') do |file|
  file.puts "\uFEFF" + # BOM
            "label,\"transform  {A:#{Edge_a}, B:#{Edge_b}}\",angle,transform[0].x,transform[0].y,transform[1].x,transform[1].y,transform[2].x,transform[2].y,pt0-coef:a0,a1, b0,b1" # header
  tiles['Delta'].forEachTile(IDENTITY, []) do |trsf, label|
    degAngle = trot_inv(trsf)[0]
    file.puts "\"#{label}\",\"#{trsf[2]}\",#{degAngle},#{trsf[0].real.to_f},#{trsf[0].imag.to_f},#{trsf[1].real.to_f},#{trsf[1].imag.to_f},#{trsf[2].real.to_f},#{trsf[2].imag.to_f}, #{to_coef(trsf[2]).join(', ')}"
  end
end
p "csv file write process #{Time.now - start_time3}sec"
p "total process time #{Time.now - start_time1}sec"
p 'save filename=', svgFileName
