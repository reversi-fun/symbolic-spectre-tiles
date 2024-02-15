#!/usr/bin/ruby
require 'matrix'
require 'complex'

## configlation
#* increase this number for larger tilings.
N_ITERATIONS = 3
#* shape Edge_ration tile(Edge_a, Edge_b)
Edge_a = 10.0 # 20.0 / (Math.sqrt(3) + 1.0)
Edge_b = 10.0 # 20.0 - Edge_a
## end of configilation.

def get_spectre_points(edge_a, edge_b)
    a = edge_a
    a_sqrt3_d2 = a * Math.sqrt(3)/2 # a*sin(60 deg)
    a_d2 = a * 0.5  # a* cos(60 deg)

    b = edge_b
    b_sqrt3_d2 = b * Math.sqrt(3) / 2 # b*sin(60 deg)
    b_d2 = b * 0.5 # b* cos(60 deg)

    spectre_points = Vector[
        Complex(0                        , 0                            ), #// 1: - b
        Complex(a                        , 0                            ), #// 2: + a
        Complex(a +     a_d2             , 0 - a_sqrt3_d2               ), #// 3: + ~a
        Complex(a +     a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +         b_d2), #// 4: + ~b
        Complex(a +     a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +     b + b_d2), #// 5: + b
        Complex(a + a + a_d2 + b_sqrt3_d2, 0 - a_sqrt3_d2 +     b + b_d2), #// 6: + a
        Complex(a + a + a +    b_sqrt3_d2,                      b + b_d2), #// 7: + ~a
        Complex(a + a + a                ,                  b + b       ), #// 8: - ~b
        Complex(a + a + a    - b_sqrt3_d2,                  b + b - b_d2), #// 9: - ~b
        Complex(a + a + a_d2 - b_sqrt3_d2,     a_sqrt3_d2 + b + b - b_d2), #// 10: +~a
        Complex(a +     a_d2 - b_sqrt3_d2,     a_sqrt3_d2 + b + b - b_d2), #// 11: -a
        Complex(        a_d2 - b_sqrt3_d2,     a_sqrt3_d2 + b + b - b_d2), #// 12: -a
        Complex(0            - b_sqrt3_d2,                  b + b - b_d2), #// 13: -~a
        Complex(0                        ,                      b       )  #// 14: +~b
    ]
    # p spectre_points
    return spectre_points
end

SPECTRE_POINTS = get_spectre_points(Edge_a, Edge_b) # tile(Edge_a, Edge_b)
Mystic_SPECTRE_POINTS = get_spectre_points(Edge_b, Edge_a) # tile(Edge_b, Edge_a)
SPECTRE_QUAD = [3,5,7,11].map{|idx| SPECTRE_POINTS[idx]}

print("coef A = #{Edge_a}\t\tRatio(#{(Edge_a/(Edge_a + Edge_b)).round(4)})\n")
print("coef B = #{Edge_b}\t\tRatio(#{(Edge_b/(Edge_a + Edge_b)).round(4)})\n")
[["SPECTRE_POINTS =", SPECTRE_POINTS], ["Mystic_SPECTRE_POINTS =", Mystic_SPECTRE_POINTS]].each do |vName,v|
    print("#{vName} [\n")
    v.each{|c| print("\t\t\t(#{c.real.to_f.round(4)} + #{c.imag.to_f.round(4)}*i),\n")}
    print("]\n")
end



# Rotation matrix for Affine transform
# pre-computed rotation matrices for common angles in the Trot_memo hash,
# to avoid recomputing them. The trot function looks up or computes the rotation matrix for a given angle.
Trot_memo = {
    #  -30=> [Complex(Math.sqrt(3)/2, 0.5),   Complex(-0.5, Math.sqrt(3)/2 ), Complex(0.0)],
       0=> [Complex(1,0),                   Complex( 0,1),                   Complex(0.0)],
      30=> [Complex(Math.sqrt(3)/2, 0.5),   Complex(-0.5, Math.sqrt(3)/2 ), Complex(0.0)],
      60=> [Complex(0.5, Math.sqrt(3)/2),   Complex(-Math.sqrt(3)/2,  0.5 ),  Complex(0.0)],
     120=> [Complex(-0.5, Math.sqrt(3)/2),  Complex(-Math.sqrt(3)/2, -0.5 ),Complex(0.0)],
     180=> [Complex(-1.0, 0.0),             Complex(0.0, -1.0), Complex(0.0)],
     240=> [Complex(-0.5, -Math.sqrt(3)/2), Complex(Math.sqrt(3)/2, -0.5), Complex(0.0)],
}
def trot(degAngle)
    # """
    # degAngle: integer degree angle
    # """
    if  not Trot_memo.has_key? degAngle
        ang = (degAngle * Math::PI / 180 )
        c = Math.cos(ang)
        s = Math.sin(ang)
        Trot_memo[degAngle] = [Complex(c,s), Complex(-s,c), Complex(0,0)]
        p "trot_memo[#{degAngle}]=#{Trot_memo[degAngle]}"
    end
    return Trot_memo[degAngle]
end

IDENTITY =    [Complex( 1.0, 0), Complex(0, 1.0), Complex(0)] # == trot(0)
ReverseTrsf = [Complex(-1.0, 0), Complex(0, 1.0), 0] # @TODO: Not trot(180).  Instead of rotating 180 degrees, get a mirror image.

# The trot_inv function takes a rotation matrix and derives the angle it represents,
#  by calculating the inverse trigonometric functions on the matrix elements.
def trot_inv(t)
    # T: rotation matrix for Affine transform
    # p ["trot_inv(t)", t]
    degAngle1 = ( Math::atan2(t[0].imag, t[0].real) / Math::PI * 180).round.to_i
    degAngle1 += 360 if degAngle1 <= -180
    degAngle2 = ( Math::atan2(-t[1].real,t[1].imag) / Math::PI * 180).round.to_i
    if (degAngle1 == degAngle2) # self validate angle
        scaleY = 1
    elsif (degAngle1 == (-degAngle2))
        scaleY = -1
    elsif (degAngle1 == (180 - degAngle2)) or (degAngle2 == (180 - degAngle1))
        scaleY = -1
    elsif (degAngle1 == (degAngle2 - 180)) or (degAngle2 == (degAngle1 - 180))
        scaleY = -1
    else
        scaleY = -1
        p ["ValueError at trot_inv: degAngle1=#{degAngle1}, degAngle2=#{degAngle2}", [t[0].to_s, t[1].to_s], [[t[0].real.to_f, t[0].imag.to_f], [t[1].real.to_f, t[1].imag.to_f]]]
        raise ("ValueError at trot_inv: degAngle1.abs != degAngle2.abs")
    end

    return [degAngle1, scaleY]
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
    trPt = Complex(quad.real * trsf[0].real + quad.imag * trsf[1].real,
                   quad.real * trsf[0].imag + quad.imag * trsf[1].imag) + trsf[2]
    # p ["transPt",trsf ,quad,trPt]
    return trPt
end

# Affine 2-matrix multiply
# mul functions multiplies two transformation matrices to combine multiple transforms.
def mul(trsfA, trsfB)
    trsfAB = [
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
    # p ["mul(trsfA, trsfB)", trsfA, trsfB, trsfAB]
    return trsfAB
end

class Tile
    attr :label, :quad
    def initialize(label)
        # _: NO list of Tile coordinate points
        # label: Tile type used for shapes coloring
        # quad: Tile quad points
        @label = label
        @quad = SPECTRE_QUAD.dup
    end

    def forEachTile(tile_transformation, &drawer)
        # print("at Tile.drawPolygon #{@label} quad=#{@quad}")
        return drawer.call(tile_transformation, @label)
    end
end

class MetaTile
    attr :tiles, :transformations, :quad
    def initialize(tiles, transformations, quad=SPECTRE_QUAD.dup)
        """
        tiles: list of Tiles(No points)
        transformations: list of transformation matrices
        quad: MetaTile quad points
        """
        @tiles = tiles
        @transformations = transformations
        @quad = quad
    end

    def forEachTile(transformation, &drawer)
        """
        recursively expand MetaTiles down to Tiles and draw those
        """
        # TODO: parallelize?
        @tiles.zip(@transformations).each do |tile, trsf|
           tile.forEachTile((mul(transformation, trsf)), &drawer)
        end
    end
end

TILE_NAMES = ["Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma", "Phi", "Psi"]

def buildSpectreBase()
    tiles = {}
    TILE_NAMES.each do |label|
        tiles[label] = case label
        when "Gamma" then
            # special rule for Mystic == Gamma == Gamma1 + Gamma2"
            MetaTile.new([
                            Tile.new("Gamma1"),
                            Tile.new("Gamma2")
                        ],
                        [
                            IDENTITY.dup,
                            mul(
                                [IDENTITY[0],IDENTITY[1],SPECTRE_POINTS[8]],
                                trot(30)
                            )
                        ],
                        SPECTRE_QUAD.dup)
        else
            Tile.new(label)
        end
    end
    # print("tiles[Gamma]=#{tiles["Gamma"].transformations}\n")
    return tiles
end

def buildSupertiles(input_tiles)
    """
    iteratively build on current system of tiles
    input_tiles = current system of tiles, initially built with buildSpectreBase()
    """
    # First, use any of the nine-unit tiles in "tiles" to obtain a
    # list of transformation matrices for placing tiles within supertiles.
    quad = input_tiles["Delta"].quad

    total_angle = 0
    rotation =  trot(total_angle) # IDENTITY.copy() #
    transformations =  [rotation] # [IDENTITY.copy()]
    transformed_quad = quad.dup
    # p "at buildSupertiles transformed_quad = quad", transformed_quad
    [[  60, 3, 1],
     [   0, 2, 0],
     [  60, 3, 1],
     [  60, 3, 1],
     [   0, 2, 0],
     [  60, 3, 1],
     [-120, 3, 3]
    ].each do |angle, from, to|
        if angle != 0
            total_angle += angle
            rotation = trot(total_angle)
            transformed_quad = quad.map {|quad1| transPt(rotation, quad1)} # + trot[:,2]
        end
        # p "total_angle=#{total_angle} transformed_quad=#{transformed_quad} rotation=#{rotation} quad=#{quad}"
        ttrans = [IDENTITY[0].dup, IDENTITY[1].dup, transPt(transformations[-1], quad[from]) - transformed_quad[to]]
        # p "total_angle=#{total_angle} ttrans=#{ttrans} transformations[-1]=#{transformations[-1]}  quad[_from]=#{quad[from]} transformed_quad[_to,:]=#{transformed_quad[to]}"
        transformations.append(mul(ttrans, rotation))
    end

    transformations = transformations.map{|trsf| mul(ReverseTrsf, trsf)} # @TODO: Instead of rotating 180 degrees, get a mirror image.
    # p "transformations=#{[6,5,3,0].map{|i| transformations[i]}}"
    # p "quad=#{[2,1].map{|i| quad[i]}}"
    # @TODO: TOBE auto update svg transform.translate scaleY. failed by (SvgContens_drowSvg_transform_scaleY=spectreTiles["Delta"].transformations[0][0,0])

    # Now build the actual supertiles, labeling appropriately.
    super_quad =  [
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
        ["Gamma",  ["Pi",  "Delta", nil ,  "Theta", "Sigma", "Xi",  "Phi",    "Gamma"]],
        ["Delta",  ["Xi",  "Delta", "Xi",  "Phi",   "Sigma", "Pi",  "Phi",    "Gamma"]],
        ["Theta",  ["Psi", "Delta", "Pi",  "Phi",   "Sigma", "Pi",  "Phi",    "Gamma"]],
        ["Lambda", ["Psi", "Delta", "Xi",  "Phi",   "Sigma", "Pi",  "Phi",    "Gamma"]],
        ["Xi",     ["Psi", "Delta", "Pi",  "Phi",   "Sigma", "Psi", "Phi",    "Gamma"]],
        ["Pi",     ["Psi", "Delta", "Xi",  "Phi",   "Sigma", "Psi", "Phi",    "Gamma"]],
        ["Sigma",  ["Xi",  "Delta", "Xi",  "Phi",   "Sigma", "Pi",  "Lambda", "Gamma"]],
        ["Phi",    ["Psi", "Delta", "Psi", "Phi",   "Sigma", "Pi",  "Phi",    "Gamma"]],
        ["Psi",    ["Psi", "Delta", "Psi", "Phi",   "Sigma", "Psi", "Phi",    "Gamma"]]
    ].each do |label, substitutions|
        tiles[label] = MetaTile.new(
                        substitutions.filter{|subst| subst}.map{|subst| input_tiles[subst]},
                        substitutions.zip(transformations).filter{|subst,_| subst}.map{|subst, trsf| trsf},
                        super_quad
                    )
    end
    return tiles
end

#### main process ####
def buildSpectreTiles(n_ITERATIONS)
    tiles = buildSpectreBase()
    (n_ITERATIONS).times{ tiles = buildSupertiles(tiles)}
    return tiles
end

### drawing parameter data

Trot_inv_prof = {
    # -180=> 0,
    -150=> 0, # Gamma2
    -120=> 0,
    -90=> 0, # Gamma2
    -60=> 0,
    -30=> 0,  # Gamma2
    0=> 0,
    30=> 0,  # Gamma2
    60=> 0,
    90=> 0, # Gamma2
    120=> 0,
    150=> 0,  # Gamma2
    180=> 0,
    360=> 0 # Gamma2 total
}
def print_trot_inv_prof()
    print("transformation rotation profile(angle: count)={")
    p Trot_inv_prof
    return Trot_inv_prof
end

def get_color_array(tile_transformation, label)
    angle, _scale = trot_inv(tile_transformation)
    if not Trot_inv_prof.has_key? angle
        Trot_inv_prof[angle] = 0
    end
    Trot_inv_prof[angle] += 1
    if (label == 'Gamma2')
        Trot_inv_prof[360] += 1
        return       [0.25,0.25,0.25]
    else
        rgb = {
                -180=> [1.0, 0.0,   0],
                -120=> [0.9, 0.8,   0],
                -60=>  [0.9, 0.4, 0.4],
                0=>    [1.0,   0,   0],
                60=>   [0.4, 0.4, 0.9],
                120=>  [  0, 0.8, 0.9],
                180=>  [  0,   0, 1.0]
        }[angle]
        if rgb
            return rgb
        else
            p ["Inalid color {rgb} {label}, {tile_transformation}", rgb, label,tile_transformation, angle ]
        end
    end
    return [0.5,0.5,0.5]
end

start_time1 = Time.now
transformation_min_X = Float::INFINITY
transformation_min_Y = Float::INFINITY
transformation_max_X = -Float::INFINITY
transformation_max_Y = -Float::INFINITY
num_tiles = 0
tiles = buildSpectreTiles(N_ITERATIONS)
tiles["Delta"].forEachTile(IDENTITY) do |tile_transformation, label|
    _ = trot_inv(tile_transformation) # validate trasform rotation.
    transformation_min_X = [transformation_min_X, tile_transformation[2].real.to_f].min
    transformation_min_Y = [transformation_min_Y, tile_transformation[2].imag.to_f].min
    transformation_max_X = [transformation_max_X, tile_transformation[2].real.to_f].max
    transformation_max_Y = [transformation_max_Y, tile_transformation[2].imag.to_f].max
    num_tiles += 1
end
print("* #{N_ITERATIONS} Iterations, generated #{num_tiles} tiles\n")
tiles["Delta"].quad.each_with_index do |quad1, i|
    print(" quad[#{i}] = #{quad1.to_s}\t(#{quad1.real.to_f})+(#{quad1.imag.to_f})*i\n")
end
transformation_min_X = (transformation_min_X - Edge_a * 3 - Edge_b * 3).to_i
transformation_min_Y = (transformation_min_Y - Edge_a * 3 - Edge_b * 3).to_i
transformation_max_X = (transformation_max_X + Edge_a * 3 + Edge_b * 3).to_i
transformation_max_Y = (transformation_max_Y + Edge_a * 3 + Edge_b * 3).to_i
print("buildSpectreTiles process #{Time.now - start_time1}sec.\n")

start_time2 = Time.now
svgContens_drowSvg_transform_scaleY = N_ITERATIONS.even? ? 1 : -1
svgFileName= "spectre-tile#{Edge_a.truncate(1)}-#{Edge_b.truncate(1)}-#{N_ITERATIONS}.svg"

File.open(svgFileName, 'w') do |file|
    viewWidth = transformation_max_X - transformation_min_X
    viewHeight = transformation_max_Y - transformation_min_Y
    file.puts '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'
    file.puts " width=\"#{viewWidth}\" height=\"#{viewHeight}\" viewBox=\"#{transformation_min_X} #{transformation_min_Y} #{viewWidth} #{viewHeight}\">"
    file.puts '<defs>'
    file.puts '<path id="d0" d="M' + SPECTRE_POINTS.map{|pt2| pt2.real.to_f.to_s + "," + pt2.imag.to_f.to_s}.inject {|pts,pt1| pts + ' L' + pt1} +
            ' Z" stroke="gray" stroke-width="1.2"/>'
    file.puts '<path id="d1" d="M' + Mystic_SPECTRE_POINTS.map{|pt2| pt2.real.to_f.to_s + "," + pt2.imag.to_f.to_s}.inject {|pts,pt1| pts + ' L' + pt1} +
            ' Z" stroke="gray" stroke-width="1.2"/>'
    file.puts '</defs>'

    tiles["Delta"].quad.each_with_index do |quad1, i|
        file.puts "<rect x=\"#{quad1.real.to_f}\" y=\"#{quad1.imag.to_f}\"" +
        " width=\"#{(Edge_a + Edge_b)/1.1}\" height=\"#{(Edge_a + Edge_b)/1.1}\"" +
        ' r="8" fill="rgb(0,222,0)" fill-opacity="90%" />'
    end

    tiles["Delta"].forEachTile(IDENTITY) do |tile_transformation, label|
        trsf = tile_transformation
        degAngle = trot_inv(trsf)[0]
        if degAngle == degAngle
            file.puts '<circle cx="' + trsf[2].real.to_f.to_s + '" cy="' + trsf[2].imag.to_f.to_s +
                '" r="4" fill="' + (label == "Gamma2" ? 'rgb(128,8,8)' : 'rgb(66,66,66)') + '" fill-opacity="90%" />'
            file.puts '<use xlink:href="#' + (label != "Gamma2" ? 'd0' : 'd1') + '" x="0" y="0" ' +
                " transform=\"translate(#{trsf[2].real.to_f},#{trsf[2].imag.to_f}) rotate(#{degAngle}) scale(1,#{svgContens_drowSvg_transform_scaleY})\"" +
                ' fill="' + 'rgb(' + get_color_array(trsf, label).map{|c| (c*255).to_i }.join(",") + ")" +
                '" fill-opacity="50%" stroke="black" stroke-weight="0.1" />'
            file.puts '<text x="' + Edge_a.to_s + '" y="' + Edge_b.to_s + '"' +
                " transform=\"translate(#{trsf[2].real.to_f},#{trsf[2].imag.to_f}) rotate(#{degAngle- 60}) " +
                '" font-size="8">' + label + '</text>'
        end
    end
    file.puts '</svg>'
end
print(" each angle's tile count =\t#{Trot_inv_prof}\n") # count in get_color_array call
p "svg file write process #{Time.now - start_time2}sec"

p "total process time #{Time.now - start_time1}sec"
p "save filename=",svgFileName
