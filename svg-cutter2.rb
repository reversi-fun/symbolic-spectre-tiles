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
    is_in_rect?(x, y, x1, y1, x2, y2)
  elsif line =~ /<circle/
    cx, cy = line.match(/cx="([^"]+)"\s+cy="([^"]+)"/)&.captures&.map { |z| z.to_f }
    #  p ["circle",cx,cy]
    is_in_rect?(cx, cy, x1, y1, x2, y2)
  elsif line =~ /<text/
    x, y = line.match(/x="([^"]+)"\s+y="([^"]+)"/)&.captures&.map { |z| z.to_f }
    is_in_rect?(x, y, x1, y1, x2, y2)
  elsif line =~ /<rect/
    x, y = line.match(/x="([^"]+)"\s+y="([^"]+)"/)&.captures&.map { |z| z.to_f }
    p ['rect point X,Y', x, y]
    is_in_rect?(x, y, x1, y1, x2, y2)
  elsif line =~ /<polygon/
    points = line.match(/points="([^"]+)"/).captures[0].split(/\s+/).map { |xy| xy.split(',').map { |z| z.to_f } }
    # p ["points",  points]
    points&.any? { |x, y| is_in_rect?(x, y, x1, y1, x2, y2) }
  else
    true
  end
end

def main(input_file_path, output_file_path, x1, y1, x2, y2, dx)
  File.open(output_file_path, 'w') do |outFile|
    File.open(input_file_path, 'r') do |inFile|
      in_defs_group = false
      inFile.each_line do |line|
        # p line
        in_defs_group = true if line =~ /<defs>/
        in_defs_group = false if line =~ %r{</defs>}
        if in_defs_group
          outFile.puts line
        else
          line.gsub!(/\sviewBox="[^"]*"/, " viewBox=\"#{x1} #{y1} #{x2 - x1} #{y2 - y1}\"") if line =~ /\sviewBox=/
          line.gsub!(/\swidth="[^"]*"/, " width=\"#{x2 - x1}\"") if line =~ /\swidth=/
          line.gsub!(/\sheight="[^"]*"/, " height=\"#{y2 - y1}\"") if line =~ /\sheight=/
          outFile.puts line if is_in_rect_svgline(line, x1, y1, x2, y2)
          if line =~ /<g/
            outFile.puts "<rect x=\"#{x1}\" y=\"#{y1}\" width=\"#{x2 - x1}\" height=\"#{y2 - y1}\" stroke=\"#1600FC\" stroke-width=\"2\" fill=\"#BCE1DF\" />"
            (dx - 1).times do |i|
              outFile.puts "<line x1=\"#{x1 + (x2 - x1) * (i + 1) / dx}\" y1=\"#{y1}\" x2=\"#{x1 + (x2 - x1) * (i + 1) / dx}\" y2=\"#{y2}\" stroke=\"black\" />"
            end
          end
        end
      end
    end
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
  output_file_name = "#{input_file_basename}_(#{x1},#{y1})-(#{x2},#{y2}).svg"
  dx = ARGV[5].to_i || 5
  main(input_file_path, output_file_name, x1, y1, x2, y2, dx)
  print("output file = \"#{output_file_name}\"")
end
