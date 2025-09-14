require 'matrix'
# This script generates a set of sequences related to aperiodic tilings.
# The sequences are calculated using a second-order linear recurrence relation
# encapsulated within an expanded state-space representation.
# This approach is mathematically rigorous and avoids direct manipulation of constants.

# Labels for the 12 sequences, including a custom auxiliary sequence "_even".
# The "_even" sequence, which alternates between 1 and 0, is a key component
# for handling the non-homogeneous parts of the recurrence relations.
labels = ["Gamma1", "Gamma2", "Delta", "Sigma",  "Theta", "Lambda", "Pi", "Xi",  "Phi", "Psi", "_Pi_Xi", "_even"]

# The size of our state vector.
VEC_SIZE = labels.length

# The initial state vectors, v0 and v1. These serve as the base cases for the recurrence.
# The order of the elements corresponds to the `labels` array.
v = [
  [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0], # v(0)
  [1, 1, 1, 1, 0, 0, 1, 2, 2, 0, 1, 1], # v(1)
  [8, 8, 8, 8, 1, 1, 7, 6,14,10, 6, 0]  # v(2) - manually set for the recurrence start for v(0)==v(1)==0
]

# The transition matrix T, which defines the linear recurrence relation.
# It operates on a combined state vector of [v(n-1), v(n-2)].
# The matrix coefficients are derived from the recurrence relations for each sequence.
#
# The matrix has dimensions (VEC_SIZE*2) x (VEC_SIZE*2) and is structured as:
#
#   [ v(n-1) -> v(n) | v(n-2) -> v(n) ]
#   [   I           |       0          ]
#
# This structure enables the calculation of v(n) while simultaneously shifting
# v(n-1) to the v(n-2) position for the next iteration.
#
# The coefficients for each sequence's recurrence are placed in the appropriate rows.
M = Matrix[
  # Recurrence: a(n) = 8*a(n-1) - a(n-2) ; https://oeis.org/A001090
  [8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma1
  [0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma2
  [0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Delta
  [0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0], # Sigma
  [0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0], # Theta
  [0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0], # Lambda
  # Recurrence with non-homogeneous terms
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 1,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-1, 0], # Pi: Pi(n) = 8* _Pi_Xi(n-1) - _Pi_Xi(n-2) + _even(n-1)
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-1, 1], # Xi: Xi(n) = 8* _Pi_Xi(n-1) - _Pi_Xi(n-2) + _even(n-2)
  [0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,-1, 0, 0, 0], # Phi; {Phi - Psi} = [2 , 4, 24, 182 , 1426 , 11220] == [A144479] + 1 ; [A144479](n) = [A001090](n+1)-5*[A001090](n).
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 6,   0, 0, 0, 0, 0, 0, 0, 0, 0,-1, 0, 6], # Psi: Psi(n) = 8*Psi(n-1) - Psi(n-2) + 6(1: _even(n-1) + _even(n-2)); related to https://oeis.org/A144479
  # Auxiliary sequence recurrence
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-1, 0], # _Pi_Xi: [0, 1, 6, 8* _Pi_Xi(n-1) - _Pi_Xi(n-2)]; https://oeis.org/A341927
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], # _even: _even(n) = 0 * _even(n-1) + _even(n-2)
]

# The main loop performs the recurrence for the desired number of iterations.
(3..14).each do |i|
  # Concatenate the previous two vectors to form the state vector for the next iteration.
  state_vector = Matrix[v[-1] + v[-2]]

  # Calculate the next vector using matrix multiplication.
  next_vector = (state_vector * M.transpose).row(0).to_a

  # Append the new vector to the sequence history.
  v << next_vector
end

# Display the results
puts "---"
puts "Display the results: tile_counts_by_iteration"
puts "---"
v.transpose.each_with_index do |vec, i|
  puts "# #{labels[i]} = [#{vec.join(', ')}]"
end

# Display the results in a hash format for each iteration

puts "---"
puts "Display the results in a hash format for each iteration"
puts "---"
display_labels = labels.reject { |label| label.start_with?('_') }
v.each_with_index do |vec, i|
  # Create a hash from the labels and values, filtering out zero-value entries
  # and adding the total sum of the displayed values.
  filtered_values = display_labels.zip(vec[0..(display_labels.size-1)]).reject { |_, value| value == 0 }
  total = filtered_values.map { |_, value| value }.sum
  hash = filtered_values.to_h
  hash[:_total] = total
  puts "# Iteration #{i} = #{hash}"
end

# Expected Output:
# Display the results: tile_counts_by_iteration
# Gamma1 = [0, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673, 453811015736]
# Gamma2 = [0, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673, 453811015736]
# Delta = [1, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673, 453811015736]
# Sigma = [0, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673, 453811015736]
# Theta = [0, 0, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673]
# Lambda = [0, 0, 1, 8, 63, 496, 3905, 30744, 242047, 1905632, 15003009, 118118440, 929944511, 7321437648, 57641556673]
# Pi = [0, 1, 7, 47, 371, 2913, 22935, 180559, 1421539, 11191745, 88112423, 693707631, 5461548627, 42998681377, 338527902391]
# Xi = [0, 2, 6, 48, 370, 2914, 22934, 180560, 1421538, 11191746, 88112422, 693707632, 5461548626, 42998681378, 338527902390]
# Phi = [0, 2, 14, 110, 866, 6818, 53678, 422606, 3327170, 26194754, 206230862, 1623652142, 12782986274, 100640238050, 792338918126]
# Psi = [0, 0, 10, 86, 684, 5392, 42458, 334278, 2631772, 20719904, 163127466, 1284299830, 10111271180, 79605869616, 626735685754]
# _Pi_Xi = [0, 1, 6, 47, 370, 2913, 22934, 180559, 1421538, 11191745, 88112422, 693707631, 5461548626, 42998681377, 338527902390]
# _even = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]

# Display the results in a hash format for each iteration
# Iteration 0 = {"Delta"=>1, :_total=>1}
# Iteration 1 = {"Gamma1"=>1, "Gamma2"=>1, "Delta"=>1, "Sigma"=>1, "Pi"=>1, "Xi"=>2, "Phi"=>2, :_total=>9}
# Iteration 2 = {"Gamma1"=>8, "Gamma2"=>8, "Delta"=>8, "Sigma"=>8, "Theta"=>1, "Lambda"=>1, "Pi"=>7, "Xi"=>6, "Phi"=>14, "Psi"=>10, :_total=>71}
# Iteration 3 = {"Gamma1"=>63, "Gamma2"=>63, "Delta"=>63, "Sigma"=>63, "Theta"=>8, "Lambda"=>8, "Pi"=>47, "Xi"=>48, "Phi"=>110, "Psi"=>86, :_total=>559}
# Iteration 4 = {"Gamma1"=>496, "Gamma2"=>496, "Delta"=>496, "Sigma"=>496, "Theta"=>63, "Lambda"=>63, "Pi"=>371, "Xi"=>370, "Phi"=>866, "Psi"=>684, :_total=>4401}
# Iteration 5 = {"Gamma1"=>3905, "Gamma2"=>3905, "Delta"=>3905, "Sigma"=>3905, "Theta"=>496, "Lambda"=>496, "Pi"=>2913, "Xi"=>2914, "Phi"=>6818, "Psi"=>5392, :_total=>34649}
# Iteration 6 = {"Gamma1"=>30744, "Gamma2"=>30744, "Delta"=>30744, "Sigma"=>30744, "Theta"=>3905, "Lambda"=>3905, "Pi"=>22935, "Xi"=>22934, "Phi"=>53678, "Psi"=>42458, :_total=>272791}
# Iteration 7 = {"Gamma1"=>242047, "Gamma2"=>242047, "Delta"=>242047, "Sigma"=>242047, "Theta"=>30744, "Lambda"=>30744, "Pi"=>180559, "Xi"=>180560, "Phi"=>422606, "Psi"=>334278, :_total=>2147679}
# Iteration 8 = {"Gamma1"=>1905632, "Gamma2"=>1905632, "Delta"=>1905632, "Sigma"=>1905632, "Theta"=>242047, "Lambda"=>242047, "Pi"=>1421539, "Xi"=>1421538, "Phi"=>3327170, "Psi"=>2631772, :_total=>16908641}
# Iteration 9 = {"Gamma1"=>15003009, "Gamma2"=>15003009, "Delta"=>15003009, "Sigma"=>15003009, "Theta"=>1905632, "Lambda"=>1905632, "Pi"=>11191745, "Xi"=>11191746, "Phi"=>26194754, "Psi"=>20719904, :_total=>133121449}
# Iteration 10 = {"Gamma1"=>118118440, "Gamma2"=>118118440, "Delta"=>118118440, "Sigma"=>118118440, "Theta"=>15003009, "Lambda"=>15003009, "Pi"=>88112423, "Xi"=>88112422, "Phi"=>206230862, "Psi"=>163127466, :_total=>1048062951}
# Iteration 11 = {"Gamma1"=>929944511, "Gamma2"=>929944511, "Delta"=>929944511, "Sigma"=>929944511, "Theta"=>118118440, "Lambda"=>118118440, "Pi"=>693707631, "Xi"=>693707632, "Phi"=>1623652142, "Psi"=>1284299830, :_total=>8251382159}
# Iteration 12 = {"Gamma1"=>7321437648, "Gamma2"=>7321437648, "Delta"=>7321437648, "Sigma"=>7321437648, "Theta"=>929944511, "Lambda"=>929944511, "Pi"=>5461548627, "Xi"=>5461548626, "Phi"=>12782986274, "Psi"=>10111271180, :_total=>64962994321}
# Iteration 13 = {"Gamma1"=>57641556673, "Gamma2"=>57641556673, "Delta"=>57641556673, "Sigma"=>57641556673, "Theta"=>7321437648, "Lambda"=>7321437648, "Pi"=>42998681377, "Xi"=>42998681378, "Phi"=>100640238050, "Psi"=>79605869616, :_total=>511452572409}
# Iteration 14 = {"Gamma1"=>453811015736, "Gamma2"=>453811015736, "Delta"=>453811015736, "Sigma"=>453811015736, "Theta"=>57641556673, "Lambda"=>57641556673, "Pi"=>338527902391, "Xi"=>338527902390, "Phi"=>792338918126, "Psi"=>626735685754, :_total=>4026657584951}
