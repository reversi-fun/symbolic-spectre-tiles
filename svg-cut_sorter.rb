$min_x = Float::INFINITY
$min_y = Float::INFINITY
$max_x = -Float::INFINITY
$max_y = -Float::INFINITY
def is_in_rect?(x, y, x1, y1, x2, y2)
  $min_x = x if $min_x > x
  $min_y = y if $min_y > y
  $max_x = x if $max_x < x
  $max_y = y if $max_y < y
  x >= x1 && x <= x2 && y >= y1 && y <= y2
end

def is_in_rect_svgline(line, x1, y1, x2, y2)
  if line =~ /"translate\(/
    x, y = line.match(/translate\(([^,]+),([^)]+)/)&.captures&.map { |z| z.to_f }
    # p ["translate",x,y]
    [is_in_rect?(x, y, x1, y1, x2, y2), [x, y]]
  elsif line =~ /<circle/
    cx, cy = line.match(/cx="([^"]+)"\s+cy="([^"]+)"/)&.captures&.map { |z| z.to_f }
    #  p ["circle",cx,cy]
    [is_in_rect?(cx, cy, x1, y1, x2, y2), [cx, cy]]
  elsif line =~ /<text/
    x, y = line.match(/x="([^"]+)"\s+y="([^"]+)"/)&.captures&.map { |z| z.to_f }
    [is_in_rect?(x, y, x1, y1, x2, y2), [x, y]]
  elsif line =~ /<rect/
    x, y = line.match(/x="([^"]+)"\s+y="([^"]+)"/)&.captures&.map { |z| z.to_f }
    p ['rect point X,Y', x, y]
    [is_in_rect?(x, y, x1, y1, x2, y2), [x, y]]
  elsif line =~ /<polygon/
    points = line.match(/points="([^"]+)"/).captures[0].split(/\s+/).map { |xy| xy.split(',').map { |z| z.to_f } }
    # p ["points",  points]
    [points&.any? { |x, y| is_in_rect?(x, y, x1, y1, x2, y2) }, points]
  else
    [nil, []]
  end
end

def main(input_file_path, output_file_path, x1, y1, x2, y2, _dx)
  svg_headBuf = []
  svg_bodyBuf = []
  svg_tailBuf = []
  File.open(input_file_path, 'r') do |inFile|
    line_progress = :atHeaders
    inFile.each_line do |line|
      # p line_progress, line
      if line_progress == :atHeaders
        line.gsub!(/\sviewBox="[^"]*"/, " viewBox=\"#{x1} #{y1} #{x2 - x1} #{y2 - y1}\"") if line =~ /\sviewBox=/
        line.gsub!(/\swidth="[^"]*"/, " width=\"#{x2 - x1}\"") if line =~ /\swidth=/
        line.gsub!(/\sheight="[^"]*"/, " height=\"#{y2 - y1}\"") if line =~ /\sheight=/
        svg_headBuf.push line
        line_progress = :atBody if line =~ %r{</defs>}
      elsif line_progress == :atBody
        whatAddr = is_in_rect_svgline(line, x1, y1, x2, y2)
        if whatAddr[0]
          svg_bodyBuf.push [whatAddr[1], line]
        elsif whatAddr[0].nil? && whatAddr[1][0].nil? && line =~ %r{</svg>}
          svg_tailBuf.push line
          line_progress = :atTail
        end
      elsif line_progress == :atTail
        svg_tailBuf.push line
      end
    end
  end
  p [svg_headBuf.length, svg_bodyBuf.length, svg_tailBuf.length]
  svg_bodyBuf.sort_by! { |w| [w[0][1], w[0][0]] }
  File.open(output_file_path, 'w') do |outFile|
    svg_headBuf.each { |line| outFile.puts line }
    svg_bodyBuf.each { |_whatAddr, line| outFile.puts line }
    svg_tailBuf.each { |line| outFile.puts line }
  end
  print("input range=(#{$min_x},#{$min_y})-(#{$max_x},#{$max_y})\n")
end

if __FILE__ == $0
  input_file_path = ARGV[0]
  input_file_basename = File.basename(input_file_path, '.*')
  x1 = ARGV[1].to_f.to_i
  y1 = ARGV[2].to_f.to_i
  x2 = ARGV[3].to_f.to_i
  y2 = ARGV[4].to_f.to_i
  output_file_name = "#{input_file_basename}_(#{x1},#{y1})-(#{x2},#{y2})-sorted.svg"
  dx = ARGV[5].to_i || 5
  main(input_file_path, output_file_name, x1, y1, x2, y2, dx)
  print("output file = \"#{output_file_name}\"")
end
