# frozen_string_literal: true
require 'matrix'

# =============================================================================
#
# This script calculates and validates the tile counts for each generation
# of a Spectre-tile-based aperiodic tiling. It employs two distinct methods:
#
# 1. Direct Substitution: A straightforward iterative application of tile
#    replacement rules, directly simulating the tiling's growth.
#    This method serves as a validation baseline.
#
# 2. Matrix-based Linear Recurrence Method:
# 2.1  Calculation by Second-Order Linear Recurrence Matrix;
#     A mathematically rigorous approach using a transition matrix
#    to solve a system of second-order linear recurrence relations.
#    This method leverages linear algebra to compute the sequences efficiently.
#
# 2.2  Calculation by First-Order Linear Recurrence Matrix;
#
# The script is structured to demonstrate that both methods yield identical results,
# confirming the correctness of the derived recurrence relations.
#
# =============================================================================

# --- Configuration ---
N_ITERATIONS = 14
DEBUG_TRACE_LABEL = 'Psi' # e.g., nil ro traceoff ;'Psi' to trace its calculation;

# =============================================================================
# Section 1: Direct Substitution Method for Validation
# =============================================================================

puts '--- Validation of Tile Counts by Direct Substitution ---'

# The set of unique tile labels used in the substitution system.
# Note: The original 'Gamma' tile is split into 'Gamma1' and 'Gamma2'
# for specific tracking purposes.
TILE_NAMES = %w[Gamma1 Gamma2 Delta Sigma Theta Lambda Pi Xi Phi Psi].freeze

# The substitution rules are derived from the geometric construction of the
# Spectre supertile, as described by discoverers :
# David Smith, Joseph Samuel Myers, Craig S. Kaplan, and Chaim Goodman-Strauss, 2023
# (https://cs.uwaterloo.ca/~csk/spectre/
#  https://arxiv.org/abs/2306.10767
# https://cs.uwaterloo.ca/~csk/spectre/app.html).

# Each parent tile is replaced by a specific arrangement of child tiles.
# 'nil' indicates an empty position within the supertile structure.
original_substitution_rules = [
  ['Gamma',  ['Pi', 'Delta', nil, 'Theta', 'Sigma', 'Xi', 'Phi', 'Gamma']],
  ['Delta',  %w[Xi Delta Xi Phi Sigma Pi Phi Gamma]],
  ['Theta',  %w[Psi Delta Pi Phi Sigma Pi Phi Gamma]],
  ['Lambda', %w[Psi Delta Xi Phi Sigma Pi Phi Gamma]],
  ['Xi',     %w[Psi Delta Pi Phi Sigma Psi Phi Gamma]],
  ['Pi',     %w[Psi Delta Xi Phi Sigma Psi Phi Gamma]],
  ['Sigma',  %w[Xi Delta Xi Phi Sigma Pi Lambda Gamma]],
  ['Phi',    %w[Psi Delta Psi Phi Sigma Pi Phi Gamma]],
  ['Psi',    %w[Psi Delta Psi Phi Sigma Psi Phi Gamma]]
]

# The geometric rules are converted into a frequency map (a hash).
# This represents a system of first-order difference equations, where the
# count of each tile at step `n` is a linear combination of all tile counts
# at step `n-1`.
substitution_rules = {}
original_substitution_rules.each do |parent, children|
  rule = Hash.new(0)
  children.compact.each { |child| rule[child] += 1 }
  substitution_rules[parent] = rule
end
# expected substitution_rules = {
#   'Gamma' => { 'Pi' => 1, 'Delta' => 1, 'Theta' => 1, 'Sigma' => 1, 'Xi' => 1, 'Phi' => 1, 'Gamma' => 1 },
#   'Delta' => { 'Xi' => 2, 'Delta' => 1, 'Phi' => 2, 'Sigma' => 1, 'Pi' => 1, 'Gamma' => 1 },
#   'Theta' => { 'Psi' => 1, 'Delta' => 1, 'Pi' => 2, 'Phi' => 2, 'Sigma' => 1, 'Gamma' => 1 },
#   'Lambda' => { 'Psi' => 1, 'Delta' => 1, 'Xi' => 1, 'Phi' => 2, 'Sigma' => 1, 'Pi' => 1, 'Gamma' => 1 },
#   'Xi' => { 'Psi' => 2, 'Delta' => 1, 'Pi' => 1, 'Phi' => 2, 'Sigma' => 1, 'Gamma' => 1 },
#   'Pi' => { 'Psi' => 2, 'Delta' => 1, 'Xi' => 1, 'Phi' => 2, 'Sigma' => 1, 'Gamma' => 1 },
#   'Sigma' => { 'Xi' => 2, 'Delta' => 1, 'Phi' => 1, 'Sigma' => 1, 'Pi' => 1, 'Lambda' => 1, 'Gamma' => 1 },
#   'Phi' => { 'Psi' => 2, 'Delta' => 1, 'Pi' => 1, 'Phi' => 2, 'Sigma' => 1, 'Gamma' => 1 },
#   'Psi' => { 'Psi' => 3, 'Delta' => 1, 'Phi' => 2, 'Sigma' => 1, 'Gamma' => 1 }
# }

# --- Initial Conditions ---

# Storage for the sequence of counts for each tile type.
tile_sequences = Hash.new { |h, k| h[k] = [] }

# At iteration n=0, the tiling starts from a single 'Delta' tile.
current_counts = Hash.new(0)
current_counts['Delta'] = 1
TILE_NAMES.each { |name| tile_sequences[name] << current_counts[name] }
puts "# Iteration 0 = #{current_counts}" if DEBUG_TRACE_LABEL

# At iteration n=1, the initial 'Delta' tile is substituted.
# This step requires special handling for the bifurcation of 'Gamma' into 'Gamma1' and 'Gamma2'.
prev_counts = current_counts
current_counts = { 'Gamma1' => 1, 'Gamma2' => 1, 'Delta' => 1, 'Sigma' => 1, 'Theta' => 0, 'Lambda' => 0, 'Pi' => 1, 'Xi' => 2, 'Phi' => 2, 'Psi' => 0 }
TILE_NAMES.each { |name| tile_sequences[name] << current_counts[name] }
puts "# Iteration 1 = #{current_counts}" if DEBUG_TRACE_LABEL

# --- Iterative Calculation (n >= 2) ---

prev_counts = current_counts
(2...N_ITERATIONS).each do |n|
  current_counts = Hash.new(0)
  substitution_rules.each do |label, rules|
    # The counts of Gamma1 and Gamma2 from the previous step are treated
    # as a single 'Gamma' pool for substitution purposes.
    count = (label == 'Gamma') ? prev_counts['Gamma1'] : prev_counts[label]

    rules.each do |sub_label, sub_count|
      if sub_label == 'Gamma'
        # When a 'Gamma' tile is produced, it contributes to both Gamma1 and Gamma2 counts.
        current_counts['Gamma1'] += count * sub_count
        current_counts['Gamma2'] += count * sub_count
        puts " Debug: #{label} -> #{sub_label}, prev_counts[#{label}]: #{count}, sub_count: #{sub_count}, adds:#{count * sub_count}, current_counts[#{sub_label}]: #{current_counts['Gamma2']} " if sub_label == DEBUG_TRACE_LABEL
        # at Section 2.2 : recurrence_matrix[labels.index('Gamma1'), labels.index(label)] = recurrence_matrix[labels.index('Gamma2'), labels.index(label)] = sub_count
      else
        current_counts[sub_label] += count * sub_count
        puts " Debug: #{label} -> #{sub_label}, prev_counts[#{label}]: #{count}, sub_count: #{sub_count}, adds:#{count * sub_count}, current_counts[#{sub_label}]: #{current_counts[sub_label]} " if sub_label == DEBUG_TRACE_LABEL
        # at Section 2.2 : recurrence_matrix[labels.index(sub_label), labels.index(label)] = sub_count
        current_counts['Gamma1'] += count * sub_count if label == 'Gamma'
      end
    end
  end

  TILE_NAMES.each { |name| tile_sequences[name] << current_counts[name] }
  puts "# Iteration #{n} = #{current_counts.select { |_, v| v > 0 }}" if DEBUG_TRACE_LABEL
  prev_counts = current_counts
end

# --- Display Validation Results ---
puts "\n--- Substitution Results by Tile ---"
TILE_NAMES.each do |name|
  puts "# #{name} = [#{tile_sequences[name].join(', ')}]"
end

# =============================================================================
# Section 2: Matrix-based Linear Recurrence Method
# =============================================================================

# The state vector includes the primary tiles plus two auxiliary sequences
# required to solve the system of recurrence relations.
labels = TILE_NAMES + ['_Pi_Xi', '_even']
VEC_SIZE = labels.length

# The system of recurrences is expressed in a state-space representation.
# The state vector at step `n` is `S(n) = [v(n-1), v(n-2)]^T`.
# A transition matrix `M` advances the state: `S(n+1) = M * S(n)`.
# This formulation allows us to solve a system of coupled, second-order
# linear recurrence relations using matrix exponentiation.
# The recurrence_matrix `M` is structured as:
# M = [ A  B ]
#     [ I  0 ]
# where v(n) = A*v(n-1) + B*v(n-2).
[
  ["# 2.1 : Calculation by Second-Order Linear Recurrence Matrix",
   Matrix[
  # Recurrence: a(n) = 8*a(n-1) - a(n-2). See OEIS A001090.
  [8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma1
  [0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma2
  [0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Delta
  [0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0], # Sigma
  [0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0], # Theta
  [0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0], # Lambda
  # Non-homogeneous recurrences are handled using auxiliary sequences.
  # Pi(n) = 8*_Pi_Xi(n-1) - _Pi_Xi(n-2) + _even(n-1)
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0], # Pi
  # Xi(n) = 8*_Pi_Xi(n-1) - _Pi_Xi(n-2) + _even(n-2)
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1], # Xi
  # Phi(n) = 8*Phi(n-1) - Phi(n-2)
  [0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0], # Phi
  # Psi(n) = 8*Psi(n-1) - Psi(n-2) + 6. The constant term `6` is modeled as
  # 6 * _even(n-1) + 6 * _even(n-2), which equals 6 for n >= 2.
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 6], # Psi
  # Auxiliary sequence _Pi_Xi follows the base recurrence. See OEIS A341927.
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0], # _Pi_Xi
  # Auxiliary sequence _even generates [0, 1, 0, 1, ...], satisfying a(n) = a(n-2).
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]  # _even
]],
[ "# 2.2 : Calculation by First-Order Linear Recurrence Matrix",
  Matrix[
  [1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma1
  [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Gamma2
  [1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Delta
  [1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Sigma
  [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Theta
  [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Lambda
  [1, 0, 1, 1, 2, 1, 0, 1, 1, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Pi
  [1, 0, 2, 2, 0, 1, 1, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Xi
  [1, 0, 2, 1, 2, 2, 2, 2, 2, 2, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Phi
  [0, 0, 0, 0, 1, 1, 2, 2, 2, 3, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # Psi
  # Auxiliary sequence recurrence: Not used
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-1, 0], # _Pi_Xi: [0, 1, 6, 8* _Pi_Xi(n-1) - _Pi_Xi(n-2)]; https://oeis.org/A341927
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1] # _even: _even(n) = 0 * _even(n-1) + _even(n-2)
]
]
].each do |title, recurrence_matrix|
  puts "\n---begin #{title}---"
# The state vector includes the primary tiles plus two auxiliary sequences
# required to solve the system of recurrence relations.

# The initial state vectors v(0), v(1), and v(2) serve as base cases.
# The values are derived from the substitution process for the first few steps.
v = [
  [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0], # v(0) as 1 tile of spectre(labeled Delta).
  [1, 1, 1, 1, 0, 0, 1, 2, 2, 0, 1, 1], # v(1) as 9 tile of spectres.
  [8, 8, 8, 8, 1, 1, 7, 6, 14, 10, 6, 0] # v(2) as 71 tile of spectres for v(0)==v(1)==0.
]

# --- Matrix Calculation Loop (n >= 3) ---
(3..N_ITERATIONS).each do |i|
  # Form the state vector S(i) = [v(i-1), v(i-2)]^T
  state_vector = Matrix[v[-1] + v[-2]]

  # Calculate the next vector v(i) by multiplying by the transition matrix.
  # v(i) is the first half of the resulting state vector S(i+1).
  next_vector = (state_vector * recurrence_matrix.transpose).row(0).to_a

  v << next_vector
end

# --- Display Matrix Results ---
puts "\n--- Recurrence Results by Iteration ---"
display_labels = labels.reject { |label| label.start_with?('_') }
v.each_with_index do |vec, i|
  filtered_values = display_labels.zip(vec[0...display_labels.size]).reject { |_, value| value.zero? }
  hash = filtered_values.to_h
  hash[:_total] = hash.values.sum
  puts "# Iteration #{i} = #{hash}"  if DEBUG_TRACE_LABEL
end

puts "\n--- Recurrence Results by Tile ---"
v.transpose.each_with_index do |vec, i|
  puts "# #{labels[i]} = [#{vec.join(', ')}]"
end
puts "\n---end #{title}---"
end

# excepted output:

#--- Recurrence Results by Iteration ---
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

#--- Recurrence Results by Tile ---
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
