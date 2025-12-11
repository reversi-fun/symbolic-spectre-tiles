# filename= my_spectre_coordinateAnalyzer_base_interface.rb
# frozen_string_literal: true

# ====================================================================
# SpectreCoordinateAnalyzerBaseInterface
#
# 実験的なコード群 (hybrid, keyed, etc.) から抽出された共通機能と
# 最も洗練された実装（精度向上版）を集約したインターフェース定義ファイル。
# ====================================================================

require 'matrix'
require 'set'

# 高精度PCA用：条件付きrequire
begin
  require_relative 'HighPrecisionMath/HighPrecisionMath'
  HIGHPRECISION_AVAILABLE = true
rescue LoadError
  HIGHPRECISION_AVAILABLE = false
end

module SpectreMath
  module_function

  # ====================================================================
  # MathContext シングルトンレジストリ
  # 型（クラス名）ごとに数学定数を管理し、引数の型に応じて適切な値を返す
  # ====================================================================

  # クラス名 => { 定数名 => Proc } のハッシュ
  @@math_contexts = {}

  # 定数名の定義（標準化された名前）
  SINGULARITY_THRESHOLD = :singularity_threshold # 数値的特異性回避用（ゼロ判定）
  CONVERGENCE_EPSILON = :convergence_epsilon   # 反復計算の収束判定用
  GEOMETRIC_TOLERANCE = :geometric_tolerance   # 幾何学的許容誤差

  # 型ごとの数学定数を登録
  # @param class_names [Array<String>] クラス名のリスト（例: ["BigDecimal", "Float"]）
  # @param context_procs [Hash<String, Proc>] 定数名: Proc のハッシュ
  #
  # 使用例:
  #   SpectreMath.register_math_context(
  #     ["BigDecimal"],
  #     singularity_threshold: BigDecimal('10') ** (-(HighPrecisionMath.precision * 0.9).to_i),
  #     convergence_epsilon: BigDecimal('10') ** (-(HighPrecisionMath.precision * 0.8).to_i),
  #     geometric_tolerance: BigDecimal('1e-160')
  #   )
  def register_math_context(class_names,
  singularity_threshold:,  # 数値的特異性回避用（ゼロ判定）
  convergence_epsilon:,   # 反復計算の収束判定用
  geometric_tolerance:   # 幾何学的許容誤差
  )
    context_procs = {
      singularity_threshold: singularity_threshold.nil? ? nil : singularity_threshold.respond_to?(:call) ? singularity_threshold : -> { singularity_threshold },
      convergence_epsilon: convergence_epsilon.nil? ? nil : convergence_epsilon.respond_to?(:call) ? convergence_epsilon : -> { convergence_epsilon },
      geometric_tolerance: geometric_tolerance.nil? ? nil : geometric_tolerance.respond_to?(:call) ? geometric_tolerance : -> { geometric_tolerance }
    }
    class_names.each do |class_name|
      @@math_contexts[class_name] ||= {}
      [:singularity_threshold,:convergence_epsilon, :geometric_tolerance ].each do |const_name_symbol|
        if context_procs[const_name_symbol]
          @@math_contexts[class_name][const_name_symbol] = context_procs[const_name_symbol]
        end
      end
    end
  end

  # 型に応じた数学定数を取得
  # @param class_name [String] クラス名（例: "BigDecimal", "Float"）
  # @param const_name [String] 定数名（:singularity_threshold, :convergence_epsilon, :geometric_tolerance）
  # @return [Numeric] 定数値
  #
  # 使用例:
  #   tolerance = SpectreMath.get_math_context(pt.class.name, SpectreMath::GEOMETRIC_TOLERANCE)
  def get_math_context(class_name, const_name)
    context = @@math_contexts[class_name]
    unless context   # 未登録の型の場合、停止
      raise ArgumentError, "⚠️ 警告: #{class_name} の MathContext が未登録です。"
    end

    proc_or_value = context[const_name]
    unless proc_or_value
      raise ArgumentError, "定数名 '#{const_name}' は #{class_name} の MathContext に登録されていません。"
    end

    # Procを呼び出して最新の値を取得
    proc_or_value.call
  end

  # デバッグ用: 登録されているすべてのコンテキストを表示
  def list_math_contexts
    @@math_contexts.each do |class_name, context|
      puts "#{class_name}:"
      context.each do |const_name, proc|
        puts "  #{const_name}: #{proc.call}"
      end
    end
  end

  # --- ベクトル・行列演算 ---


  def mean_vector(data)
    cols = data.transpose
    cols.map { |col| col.sum / col.size.to_f }
  end

  def center_data(data)
    mean = mean_vector(data)
    data.map { |row| row.zip(mean).map { |x, m| x - m } }
  end

  def outer_product(v1, v2)
    Matrix.rows(v1.to_a.map { |x| v2.to_a.map { |y| x * y } })
  end

  def covariance_matrix(data)
    centered = center_data(data)
    m = Matrix[*centered]
    (m.transpose * m) / data.size.to_f
  end

  def rmse(vectors)
    return 0.0 if vectors.empty?
    Math.sqrt(vectors.map { |v| v.map { |x| x**2 }.sum }.sum / vectors.size.to_f)
  end

  def normalize(v)
    mag = Math.sqrt(v.map { |x| x**2 }.sum)
    return v if mag.zero?
    v.map { |x| x / mag }
  end

  def orthogonalize(v1, v2)
    dot = v1.zip(v2).map { |a, b| a * b }.sum
    scale = dot / v1.map { |x| x**2 }.sum
    v2.zip(v1).map { |b, a| b - scale * a }
  end

  # --- PCA (主成分分析) ---

  # 機能概要: 主成分分析を行い、共分散行列の小さい固有値に対応するn個の固有ベクトルを返す。
  # Input: data (Array<Array<Numeric>>), n_components (Integer), key (String/Optional for debug)
  # Output: Array<Array<Numeric>> 1e-6以下で概ね０に近い固有値に対応する固有ベクトルで、2行３列の行列。
  def pca_components(data, n_components = 2, key = "")
    return [] if data.empty?

    m = data.size
    # 高速化のため、Matrixオブジェクトを介さずに共分散行列を計算
    mean = Vector.elements(data.transpose.map { |col| col.sum / m.to_f })
    centered = data.map { |row| Vector.elements(row) - mean }
    cov = Matrix.zero(4)
    centered.each { |v| cov += outer_product(v, v) }
    cov /= m.to_f

    eig = cov.eigen

    # 固有値の絶対値で昇順ソート（小さい順）
    sorted = eig.eigenvalues.zip(eig.eigenvectors)
                .sort_by { |val, _| val.abs }

    # 小さい固有値に対応する固有ベクトルと固有値を抽出
    extracted = sorted.first(n_components)
    components = extracted.map { |_, vec| vec.to_a }
    eigenvalues = extracted.map { |val, _| val }

    [components, eigenvalues]
  end

  # --- 連分数展開 (Continued Fraction) ---
  # --- 連分数展開 (Continued Fraction) ---
  # 符号を最初の要素（"+" または "-"）として分離し、
  # 第2要素以降に非負の整数（絶対値）を格納する形式に変更
  def self.continued_fraction(val, max_terms: 20)
    # 値が数値でない、または無限大/NaNの場合はエラーシンボルを返す
    return [:error] unless val.is_a?(Numeric) && val.finite?

    # --- 1. 符号の分離 ---
    sign = (val >= 0) ? "+" : "-"
    x_abs = val.abs

    eps = SpectreMath.get_math_context(val.class.name, :convergence_epsilon)

    # 整数に近い場合は即座に終了 (絶対値で判定)
    if (x_abs - x_abs.round).abs < eps
        # [符号, 整数値] を返す
        return [sign, x_abs.round]
    end

    coeffs = []
    x = x_abs # 正の値から展開を開始

    max_terms.times do
        i = x.floor # i は常に非負
        coeffs << i
        x = x - i

        if x.abs < eps
            break
        end

        begin
            # ここでは正の値の逆数を取るため、xは必ず正
            x = 1.0 / x
        rescue ZeroDivisionError
            break
        end

        # 発散チェック
        if x.abs > 1.0/eps
            # 発散項は通常省略
            break
        end
    end

    # [符号, a0, a1, a2, ...] の形式で返す
    return [sign] + coeffs
  end

  # 連分数からの復元
  # --- 連分数からの復元 ---
  # [符号, a0, a1, a2, ...] の形式から復元
  def self.continued_fraction_to_decimal(coeffs, target_type = BigDecimal)
    # インスタンス化ヘルパー (BigDecimal.new は廃止されたため Kernel.BigDecimal 等を使用)
    to_target = ->(val) {
      if target_type == BigDecimal
        BigDecimal(val.to_s)
      elsif target_type == Float
        val.to_f
      elsif target_type == Integer
        val.to_i
      else
        target_type.new(val)
      end
    }

    return to_target.call('0') if coeffs.nil? || coeffs.empty? || coeffs == [:error]

    # --- 1. 符号と係数の分離 ---
    sign = coeffs.first.to_s
    # 係数リスト (a0, a1, ...) は第2要素以降
    abs_coeffs = coeffs[1..-1]

    if abs_coeffs.nil? || abs_coeffs.empty?
        # 符号のみで係数がない場合（例：[+/-]）
        return to_target.call('0')
    end

    # --- 2. 正の値として復元 ---
    # 通常の復元ロジック (a0, a1, ...)
    val = to_target.call(abs_coeffs.last.to_s)
    abs_coeffs[0...-1].reverse_each do |c|
        # cは非負整数であるため、c.to_s は安全
        begin
            # val = c + 1 / val
            val = to_target.call(c.to_s) + (to_target.call('1') / val)
        rescue ZeroDivisionError
            return val
        end
    end

    # --- 3. 符号を適用 ---
    if sign == "-"
        return val * to_target.call('-1')
    else
        return val
    end
  end

  # 汎用 PCA 検証関数
  #
  # @param data [Array<Array<Numeric>>] 入力データ (行の配列)
  # @param components [Array<Array<Numeric>>] 固有ベクトル (基底)
  # @param eigenvalues [Array<Numeric>] 固有値 (絶対値の昇順)
  # @param options [Hash] 設定オプション
  #   - :label [String] エラーメッセージやレポートに使用する識別子
  #   - :io [IO] 出力先 (デフォルト: nil = 出力なし)
  #   - :check_algebraic [Boolean] 連分数展開による解析を行うか (デフォルト: true, io指定時のみ有効)
  #   - :tolerance_multiplier [Numeric] 許容誤差の倍率 (デフォルト: 1.0)
  #   - :dimensionality_threshold [Float] 次元性判定の閾値(%)(デフォルト: 10.0)
  #
  # @raise [ArgumentError] 入力データ不備 (サイズ不足、次元不一致)
  # @raise [RuntimeError] 検証失敗 (正規性、直交性、固有対整合性、射影残差などが許容範囲外)
  def self.verify_pca_results(data, components, eigenvalues, options = {})
    label = options[:label] || "PCA Verification"
    io = options[:io]
    check_algebraic = options.fetch(:check_algebraic, true)
    tolerance_multiplier = options[:tolerance_multiplier] || 1.0
    dim_threshold = options[:dimensionality_threshold] || 10.0

    # 1. Input Validation
    raise ArgumentError, "[#{label}] Input Validation Failed: Data size too small (Rows: #{data.size}, Required: >= 5)" if data.size < 5
    raise ArgumentError, "[#{label}] Input Validation Failed: Invalid component count (Count: #{components.size}, Required: 4)" if components.size != 4
    raise ArgumentError, "[#{label}] Input Validation Failed: Invalid eigenvalue count (Count: #{eigenvalues.size}, Required: 4)" if eigenvalues.size != 4
    raise ArgumentError, "[#{label}] Input Validation Failed: Invalid data dimension (Dim: #{data[0].size}, Required: 4)" if data[0].size != 4

    # ソート順チェック (絶対値昇順であることを確認)
    val_abs = eigenvalues.map(&:abs)
    unless val_abs.each_cons(2).all? { |a, b| a <= b }
      raise RuntimeError, "[#{label}] Verification Failed: Eigenvalue Order - Input eigenvalues are not sorted by magnitude (Values: #{eigenvalues})"
    end

    sample_val = data[0][0]
    eps = SpectreMath.get_math_context(sample_val.class.name, :convergence_epsilon) * tolerance_multiplier

    # Header Output
    if io
      io.puts "\n" + "=" * 80
      io.puts "🔍 #{label}"
      io.puts "=" * 80
      io.puts "  Input Data: #{data.size} samples, Type: #{sample_val.class}"
      io.puts "  Epsilon: #{eps}"
      io.puts "  基底ベクトル数: #{components.size}"
      components.each_with_index do |component, i|
        io.puts "  基底#{i}: #{component.map { |x| format('%.10f', x) }.inspect}"
      end
    end

    # 2. Eigenvalue Analysis
    # 表示用に降順に並べ替え
    sorted_indices = (0...4).to_a.reverse
    vals_desc = sorted_indices.map { |i| eigenvalues[i] }

    sum_lambdas = val_abs.sum
    if sum_lambdas.zero?
      raise RuntimeError, "[#{label}] Verification Failed: Sum of eigenvalues is zero."
    end

    if io
      io.puts "\n📊 Eigenvalue Analysis (Sorted Descending):"
      cumsum = 0.0
      vals_desc.each_with_index do |v, i|
        ratio = (v.abs / sum_lambdas * 100)
        cumsum += ratio
        io.puts "  λ#{i+1}: #{format('%.10e', v.to_f)} (Ratio: #{format('%.2f', ratio)}%, Cum: #{format('%.2f', cumsum)}%)"

        if check_algebraic
          cf = SpectreMath.continued_fraction(v, max_terms: 20)
          io.puts "      Continued Fraction: #{cf.inspect}"
        end
      end
    end

    # Dimensionality Check (using original ascending order: index 0 and 1 are smallest)
    # The smallest eigenvalues correspond to the null space (if 2D)
    min_2_variance = (eigenvalues[0].abs + eigenvalues[1].abs)
    min_2_ratio = (min_2_variance / sum_lambdas * 100)

    if min_2_ratio > dim_threshold
      raise RuntimeError, "[#{label}] Verification Failed: Dimensionality Check - Significant variance in null-space (Ratio: #{min_2_ratio.round(2)}% > Threshold: #{dim_threshold}%)"
    elsif io
      io.puts "\n  ✅ Dimensionality Check: Null-space variance is #{min_2_ratio.round(4)}% <= (Threshold: #{dim_threshold}%)"
    end

    # 3. Eigenvector Analysis (Normality & Orthogonality)
    components.each_with_index do |v, i|
      # Normality
      norm_sq = v.zip(v).map { |a, b| a * b }.sum
      norm = Math.sqrt(norm_sq.to_f) # Check uses sqrt for output, but comparison can be done on sq
      if (norm - 1.0).abs > eps
        raise RuntimeError, "[#{label}] Verification Failed: Normality Check - Vector v[#{i}] is not normalized (Norm: #{norm}, Tol: #{eps})"
      end

      # Orthogonality with SUBSEQUENT vectors
      (i + 1...components.size).each do |j|
        dot = v.zip(components[j]).map { |a, b| a * b }.sum
        if dot.abs > eps
          raise RuntimeError, "[#{label}] Verification Failed: Orthogonality Check - Pair v[#{i}]·v[#{j}] is not orthogonal (Dot: #{dot}, Tol: #{eps})"
        end
      end

      if io && check_algebraic
        io.puts "\n  λ[#{i}] Scientific: #{ eigenvalues[i].inspect }"
        io.puts "\n  λ[#{i}] Continued Fraction: #{ SpectreMath.continued_fraction(eigenvalues[i], max_terms: 30).inspect }"
        io.puts "\n  Vector v[#{i}] Algebraic Analysis:"
        v.each_with_index do |val, k|
           io.puts "    Coords[#{k}] scientific: #{val.inspect}"
           cf = SpectreMath.continued_fraction(val, max_terms: 30)
           io.puts "    Coords[#{k}]: #{cf.inspect}"
        end
      end
    end
    components[0].zip(components[1]).map { |a, b| a * b }.each_with_index do |dot, i|
      io.puts "\n   v[0][#{i}] dot v[1][#{i}] scientific: #{dot}" if io && check_algebraic
      io.puts "\n   v[0][#{i}] dot v[1][#{i}] continued_fraction: #{SpectreMath.continued_fraction(dot, max_terms: 30).inspect}" if io && check_algebraic
    end

    if io
      io.puts "\n  ✅ Eigenvectors are Normalized and Orthogonal."
    end

    # 4. Eigenpair Consistency (Covariance Matrix Check)
    # Reconstruct Covariance Matrix
    m = data.size
    n_cols = 4
    col_sums = Array.new(n_cols, 0.0)
    # Using generic addition
    data.each { |row| row.each_with_index { |x, j| col_sums[j] += x } }

    # Casting m to appropriate type
    m_val = (sample_val.is_a?(BigDecimal) ? BigDecimal(m.to_s) : m.to_f)
    mean = col_sums.map { |s| s / m_val }

    # Covariance loop
    cov = Array.new(n_cols) { Array.new(n_cols, 0.0) }
    cov.map! { |row| row.map! { |x| sample_val.is_a?(BigDecimal) ? BigDecimal('0') : 0.0 } }

    data.each do |row|
      centered = row.zip(mean).map { |x, mu| x - mu }
      n_cols.times do |dim_i|
        n_cols.times do |dim_j|
          cov[dim_i][dim_j] += centered[dim_i] * centered[dim_j]
        end
      end
    end
    # Divide by m
    cov.each { |row| row.map! { |x| x / m_val } }

    # Check A*v = lambda*v
    eigenvalues.each_with_index do |lam, i|
      vec = components[i]

      # A * v
      av = Array.new(n_cols, 0.0)
      # Init with zero of correct type
      av.map! { |x| sample_val.is_a?(BigDecimal) ? BigDecimal('0') : 0.0 }

      n_cols.times do |r|
        n_cols.times do |c|
          av[r] += cov[r][c] * vec[c]
        end
      end

      # lambda * v
      lam_v = vec.map { |x| x * lam }

      # Residual
      residual = av.zip(lam_v).map { |a, b| a - b }
      residual_norm_sq = residual.zip(residual).map { |a, b| a * b }.sum
      residual_norm = Math.sqrt(residual_norm_sq.to_f)

      # Relaxation for checking: Covariance reconstruction from data might have slight precision diffs
      # compared to the one used for PCA if not exactly same method.
      # Allowing slightly looser tolerance for this derived check.
      check_tol = eps * 100

      if residual_norm > check_tol
         # Warn instead of raise if purely numerical noise, but raise if significant
         # Re-evaluating: standard PCA vs generic covariance calc might differ slightly.
         # For now, strict check.
         raise RuntimeError, "[#{label}] Verification Failed: Eigenpair Consistency - v[#{i}] does not satisfy A*v = λ*v (Residual: #{residual_norm}, Tol: #{check_tol})"
      end
    end
    if io
       io.puts "\n  ✅ Eigenpair Consistency Checked (A*v ≈ λ*v)."
    end

    # 5. Projection Residual Analysis
    # Project data onto the Null Space (assumed to be components[0] and components[1])
    # Verify that these projections are small.

    null_basis = components[0..1]
    mae_sum = 0.0
    max_error = 0.0

    # 相関係数計算用の配列を追加
    centered_sq_array = []
    projections_sq_array = []

    data.each do |row|
      centered = row.zip(mean).map { |x, mu| x - mu }
      centered_sq = centered.map { |x| x * x }.sum
      centered_sq_array << centered_sq

      projections_sq = null_basis.map do |basis_vec|
        projection = centered.zip(basis_vec).map { |a, b| a * b }.sum
        abs_proj = projection.abs
        mae_sum += abs_proj
        max_error = abs_proj if abs_proj > max_error
        projection * projection  # 射影の二乗
      end.sum

      projections_sq_array << projections_sq
    end

    mae = mae_sum / (m * 2) # Average over samples and 2 dimensions

    # 相関係数の計算（Pearsonの相関係数）
    n = centered_sq_array.size
    mean_centered = centered_sq_array.sum / n.to_f
    mean_projections = projections_sq_array.sum / n.to_f

    cov = centered_sq_array.zip(projections_sq_array)
                            .map { |x, y| (x - mean_centered) * (y - mean_projections) }
                            .sum / n.to_f

    var_centered = centered_sq_array.map { |x| (x - mean_centered) ** 2 }.sum / n.to_f
    var_projections = projections_sq_array.map { |y| (y - mean_projections) ** 2 }.sum / n.to_f

    correlation = if var_centered.zero? || var_projections.zero?
                     0.0
                   else
                     cov / Math.sqrt(var_centered * var_projections)
                   end

    if io
      io.puts "\n  📊 Projection Verification:"
      io.puts "    Mean Absolute Error on Null Space: #{format('%.10e', mae.to_f)}"
      io.puts "    Max Absolute Error on Null Space:  #{format('%.10e', max_error.to_f)}"
      io.puts "\n  📈 Correlation Analysis (Pearson):"
      # io.puts "    Mean(centered_sq): #{format('%.10e', mean_centered)}"
      # io.puts "    Mean(projections_sq): #{format('%.10e', mean_projections)}"
      # io.puts "    Variance(centered_sq): #{format('%.10e', var_centered)}"
      # io.puts "    Variance(projections_sq): #{format('%.10e', var_projections)}"
      # io.puts "    Covariance: #{format('%.10e', cov)}"
      io.puts "    Correlation Coefficient: #{format('%.10f', correlation)}.abs < 0.2(Expects uncorrelated)"
    end

    # Explicit projection tolerance check (if provided in options)
    # This allows strict verification for data expected to be exactly 2D (e.g. tolerance ~ epsilon)
    # Changed to compare against Max Absolute Error
    if (projection_tolerance = options[:projection_tolerance])
      if max_error > projection_tolerance
        raise RuntimeError, "[#{label}] Verification Failed: Projection Residual - Max Error (#{max_error.to_f}) exceeds tolerance (#{format('%.3e', projection_tolerance)}) (projection_tolerance:%.3e})"
      else
         io.puts "    ✅ Projection Max Error within tolerance (#{max_error.to_f} <= #{format('%.3e', projection_tolerance)}) " if io
      end
    end

    io.puts "\n  ✅ All Verification Steps Passed." if io
  end

  # --- 最小二乗法 (Least Squares) ---
  # def least_squares(x_data, y_data)
  #   x = Matrix[*x_data]
  #   y = Vector[*y_data]
  #   xt = x.transpose

  #   # 通常の正規方程式
  #   beta = (xt * x).inverse * xt * y
  #   beta.to_a
    # max_iter = 3
    # tol = SpectreMath.get_math_context(x_data[0][0].class.name, SpectreMath::CONVERGENCE_EPSILON)
    # lambda = SpectreMath.get_math_context(x_data[0][0].class.name, SpectreMath::CONVERGENCE_EPSILON)
  # end

  # Classify points by projection residuals onto given components.
  # Generic implementation: type-agnostic (Integer, Float, BigDecimal compatible)
  #
  # points: Array<Array<Numeric>> (each 4-dim)
  # components: Array<Array<Numeric>> (each 4-dim basis vector, assumed normalized)
  # threshold_sq: Numeric or nil; if nil compute mean+3*std of residual_norm_sq
  # Returns: Array<Hash{ :point, :projections, :residual_norm_sq, :in_inside_by_residual }>
  def classify_by_projection(points, components, threshold_sq: nil)
    results = points.map do |pt|
      v = pt
      # 内積計算（型を統一せず、Rubyの型自動昇格に任せる）
      projections = components.map { |c| v.zip(c).map { |a, b| a * b }.sum }

      # 復元値の計算
      reconstructed = Array.new(pt.size, 0)
      components.each_with_index do |c, i|
        reconstructed = reconstructed.zip(c.map { |x| x * projections[i] }).map { |a, b| a + b }
      end

      # 残差の計算
      residual = v.zip(reconstructed).map { |a, b| a - b }

      # 残差のノルム二乗（sqrtを避けてgenericさを向上）
      residual_norm_sq = residual.map { |x| x * x }.sum

      { point: v, projections: projections, residual_norm_sq: residual_norm_sq }
    end

    if threshold_sq.nil?
      norms_sq = results.map { |r| r[:residual_norm_sq] }
      mean_sq = norms_sq.sum / norms_sq.size.to_f
      # 標準偏差の計算（二乗和）
      variance = norms_sq.map { |x| (x - mean_sq) ** 2 }.sum / norms_sq.size.to_f
      std_sq = variance  # sqrt不要：二乗のまま比較
      threshold_sq = mean_sq + 9.0 * std_sq  # (mean + 3*std)^2 ≈ mean_sq + 9*std_sq（近似）
    end

    results.each { |r| r[:in_inside_by_residual] = (r[:residual_norm_sq] <= threshold_sq) }
    results.each { |r| r[:residual_threshold_sq] = threshold_sq }
    results
  end
end

# ====================================================================
# デフォルト MathContext の登録
# ====================================================================

# Float型用の定数（静的値）
SpectreMath.register_math_context(
  ["Float", "Integer", "Rational"],  # Floatとその他の通常精度型
  singularity_threshold: 1e-12,      # ゼロ判定用
  convergence_epsilon: 1e-10,        # 収束判定用
  geometric_tolerance: 1e-6          # 幾何判定用
)

# BigDecimal型用の定数（動的lambda - HighPrecisionMathモジュール内の変数を参照）
if HIGHPRECISION_AVAILABLE
  SpectreMath.register_math_context(
    ["BigDecimal"],
    singularity_threshold: -> { HighPrecisionMath.class_variable_get(:@@singularity_threshold) },
    convergence_epsilon: -> { HighPrecisionMath.class_variable_get(:@@convergence_epsilon) },
    geometric_tolerance: -> { HighPrecisionMath.class_variable_get(:@@geometric_tolerance) }
  )
end


module SpectreGeometry
  module_function

  # --- 凸包 (Convex Hull) ---
  # Andrew's Monotone Chain Algorithm
  # my_spectre_coordinateAnalyzer_keyed.rb からの移植（ロバスト版）

  def compute_convex_hull(points)
    # 重複排除とソート
    points = points.uniq.sort_by { |x, y| [x, y] }
    return points if points.size <= 2

    cross = ->(o, a, b) {
      (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    }

    lower = []
    points.each do |p|
      while lower.size >= 2 && cross.call(lower[-2], lower[-1], p) <= 0
        lower.pop
      end
      lower << p
    end

    upper = []
    points.reverse.each do |p|
      while upper.size >= 2 && cross.call(upper[-2], upper[-1], p) <= 0
        upper.pop
      end
      upper << p
    end

    (lower[0...-1] + upper[0...-1])
  end

  # --- 点内包判定 (Point inside Polygon) ---
  # my_spectre_coordinateAnalyzer_keyed.rb からの移植
  # 境界線上や頂点上の判定、縮退した多角形(点、線分)への対応を含むロバスト版
  #
  # @param pt [Array<Numeric>] 判定する点 [x, y]
  # @param polygon [Array<Array<Numeric>>] 多角形の頂点リスト
  # @param tol [Numeric, nil] 許容誤差。nilの場合は pt の型から自動取得
  # @return [Boolean] 点が多角形内部にあるか（境界上を含む）
  def point_inside_polygon?(pt, polygon, tol = nil)
    x, y = pt
    # 型ベースのコンテキストから許容誤差を取得
    if tol.nil? # pt の要素の型を判定（配列の最初の要素を代表とする）
      tol = SpectreMath.get_math_context(x.class.name, SpectreMath::GEOMETRIC_TOLERANCE)
    end

    if polygon.nil? || polygon.empty?
      return false
    elsif polygon.size == 1
      # 点との一致判定
      point = polygon[0]
      return (x - point[0]).abs < tol && (y - point[1]).abs < tol
    elsif polygon.size == 2
      # 線分上判定
      x1, y1 = polygon[0]
      x2, y2 = polygon[1]
      vx, vy = x2 - x1, y2 - y1
      wx, wy = x - x1, y - y1
      seg_len2 = vx * vx + vy * vy

      if seg_len2 < tol * tol
        return (x - x1).abs < tol && (y - y1).abs < tol
      else
        t = (vx * wx + vy * wy) / seg_len2
        if t > -tol && t < 1.0 + tol
          projx = x1 + t * vx
          projy = y1 + t * vy
          dist2 = (x - projx)**2 + (y - projy)**2
          return dist2 <= tol * tol
        else
          return false
        end
      end
    end

    # 多角形 (size >= 3)
    # 1. 境界（辺上）判定
    j = polygon.size - 1
    polygon.each_with_index do |point_i, i|
      point_j = polygon[j]
      x1, y1 = point_i
      x2, y2 = point_j

      vx, vy = x2 - x1, y2 - y1
      wx, wy = x - x1, y - y1
      seg_len2 = vx * vx + vy * vy

      if seg_len2 < tol * tol
        if (x - x1).abs < tol && (y - y1).abs < tol
          return true
        end
      else
        t = (vx * wx + vy * wy) / seg_len2
        if t > -tol && t < 1.0 + tol
          projx = x1 + t * vx
          projy = y1 + t * vy
          dist2 = (x - projx)**2 + (y - projy)**2
          return true if dist2 <= tol * tol
        end
      end
      j = i
    end

    # 2. 内部判定 (Ray Casting)
    inside = false
    j = polygon.size - 1

    # ゼロ除算回避用の小さな値を型に応じて取得
    epsilon_zero = SpectreMath.get_math_context(x.class.name, SpectreMath::SINGULARITY_THRESHOLD)

    polygon.each_with_index do |point_i, i|
      point_j = polygon[j]
      xi, yi = point_i
      xj, yj = point_j

      if ((yi > y) != (yj > y))
        x_int = (xj - xi) * (y - yi) / (yj - yi + epsilon_zero) + xi
        inside = !inside if x <= x_int + tol
      end
      j = i
    end

    inside
  end

  # Helper: project 4D point to 2D using two basis vectors (each 4-d)
  # Generic implementation: works with Integer, Float, BigDecimal, Vector
  def project_to_2d(point4, basis2)
    b0 = basis2[0]
    b1 = basis2[1]
    v = point4

    # 内積計算（型を統一せず、Rubyの型自動昇格に任せる）
    x = v.zip(b0).map { |a, b| a * b }.sum
    y = v.zip(b1).map { |a, b| a * b }.sum

    [x, y]
  end
end

# --- KD木 (K-Dimensional Tree) ---
# KNN探索用。hybrid_v2 と coordinateAnalyzer で共通。

class KDTree
  Node = Struct.new(:point, :left, :right, :axis)

  def initialize(points)
    @root = build_tree(points, 0)
  end

  def build_tree(points, depth)
    return nil if points.empty?

    axis = depth % 2 # 2次元なので axis は 0(x) か 1(y)
    points.sort_by! { |p| p[axis] }
    median = points.size / 2

    Node.new(
      points[median],
      build_tree(points[0...median], depth + 1),
      build_tree(points[median+1..-1], depth + 1),
      axis
    )
  end

  def nearest_k(target, k)
    best_nodes = [] # [distance_sq, point] のリスト
    search_recursive(@root, target, k, best_nodes)
    best_nodes.sort_by { |d, _| d }
  end

  private

  def search_recursive(node, target, k, best_nodes)
    return unless node

    dist_sq = (node.point[0] - target[0])**2 + (node.point[1] - target[1])**2

    # 候補リストに追加・更新
    if best_nodes.size < k
      best_nodes << [dist_sq, node.point]
      best_nodes.sort_by! { |d, _| -d } # 距離の降順（末尾が最大距離）
    elsif dist_sq < best_nodes.first[0]
      best_nodes[0] = [dist_sq, node.point]
      best_nodes.sort_by! { |d, _| -d }
    end

    axis = node.axis
    diff = target[axis] - node.point[axis]

    near_node = diff < 0 ? node.left : node.right
    far_node = diff < 0 ? node.right : node.left

    search_recursive(near_node, target, k, best_nodes)

    # 反対側の枝を探索する必要があるか？
    if best_nodes.size < k || diff**2 < best_nodes.first[0]
      search_recursive(far_node, target, k, best_nodes)
    end
  end
end


# --- StatisticsManager クラス ---
# 複数の GroupStatistics を管理し、形状のグループキーに応じて適切な統計情報を適用する
class StatisticsManager
  def initialize
    @groups = {} # group_key => GroupStatistics
  end

  def register(group_stats)
    @groups[group_stats.group_key] = group_stats
  end

  def valid?(shape)
    stats = @groups[shape.group_key]
    # 統計情報がないグループがもし在ったら、警告して制約なしとして扱う
    unless stats
      STDERR.puts "⚠️ 警告: グループ #{shape.group_key} の統計情報が見つかりません"
      return true
    end

    # 形状の全頂点についてチェック
    shape.vertices.all? { |v| stats.valid?(v) }
  end
end

# --- GroupStatistics 抽象クラス ---
class GroupStatistics
  attr_reader :group_key

  def initialize(group_key, data_points)
    @group_key = group_key
    @data_points = data_points
  end

  # 頂点座標を与えられて、その形状が有効かどうかを返す
  def valid?(data_point)
    raise NotImplementedError, "#{self.class} must implement #valid?"
  end

  private

  def project_to_2d(points)
    points.map { |pt| project_point_to_2d(pt) }
  end

  def project_point_to_2d(point)
    # 基底ベクトルとの内積をとって2D座標に変換（型に依存しない）
    x = point.inner_product(Vector.elements(@basis_vectors[0]))
    y = point.inner_product(Vector.elements(@basis_vectors[1]))
    # [x, y]
    [x.to_f, y.to_f]
  end
  # 構造化レポート出力 (JSON風)
  # @param io [IO] 出力先ストリーム
  # @param indent [Integer] インデントレベル
  def report(io = $stdout, indent = 0)
    # デフォルト実装: クラス名と基本情報のみ
    prefix = indent_str(indent)
    io.puts "#{prefix}\"#{self.class.name}\": {"
    io.puts "#{prefix}  \"group_key\": \"#{@group_key}\""
    io.puts "#{prefix}}"
  end

  protected

  def indent_str(level)
    "  " * level
  end
end

# --- PCAGroupStatistics クラス ---
# PCA, KNN, 凸包を用いた実装
class PCAGroupStatistics < GroupStatistics
  attr_reader :basis_vectors, :acceptance_domain

  def initialize(group_key, data_points, knn_k = 5)
    super(group_key, data_points)
    @knn_k = knn_k

    # PCA計算
    # components: 固有ベクトル(基底), lambdas: 固有値
    @basis_vectors, _lambdas = SpectreMath.pca_components(data_points.map(&:to_a), 2, group_key)

    # 2D射影と凸包計算
    projected_2d = project_to_2d(data_points)
    @acceptance_domain = SpectreGeometry.compute_convex_hull(projected_2d)

    # KDTree構築（オプション）
    @kdtree = KDTree.new(projected_2d) if knn_k > 0
  end

  def valid?(data_point)
    # 1. PCA射影により2D座標を計算
    point_2d = project_point_to_2d(data_point)

    # 2. 凸包内部判定
    return false unless SpectreGeometry.point_inside_polygon?(point_2d, @acceptance_domain)

    # 3. KNN密度チェック（オプション）
    if @kdtree && @knn_k > 0
      neighbors = @kdtree.nearest_k(point_2d, @knn_k)
      max_dist_sq = neighbors.last[0]
      return max_dist_sq < 1.0 # 閾値
    end

    true
  end

  def report(io = $stdout, indent = 0)
    prefix = indent_str(indent)
    io.puts "#{prefix}\"#{self.class.name}\": {"
    io.puts "#{prefix}  \"group_key\": \"#{@group_key}\","

    # 固有値 (もしあれば) - PCAGroupStatisticsでは保持していない実装になっている場合もあるため確認
    # ここでは basis_vectors を出力
    io.puts "#{prefix}  \"basis_vectors\": ["
    @basis_vectors.each_with_index do |vec, i|
      vec_str = vec.map { |v| v.is_a?(BigDecimal) ? v.to_s("F") : v.to_s }.join(", ")
      io.print "#{prefix}    { \"index\": #{i}, \"vector\": [#{vec_str}] }"
      io.puts(i < @basis_vectors.size - 1 ? "," : "")
    end
    io.puts "#{prefix}  ]"
    io.puts "#{prefix}}"
  end
end

# --- HighPrecisionPCAGroupStatistics クラス ---
# HighPrecisionMathを用いた高精度PCA版 (BigDecimal)
if defined?(HIGHPRECISION_AVAILABLE) && HIGHPRECISION_AVAILABLE
  class HighPrecisionPCAGroupStatistics < PCAGroupStatistics
    def initialize(group_key, data_points, knn_k = 5)
      # 親クラス(PCAGroupStatistics)のinitializeを呼ぶとFloat版PCAが走るため、
      # 祖父クラス(GroupStatistics)の責務（変数のセット）をここで行い、無駄な計算を省く。
      # ※ GroupStatistics#initialize は @group_key, @data_points を設定するのみ
      @group_key = group_key
      @data_points = data_points
      @knn_k = knn_k

      # p ["debug at HighPrecisionPCAGroupStatistics#initialize: data_points", @data_points[0], @data_points[0][1].class.name]
      # データを HighPrecisionMath 用の形式 (Array of Arrays) に変換
      # data_points は Vector の配列
      rows = data_points.map(&:to_a)

      # 高精度PCAの実行 (BigDecimal)
      # components: 固有ベクトル(基底), lambdas: 固有値
      # high_precision_pca_int は Integer または BigDecimal の2次元配列を受け取る
      components, _lambdas = HighPrecisionMath.high_precision_pca_int(rows, 2, group_key)

      # 基底ベクトルをセット (配列の配列)
      @basis_vectors = components

      # 2D射影と凸包計算
      # project_to_2d は @basis_vectors を使用するため、これにより高精度な射影が行われる
      projected_2d = project_to_2d(data_points)
      @acceptance_domain = SpectreGeometry.compute_convex_hull(projected_2d)
      # p ["debug at HighPrecisionPCAGroupStatistics#initialize: acceptance_domain", @acceptance_domain]

      # KDTreeの構築 (KNN探索用) - 必要なら
      @kdtree = KDTree.new(projected_2d) if knn_k > 0
      # p ["debug at HighPrecisionPCAGroupStatistics#initialize: kdtree", @kdtree]
    end

    def report(io = $stdout, indent = 0)
      prefix = indent_str(indent)
      io.puts "#{prefix}\"#{self.class.name}\": {"
      io.puts "#{prefix}  \"group_key\": \"#{@group_key}\","

      io.puts "#{prefix}  \"basis_vectors\": ["
      @basis_vectors.each_with_index do |vec, i|
        io.puts "#{prefix}    {"
        io.puts "#{prefix}      \"index\": #{i},"
        io.puts "#{prefix}      \"components\": ["
        vec.each_with_index do |val, j|
          # 詳細フォーマット: 固定小数点, 指数表記, 連分数, 復元誤差
          # val_str = val.to_s("F")[0..20] + "..." # 長すぎるので切り詰め
          sci_str = val.to_s("E")

          # 連分数展開と誤差 (HighPrecisionMathの機能に依存)
          cf = HighPrecisionMath.continued_fraction(val, max_terms: 50)

          # 復元誤差の計算
          restored = HighPrecisionMath.continued_fraction_to_decimal(cf)
          error = (val - restored).abs.to_f

          io.puts "#{prefix}        {"
          # io.puts "#{prefix}          \"value_fixed\": \"#{val_str}\","
          io.puts "#{prefix}          \"value_sci\": \"#{sci_str}\","
          io.puts "#{prefix}          \"continued_fraction\": #{cf.to_s},"
          io.puts "#{prefix}          \"restoration_error\": \"#{error}\""
          io.print "#{prefix}        }"
          io.puts(j < vec.size - 1 ? "," : "")
        end
        io.puts "#{prefix}      ]"
        io.print "#{prefix}    }"
        io.puts(i < @basis_vectors.size - 1 ? "," : "")
      end
      io.puts "#{prefix}  ]"
      io.puts "#{prefix}}"
    end
  end
end

# --- StrictCASPrGroupStatistics クラス ---
# CASPr理論に基づく厳密な判定（プレースホルダー）
# strict_caspr_group_statistics.rb
require_relative "strict_caspr/my_snf_file_wrapper"
require_relative "strict_caspr/my_return_module"
require_relative "strict_caspr/my_star_map"
require_relative "strict_caspr/my_acceptance_window"

class StrictCASPrGroupStatistics < GroupStatistics
  def initialize(group_key, data_points)
    super(group_key, data_points)

    # 1. SNF (Python) を、group_key毎に1回だけ呼ぶ
    rows = data_points.map(&:to_a)
    snf_out = SNFFileWrapper.compute_snf_basis!(group_key, rows)

    # 2. ReturnModule（整数格子の基底）
    @return_module = ReturnModule.new(snf_out["return_module"])

    # 3. StarMap（二つの dual basis）
    @star_map = StarMap.new(snf_out["dual_basis"])  # 4×2

    # 4. Window：既存点を内部空間に写して凸包を作る
    proj_points = rows.map { |r| @star_map.project(Vector[*r]) }
    @window_polygon = CASPrWindow.convex_hull(proj_points)
  end

  def valid?(data_point)    vec = Vector[*data_point.to_a]

    # SNF return-module の性質により
    # 表現できない場合（= 無効点）を排除する
    coeff = @return_module.project_integer(vec)
    reconstructed = reconstruct(coeff)
    return false unless reconstructed == vec

    # 内部空間のウィンドウ判定
    proj = @star_map.project(vec)
    CASPrWindow.inside?(proj, @window_polygon)
  end

  private

  # coeff: return-module integer coords
  def reconstruct(coeff)
    # Σ coeff[i] * basis[i] として復元（SNF なら厳密一致）
    sum = Vector[0,0,0,0]
    coeff.each_with_index do |k,i|
      sum += @return_module.basis[i] * k
    end
    sum
  end
end

# --- CommonBasisGroupStatistics クラス ---
# 共通基底検証をGroupStatisticsとして実装
class CommonBasisGroupStatistics < GroupStatistics
  attr_reader :common_basis, :max_radius_sq

  def initialize(group_key, data_points, common_basis, max_radius_sq)
    super(group_key, data_points)
    @common_basis = common_basis
    # Float型で保持（有効桁数6桁程度確保）
    @max_radius_sq = max_radius_sq.to_f
  end

  def valid?(data_point)
    proj = @common_basis.map { |b| data_point.inner_product(Vector[*b]) }
    proj.map { |x| x**2 }.sum <= @max_radius_sq
  end

  def report(io = $stdout, indent = 0)
    prefix = indent_str(indent)
    io.puts "#{prefix}\"#{self.class.name}\": {"
    io.puts "#{prefix}  \"group_key\": \"#{@group_key}\","
    io.puts "#{prefix}  \"max_radius_sq\": #{@max_radius_sq}," # Floatなのでそのまま出力
    io.puts "#{prefix}  \"common_basis\": ["
    @common_basis.each_with_index do |vec, i|
      # common_basis は配列の配列(Float or BigDecimal)
      vec_str = vec.map { |v| v.is_a?(BigDecimal) ? v.to_s("F") : v.to_s }.join(", ")
      io.print "#{prefix}    [#{vec_str}]"
      io.puts(i < @common_basis.size - 1 ? "," : "")
    end
    io.puts "#{prefix}  ]"
    io.puts "#{prefix}}"
  end
end

# --- CompositeGroupStatistics クラス ---
# 複数統計の組み合わせ（Compositeパターン）
class CompositeGroupStatistics < GroupStatistics
  attr_reader :statistics_list

  def initialize(group_key, statistics_list)
    super(group_key, [])
    @statistics_list = statistics_list
  end

  def valid?(data_point)
    # 全ての統計クラスが有効と判定した場合のみtrue
    @statistics_list.all? { |stats| stats.valid?(data_point) }
  end

  def report(io = $stdout, indent = 0)
    prefix = indent_str(indent)
    io.puts "#{prefix}\"#{self.class.name}\": {"
    io.puts "#{prefix}  \"group_key\": \"#{@group_key}\","
    io.puts "#{prefix}  \"children\": ["
    @statistics_list.each_with_index do |stats, i|
      stats.report(io, indent + 2)
      io.puts(prefix + "    " + (i < @statistics_list.size - 1 ? "," : "")) if i < @statistics_list.size - 1 # 簡易的なカンマ処理
    end
    io.puts "#{prefix}  ]"
    io.puts "#{prefix}}"
  end
end

# --- ShapesUnitInfo 抽象クラス ---
# PCA分析結果の係数を保持するグループの単位であり、かつ座標探索のグループ単位でもある
# 「探索図形のグループ」を表す抽象基底クラス

class ShapesUnitInfo
  # 必須インターフェースメソッド（サブクラスで実装すべき）
  def vertices
    raise NotImplementedError, "#{self.class} must implement #vertices"
  end

  def centroid
    raise NotImplementedError, "#{self.class} must implement #centroid"
  end

  def group_key
    raise NotImplementedError, "#{self.class} must implement #group_key"
  end

  @@statistics_manager = nil
  def self.statistics_manager
    @@statistics_manager
  end
  def self.statistics_manager=(manager)
    @@statistics_manager = manager
  end

  def is_valid_with_groupStatistics?
    if @@statistics_manager.nil?
      # Managerがセットされていない場合はチェックをスキップ（またはエラー）
      # ここでは利便性のため true を返すが、運用に合わせて変更可
      return true
    end
    @@statistics_manager.valid?(self)
  end

  # 隣接可能な候補を生成: パターンマッチングを内部で実施し、ShapeInfoインスタンスを直接返す
  def near_shapes_candidates
    raise NotImplementedError, "#{self.class} must implement #near_shapes_candidates"
  end

  def children
    raise NotImplementedError, "#{self.class} must implement #children"
  end

end

# --- ShapeInfo クラス ---
# hybrid_v2 で拡張されたバージョン（重心、角度、スケール、分岐情報を持つ）
# ShapesUnitInfo を継承し、単一のSpectre図形を表現

class ShapeInfo < ShapesUnitInfo
  attr_reader :vertices, :centroid, :angle, :scale, :shape_id
  attr_accessor :invalid_connect_from

  # クラス変数: 有効なパターンのリスト（外部から設定可能）
  @@valid_patterns = []

  def self.valid_patterns=(patterns)
    @@valid_patterns = patterns
  end

  def self.valid_patterns
    @@valid_patterns
  end

  def initialize(vertices, angle = 0.0, scale = 1.0, shape_id: nil, group_key: nil)
    @vertices = vertices          # Array<Vector[a0, a1, b0, b1]>
    @centroid = calculate_centroid(vertices)
    @angle = angle                # Float
    @scale = scale                # Float
    @shape_id = shape_id          # String or Integer (CSVのshape#)
    @_group_key = group_key        # String or Integer (グループキー)
    @invalid_connect_from = []    # Array<Vector> (分岐元の重心)
  end

  def calculate_centroid(vertices)
    sum = Vector[0.0, 0.0, 0.0, 0.0]
    vertices.each { |v| sum += v }
    sum / vertices.size.to_f
  end

  def edges
    Enumerator.new do |y|
      @vertices.each_cons(2) { |v1, v2| y << [v1, v2] }
      y << [@vertices.last, @vertices.first]
    end
  end

  def group_key
    @_group_key || "#{@angle.round(6)}-#{@scale.round(6)}"
  end

  def children
    [self]
  end

  # 隣接判定: 辺を共有するかチェック
  def adjacent_to?(other)
    return false unless other.is_a?(ShapeInfo)

    my_edges = edges.to_a
    other_edges = other.edges.to_a

    my_edges.any? do |v1, v2|
      other_edges.any? do |ov1, ov2|
        (v1 == ov2 && v2 == ov1) || (v1 == ov1 && v2 == ov2)
      end
    end
  end

  # 隣接可能な候補を生成: パターンマッチングを内部で実施し、ShapeInfoインスタンスを直接返す
  def near_shapes_candidates
    Enumerator.new do |y|
      edges.each do |v1, v2|
        edge_vec = v2 - v1

        @@valid_patterns.each do |pattern|
          pattern.size.times do |i|
            p_start = pattern[i]
            p_end = pattern[(i + 1) % pattern.size]
            p_vec = p_start - p_end

            if p_vec == edge_vec
              offset = v2 - p_start
              candidate_points = pattern.map { |v| v + offset }
              candidate_shapeInfo = ShapeInfo.new(candidate_points, @angle, @scale)
              if candidate_shapeInfo.is_valid_with_groupStatistics?
                y << candidate_shapeInfo
              end
            end
          end
        end
      end
    end
  end
end

# --- ClusterInfo クラス ---
# ShapesUnitInfo を継承し、複数の図形からなるクラスター（置換クラスター等）を表現

class ClusterInfo < ShapesUnitInfo
  attr_reader :children, :substitution_rule_id

  def initialize(children, substitution_rule_id = nil)
    @children = children                      # Array<ClusterInfo>
    @substitution_rule_id = substitution_rule_id
  end

  def vertices
    # すべての子要素の頂点を統合
    @children.flat_map(&:vertices).uniq
  end

  def centroid
    # 子要素の重心から計算
    return Vector[0.0, 0.0, 0.0, 0.0] if @children.empty?

    sum = Vector[0.0, 0.0, 0.0, 0.0]
    @children.each { |child| sum += child.centroid }
    sum / @children.size.to_f
  end

  def group_key
    # クラスタのグループキーは子要素の数と置換ルールIDで構成
    "cluster-#{@children.size}-#{@substitution_rule_id}"
  end

  # 隣接可能な候補を生成: 置換ルールに基づく候補生成（将来的な拡張）
  def near_shapes_candidates
    # TODO: 置換ルールに基づく隣接可能なクラスターを生成
    # 現在はプレースホルダーとして空のイテレータを返す
    Enumerator.new do |y|
      # 将来的には、置換ルールに基づいて隣接可能なクラスターを生成
    end
  end
end

# --- SpectreDataLoader クラス ---
# 外部データソース（Generator, CSV）からデータを読み込み、
# 統計情報の構築やパターンの抽出を行う
class SpectreDataLoader
  attr_reader :shapes_by_key, :statistics_manager

  # Statistics Builder (デフォルトは標準PCA)
  DEFAULT_BUILDER = ->(group_key, data_points) { PCAGroupStatistics.new(group_key, data_points) }

  def initialize(statistics_builder: DEFAULT_BUILDER)
    @statistics_builder = statistics_builder  # Proc または callable object
    @shapes_by_key = Hash.new { |h, k| h[k] = [] }
    @statistics_manager = StatisticsManager.new
  end

  # 列挙子からデータを読み込む
  # @param shape_enumerator [Enumerator] ShapeInfo を yield する列挙子
  def load(shape_enumerator)
    shape_enumerator.each do |shape|
      @shapes_by_key[shape.group_key] << shape
    end
    self
  end

  # 読み込んだデータから分析を行い、統計情報とパターンを構築する
  def analyze!
    # 1. パターン抽出
    extract_patterns

    # 2. グループ統計情報の構築
    build_group_statistics

    # 3. ShapesUnitInfo への登録
    ShapesUnitInfo.statistics_manager = @statistics_manager

    # puts "✅ データ分析完了: #{@shapes_by_key.size} グループ, #{ShapeInfo.valid_patterns.size} パターン"
  end

  # === 省メモリヘルパーメソッド ===

  # 全形状を列挙する（イテレータ）
  # @yield [shape, shape_index] 形状と形状インデックス
  def each_shape
    return enum_for(:each_shape) unless block_given?

    shape_index = 0
    @shapes_by_key.each_value do |shapes|
      shapes.each do |shape|
        yield shape, shape_index
        shape_index += 1
      end
    end
  end

  # 全頂点を列挙する（列挙子）
  # @yield [vertex, vertex_index, shape_index] 頂点と頂点インデックスと形状インデックス
  # @return [Enumerator] ブロックが渡されない場合は列挙子を返す
  def each_vertices
    return enum_for(:each_vertices) unless block_given?

    each_shape do |shape, shape_index|
      vertex_index = 0
      shape.vertices.each do |v|
        yield v, vertex_index, shape_index
        vertex_index += 1
      end
    end
  end

  # 増殖の種にする、最初のN個の形状を取得（初期形状用）
  # 特定のshape_idの形状を取得（初期形状用・推奨）
  # @param ids [Array<String, Integer>] 取得するshape_idのリスト（デフォルト: ["0".."9"]）
  # @return [Array<ShapeInfo>] 指定されたshape_idの形状リスト
  def get_seeded_shapes(ids: (0..9).map(&:to_s))
    all_shapes = @shapes_by_key.values.flatten

    # shape_idでフィルタリング
    seeded_shapes = ids.map do |id|
      all_shapes.find { |shape| shape.shape_id.to_s == id.to_s }
    end.compact

    seeded_shapes
  end

  private

  def extract_patterns
    patterns = []
    @shapes_by_key.each do |key, shapes|
      shapes.each do |shape|
        # 最初の頂点を基準とした相対座標をパターンとする
        base_v = shape.vertices.first
        pattern = shape.vertices.map { |v| v - base_v }
        patterns << pattern
      end
    end

    ShapeInfo.valid_patterns = patterns.uniq { |pat| pat.map(&:to_a) }
  end

  def build_group_statistics
    @shapes_by_key.each do |key, shapes|
      # 頂点データを集める
      data_points = shapes.flat_map(&:vertices)
      # PCA統計情報の作成（データ点数が少ない場合はスキップなどの処理が必要かも）
      if data_points.size >= 4 # 最低限の点数
        # ビルダーを使用して統計オブジェクトを生成
        stats = @statistics_builder.call(key, data_points)
        @statistics_manager.register(stats)
      end
    end
  end
end

# --- SpectreDataEnumerators モジュール ---
# 各種データソースから ShapeInfo を生成する列挙子を提供するファクトリ
module SpectreDataEnumerators
  module_function

  # CSVファイルから読み込む列挙子
  # hybrid_v2 形式のCSV (full vertex list) を想定
  def from_csv(filename)
    Enumerator.new do |y|
      require 'csv'
      rows_by_shape = Hash.new { |h, k| h[k] = [] }

      CSV.foreach(filename, headers: true) do |row|
        shape_id = row['shape#'] || row["\uFEFFshape#"]
        next unless shape_id

        # 必要なカラムのパース
        coord = ['pt0-coef:a0', 'a1', 'b0', 'b1'].map { |c| row[c].to_f }
        angle = row['angle'] #.to_f
        scale = row['scale_y'] #.to_f
        idx = row['vertex_index'].to_i

        rows_by_shape[shape_id] << { idx: idx, coord: Vector[*coord], angle: angle, scale: scale }
      end

      # シェイプごとに ShapeInfo を生成
      rows_by_shape.each do |id, rows|
        # インデックス順にソート (-14..-1 または 0..13)
        sorted_rows = rows.sort_by { |r| r[:idx] }
        vertices = sorted_rows.map { |r| r[:coord] }

        # 頂点数が14であることを確認（必要なら）
        if vertices.size == 14
          first = sorted_rows.first
          # shape_idを保存
          y << ShapeInfo.new(vertices, first[:angle], first[:scale], shape_id: id)
        end
      end
    end
  end

  # SpectreTilingGenerator から読み込む列挙子
  # generator は SpectreTilingGenerator のインスタンス
  def from_generator(generator, generations)
    Enumerator.new do |y|
      # generator の内部メソッドに依存するため、generator が公開しているメソッドを使用するか、
      # 必要な情報を取得できる前提

      # shape_id カウンター
      shape_id_counter = 0

      # 注: ここでは generator.generate のブロック引数の仕様に合わせて実装
      generator.generate(generations) do |n, tilesHash|
        next if n == 0 # 0世代目はスキップなど、必要に応じて調整

        tilesHash.each_value do |tile|
          # タイルの頂点座標を計算する必要がある
          # tile オブジェクトから頂点を取得できるか、transform から計算するか
          # ここでは tile.for_each_tile を使って変換行列を取得し、
          # strategy を使って頂点を計算する流れを想定

          # generator から strategy を取得（アクセサがあれば）
          strategy = generator.instance_variable_get(:@strategy)
          # 頂点生成ロジック (Spectreの14頂点)
          # Edge_a, Edge_b は generator から取得
          edge_a = generator.instance_variable_get(:@edge_a) || 1.0
          edge_b = generator.instance_variable_get(:@edge_b) || 1.0
          spectre_points = strategy.define_spectre_points(edge_a, edge_b)
          mystic_points = strategy.define_mystic_points(spectre_points)

          tile.for_each_tile(strategy.identity_transform) do |transform, label, parent_info|
            # transform を適用して座標変換
            vertices = (if label == 'Gamma2'
              then
                mystic_points
              else
                spectre_points
              end
            ).map {|pt| strategy.transform_point(transform, pt).vector}

            # angle, scale の取得
            angle, scale = strategy.get_angle_from_transform(transform)
            # angle が '?' の場合の処理などが必要
            # angle_val = (angle == '?') ? 0.0 : angle.to_f

            # ShapeInfoを生成（shape_idを付与）
            y << ShapeInfo.new(vertices, angle, scale,
               shape_id: shape_id_counter.to_s
              #  group_key: "gen#{n}:#{angle}-#{scale}",
              )
            shape_id_counter += 1
          end
        end
      end
    end
  end
end

# --- SpectreRules モジュール ---
module SpectreRules
  module_function

  # --- 汎用的な候補探索関数 ---
  # near_shapes_candidates から候補を取得し、ブロックによる検証ロジックでフィルタリング
  #
  # @param current_unit [ShapesUnitInfo] 現在のユニット（形状またはクラスター）
  # @param visited [Set<Vector>] 訪問済み重心セット
  # @param debug_stats [Hash] 統計情報更新用
  # @return [Array<ShapesUnitInfo>] 新規に見つかった有効なユニットのリスト
  def find_valid_tile_configuration_generic(current_unit, visited, debug_stats)
    candidates_for_unit = []

    # 現在のユニットから隣接候補を生成（パターンマッチング済み）
    current_unit.near_shapes_candidates.each do |candidate_unit|
      next if visited.include?(candidate_unit.centroid)
      candidates_for_unit << candidate_unit
    end

    # 分岐検出（同じ候補が複数回生成された場合）
    unique_candidates = candidates_for_unit.uniq { |u| u.centroid }
    if unique_candidates.size >= 2
      debug_stats[:branch_detected] += 1
      unique_candidates.each do |u|
        u.invalid_connect_from << current_unit.centroid if u.respond_to?(:invalid_connect_from)
      end
    end
    unique_candidates
  end

  # --- 汎用的なメイン探索ループ ---
  #
  # @param initial_shapes [Array<ShapeInfo>] 初期形状リスト
  # @param max_points [Integer] 最大探索点数
  # @param search_range [Hash] 探索範囲 {min_a0:, max_a0:, ...}
  # @param target_coverage [Float] 目標カバレッジ (0.0 - 1.0)
  # @param input_coords_set [Set<Array>] カバレッジ計算用の入力座標セット (Optional)
  # @return [Array<ShapeInfo>] 新規形状リスト
  def run_search_generic(initial_shapes, max_points, search_range, target_coverage = 1.0, input_coords_set = nil)
    visited = Set.new
    queue = []
    candidates = []
    generated_coords_set = Set.new

    # デバッグ統計
    debug_stats = {
      total_queue_processed: 0,
      branch_detected: 0,
      shapes_by_group: Hash.new(0),
      start_time: Time.now
    }

    # 初期化処理
    initial_shapes.each_with_index do |shape, i|
      # 範囲チェック
      in_range = shape.vertices.all? do |pt|
        (search_range[:min_a0]..search_range[:max_a0]).include?(pt[0]) &&
        (search_range[:min_b0]..search_range[:max_b0]).include?(pt[2])
      end

      unless in_range
        puts "❌ エラー: 初期形状 Shape##{i} が探索範囲外です。"
        return candidates, debug_stats
      end

      visited << shape.centroid
      candidates << shape
      debug_stats[:shapes_by_group][shape.group_key] += 1 if shape.respond_to?(:group_key)
      shape.vertices.each { |v| generated_coords_set << v.to_a }

      queue.push(shape)
    end

    puts "\n🚀 汎用探索ループを開始します..."
    puts "   初期形状数: #{initial_shapes.size}, Queue: #{queue.size}"

    while !queue.empty? && candidates.size < max_points
      current_shapeUnit = queue.shift
      debug_stats[:total_queue_processed] += 1

      find_valid_tile_configuration_generic(current_shapeUnit, visited, debug_stats).each do |shapeUnit|
        next if visited.include?(shapeUnit.centroid)

        visited << shapeUnit.centroid
        queue.push(shapeUnit)
        candidates << shapeUnit
        debug_stats[:shapes_by_group][shapeUnit.group_key] += 1 if shapeUnit.respond_to?(:group_key)

        shapeUnit.vertices.each { |v| generated_coords_set << v.to_a }
      end

      # 進捗表示とカバレッジ判定
      if candidates.size % 100 == 0
        status_msg = "   ... #{candidates.size} 生成済. Queue: #{queue.size}"

        if input_coords_set
          matched = input_coords_set & generated_coords_set
          coverage = matched.size.to_f / input_coords_set.size
          status_msg += ", Coverage: #{(coverage * 100).round(2)}%"

          if coverage >= target_coverage
            puts status_msg
            puts "\n🎉 目標カバレッジ達成！"
            break
          end
        end
        puts status_msg
      end
    end

    puts "✅ 探索終了. 生成数: #{candidates.size}, 時間: #{Time.now - debug_stats[:start_time]}s"
    return candidates, debug_stats
  end
end

# ====================================================================
# テストコード (if __FILE__ == $0)
# ====================================================================

if __FILE__ == $0
  puts "🧪 インターフェース適合性テストを実行中..."

  # 1. ShapesUnitInfo インターフェースのテスト
  puts "\n【1】ShapeInfo のインターフェーステスト"
  test_vertices = [
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ]
  shape = ShapeInfo.new(test_vertices, 0.0, 1.0)
  puts "  ✓ vertices: #{shape.vertices.size} 個"
  puts "  ✓ centroid: #{shape.centroid}"
  puts "  ✓ group_key: #{shape.group_key}"
  puts "  ✓ children: #{shape.children.size} 個 (自分自身)"

  # 2. ClusterInfo のテスト
  puts "\n【2】ClusterInfo のインターフェーステスト"
  shape2 = ShapeInfo.new([Vector[2, 0, 0, 0], Vector[3, 0, 0, 0]], 0.0, 1.0)
  cluster = ClusterInfo.new([shape, shape2], "test-rule")
  puts "  ✓ vertices: #{cluster.vertices.size} 個 (統合)"
  puts "  ✓ centroid: #{cluster.centroid}"
  puts "  ✓ group_key: #{cluster.group_key}"
  puts "  ✓ children: #{cluster.children.size} 個"

  # 3. adjacent_to? のテスト
  puts "\n【3】adjacent_to? メソッドのテスト"
  shape_a = ShapeInfo.new([
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ], 0.0, 1.0)
  shape_b = ShapeInfo.new([
    Vector[1, 0, 0, 0],
    Vector[2, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ], 0.0, 1.0)
  puts "  ✓ 隣接する図形の判定: #{shape_a.adjacent_to?(shape_b)}"

  # 4. GroupStatistics のテスト
  puts "\n【4】GroupStatistics のテスト"
  test_data = [
    Vector[0.0, 0.0, 0.0, 0.0],
    Vector[1.0, 0.0, 0.0, 0.0],
    Vector[0.0, 1.0, 0.0, 0.0],
    Vector[0.0, 0.0, 1.0, 0.0]
  ]
  stats = PCAGroupStatistics.new("0.0-1.0", test_data, 3)
  puts "  ✓ PCAGroupStatistics 生成: #{stats.group_key}"

  test_shape_valid = ShapeInfo.new([Vector[0.25, 0.25, 0.25, 0.25]], 0.0, 1.0)
  puts "  ✓ valid? (内部点): #{stats.valid?(Vector[0.25, 0.25, 0.25, 0.25])}"

  # ShapesUnitInfo に統計情報をセット
  manager = StatisticsManager.new
  manager.register(stats)
  ShapesUnitInfo.statistics_manager = manager
  puts "  ✓ ShapesUnitInfo.statistics_manager セット完了"

  # 5. near_shapes_candidates のテスト (パターン設定が必要)
  puts "\n【5】near_shapes_candidates のテスト"
  test_pattern = [
    Vector[0, 0, 0, 0],
    Vector[1, 0, 0, 0],
    Vector[1, 1, 0, 0]
  ]
  ShapeInfo.valid_patterns = [test_pattern]

  # 候補生成（valid? チェックが内部で走る）
  # テストデータは凸包内に入るように調整が必要だが、ここでは動作確認のみ
  candidates = shape_a.near_shapes_candidates.take(3)
  puts "  ✓ パターン設定完了: #{ShapeInfo.valid_patterns.size} 個"
  puts "  ✓ 生成された候補: #{candidates.size} 個 (フィルタリング後)"

  # --- 追加デモ: test_data_int に対する in_inside / is_extra 判定デモ ---
  puts "\n--- Demo: test_data_int classification (projection residual / convex-hull) ---"

  # サンプル整数データ（以前の test_data_int 相当）
  test_data_int = [
[0, 0, 0, 0],
[-1, -1, 0, 0],
[-2, 1, 1, -2],
[-1, -1, 1, -2],
[1, -2, 1, -2],
[0, -3, -1, -1],
[1, -2, -1, -1],
[3, -3, -1, 2],
[0, 0, -2, 1],
[8, -4, -1, 5],
[6, -3, -1, 5],
[7, -2, 1, 4],
[6, -3, 1, 4],
[7, -5, 1, 4],
[5, -4, 0, 3],
[7, -5, 0, 3],
[8, -7, -3, 6],
[8, -4, -2, 4],
[10, 1, 4, 4],
[8, 2, 4, 4],
[9, 3, 6, 3],
[8, 2, 6, 3],
[9, 0, 6, 3],
[7, 1, 5, 2],
[9, 0, 5, 2],
[10, -2, 2, 5],
[10, 1, 3, 3],
[14, -7, -1, 8],
[13, -5, -1, 8],
[15, -6, 0, 9],
[13, -5, 0, 9],
[12, -6, 0, 9],
[11, -4, 1, 7],
[12, -6, 1, 7],
[11, -7, -2, 7],
[14, -7, 0, 6],
[10, -11, -5, 7],
[11, -10, -5, 7],
[12, -12, -6, 9],
[11, -10, -6, 9],
[9, -9, -6, 9],
[10, -8, -4, 8],
[9, -9, -4, 8],
[7, -8, -4, 5],
[10, -11, -3, 6],
[15, -18, -9, 12],
[16, -17, -9, 12],
[17, -19, -10, 14],
[16, -17, -10, 14],
[14, -16, -10, 14],
[15, -15, -8, 13],
[14, -16, -8, 13],
[12, -15, -8, 10],
[15, -18, -7, 11],
[7, -14, -8, 7],
[9, -15, -8, 7],
[8, -16, -10, 8],
[9, -15, -10, 8],
[8, -13, -10, 8],
[10, -14, -9, 9],
[8, -13, -9, 9],
[7, -11, -6, 6],
[7, -14, -7, 8],
[6, -9, -5, 4],
[5, -7, -5, 4],
[5, -7, -4, 5],
[4, -8, -4, 5],
[3, -6, -3, 3],
[4, -8, -3, 3],
[3, -9, -6, 3],
[6, -9, -4, 2],
[-19, -4, -9, -9],
[-18, -6, -9, -9],
[-20, -5, -10, -10],
[-18, -6, -10, -10],
[-17, -5, -10, -10],
[-16, -7, -11, -8],
[-17, -5, -11, -8],
[-16, -4, -8, -8],
[-19, -4, -10, -7],
[-15, 0, -5, -8],
[-16, -1, -5, -8],
[-17, 1, -4, -10],
[-16, -1, -4, -10],
[-14, -2, -4, -10],
[-15, -3, -6, -9],
[-14, -2, -6, -9],
[-12, -3, -6, -6],
[-15, 0, -7, -7],
[-20, 7, -1, -13],
[-21, 6, -1, -13],
[-22, 8, 0, -15],
[-21, 6, 0, -15],
[-19, 5, 0, -15],
[-20, 4, -2, -14],
[-19, 5, -2, -14],
[-17, 4, -2, -11],
[-20, 7, -3, -12],
[-12, 3, -2, -8],
[-14, 4, -2, -8],
[-13, 5, 0, -9],
[-14, 4, 0, -9],
[-13, 2, 0, -9],
[-15, 3, -1, -10],
[-13, 2, -1, -10],
[-12, 0, -4, -7],
[-12, 3, -3, -9],
[-8, -5, -7, -4],
[-9, -3, -7, -4],
[-7, -4, -6, -3],
[-9, -3, -6, -3],
[-10, -4, -6, -3],
[-11, -2, -5, -5],
[-10, -4, -5, -5],
[-11, -5, -8, -5],
[-8, -5, -6, -6],
[-1, -7, -6, 0],
[-2, -5, -6, 0],
[0, -6, -5, 1],
[-2, -5, -5, 1],
[-3, -6, -5, 1],
[-4, -4, -4, -1],
[-3, -6, -4, -1],
[-4, -7, -7, -1],
[-1, -7, -5, -2],
[-5, -11, -10, -1],
[-4, -10, -10, -1],
[-3, -12, -11, 1],
[-4, -10, -11, 1],
[-6, -9, -11, 1],
[-5, -8, -9, 0],
[-6, -9, -9, 0],
[-8, -8, -9, -3],
[-5, -11, -8, -2],
[-10, -7, -10, -4],
[-12, -6, -10, -4],
[-12, -6, -8, -5],
[-11, -8, -8, -5],
[-13, -7, -9, -6],
[-11, -8, -9, -6],
[-10, -10, -12, -3],
[-10, -7, -11, -5],
[-32, 16, 4, -23],
[-31, 14, 4, -23],
[-33, 15, 3, -24],
[-31, 14, 3, -24],
[-30, 15, 3, -24],
[-29, 13, 2, -22],
[-30, 15, 2, -22],
[-29, 16, 5, -22],
[-32, 16, 3, -21],
[-28, 20, 8, -22],
[-29, 19, 8, -22],
[-30, 21, 9, -24],
[-29, 19, 9, -24],
[-27, 18, 9, -24],
[-28, 17, 7, -23],
[-27, 18, 7, -23],
[-25, 17, 7, -20],
[-28, 20, 6, -21],
[-33, 27, 12, -27],
[-34, 26, 12, -27],
[-35, 28, 13, -29],
[-34, 26, 13, -29],
[-32, 25, 13, -29],
[-33, 24, 11, -28],
[-32, 25, 11, -28],
[-30, 24, 11, -25],
[-33, 27, 10, -26],
[-25, 23, 11, -22],
[-27, 24, 11, -22],
[-26, 25, 13, -23],
[-27, 24, 13, -23],
[-26, 22, 13, -23],
[-28, 23, 12, -24],
[-26, 22, 12, -24],
[-25, 20, 9, -21],
[-25, 23, 10, -23],
[-21, 15, 6, -18],
[-22, 17, 6, -18],
[-20, 16, 7, -17],
[-22, 17, 7, -17],
[-23, 16, 7, -17],
[-24, 18, 8, -19],
[-23, 16, 8, -19],
[-24, 15, 5, -19],
[82, -46, -11, 58],
[82, -46, -11, 57],
[81, -45, -11, 57],
[80, -45, -11, 57],
[79, -45, -11, 57],
[79, -46, -11, 57],
[79, -46, -12, 58],
[80, -46, -10, 57],
[79, -45, -10, 57],
[79, -44, -10, 57],
[79, -44, -9, 56],
[79, -44, -9, 55],
[78, -43, -9, 55],
[77, -43, -9, 55],
[77, -43, -10, 55],
[77, -43, -11, 56],
[77, -44, -11, 56],
[78, -45, -11, 56],
[79, -46, -11, 56],
[80, -46, -11, 56],
[80, -46, -10, 56],
[78, -44, -12, 56],
[79, -45, -12, 56],
[79, -46, -12, 56],
[79, -46, -13, 57],
[79, -46, -13, 58],
[80, -47, -13, 58],
[81, -47, -13, 58],
[81, -47, -12, 58],
[81, -47, -11, 57],
[81, -46, -11, 57],
[80, -45, -11, 57],
[79, -44, -11, 57],
[78, -44, -11, 57],
[78, -44, -12, 57],
[84, -50, -13, 60],
[83, -50, -13, 60],
[82, -49, -13, 60],
[82, -49, -13, 59],
[82, -49, -14, 59],
[81, -49, -14, 59],
[81, -50, -14, 59],
[81, -50, -15, 60],
[81, -50, -15, 61],
[82, -51, -15, 61],
[83, -51, -15, 61],
[84, -51, -15, 61],
[84, -50, -15, 61],
[84, -50, -14, 60],
[83, -49, -12, 59],
[82, -48, -12, 59],
[82, -47, -12, 59],
[82, -47, -11, 58],
[82, -47, -11, 57],
[81, -46, -11, 57],
[80, -46, -11, 57],
[80, -46, -12, 57],
[80, -46, -13, 58],
[80, -47, -13, 58],
[81, -48, -13, 58],
[82, -49, -13, 58],
[83, -49, -13, 58],
[83, -49, -12, 58],
[82, -48, -12, 59],
[81, -47, -12, 59],
[81, -46, -12, 59],
[81, -46, -11, 58],
[81, -46, -11, 57],
[80, -45, -11, 57],
[79, -45, -11, 57],
[79, -45, -12, 57],
[79, -45, -13, 58],
[79, -46, -13, 58],
[80, -47, -13, 58],
[81, -48, -13, 58],
[82, -48, -13, 58],
[82, -48, -12, 58],
[81, -45, -11, 57],
[81, -46, -11, 57],
[80, -46, -11, 57],
[80, -46, -12, 57],
[80, -46, -13, 58],
[80, -47, -13, 58],
[81, -48, -13, 58],
[81, -48, -13, 59],
[81, -48, -12, 59],
[82, -50, -14, 60],
[82, -49, -14, 60],
[82, -48, -14, 60],
[81, -47, -14, 60],
[81, -47, -14, 59],
[82, -46, -11, 57],
[82, -47, -11, 57],
[81, -47, -11, 57],
[81, -47, -12, 57],
[81, -47, -13, 58],
[81, -48, -13, 58],
[82, -49, -13, 58],
[82, -49, -13, 59],
[82, -49, -12, 59],
[83, -49, -12, 59],
[83, -48, -12, 59],
[83, -47, -12, 59],
[82, -46, -12, 59],
[82, -46, -12, 58],
[80, -45, -12, 57],
[81, -46, -12, 57],
[81, -47, -12, 57],
[81, -47, -13, 58],
[81, -47, -13, 59],
[82, -48, -13, 59],
[83, -48, -13, 59],
[83, -48, -12, 59],
[83, -48, -11, 58],
[83, -47, -11, 58],
[82, -46, -11, 58],
[81, -45, -11, 58],
[80, -45, -11, 58],
[80, -45, -12, 58]

  ]

  # 1) グループPCAで得た基底（ここでは簡易: 全データでPCAを実行して上位2軸を採用）
  # data_float = test_data_int.map { |r| r.map(&:to_f) }
  basis2, _ = SpectreMath.pca_components(test_data_int, 2, "demo") # returns two 4-d vectors (small-eig in implementation)
  if basis2.nil? || basis2.empty?
    # フォールバック: 単位ベクトルを使う（安全策）
    basis2 = [[1.0,0.0,0.0,0.0], [0.0,1.0,0.0,0.0]]
  end

  # 2) 凸包（2D射影上）作成
  proj_points = test_data_int.map { |pt| SpectreGeometry.project_to_2d(pt, basis2) }
  hull = SpectreGeometry.compute_convex_hull(proj_points)

  # 3) 射影残差分類（閾値自動設定）
  proj_class_results = SpectreMath.classify_by_projection(test_data_int, basis2, threshold_sq: nil)

  # 4) 凸包内判定（2D射影）
  hull_results = proj_points.map { |p2| SpectreGeometry.point_inside_polygon?(p2, hull) }

  # 5) 結合判定と出力（1行毎）
  puts "Idx, point (a0,a1,b0,b1), proj(x|y), residual_norm_sq, in_by_residual, in_by_hull, final_in_inside/is_extra"
  proj_class_results.each_with_index do |r, i|
    p = r[:point]
    proj_xy = proj_points[i]
    residual_norm_sq = r[:residual_norm_sq]  # 2乗のまま
    residual_norm = Math.sqrt(residual_norm_sq)  # 出力用に平方根を取る
    in_res = r[:in_inside_by_residual] ? "IN" : "OUT"
    in_hull = hull_results[i] ? "IN" : "OUT"
    # 最終判定: 両方のメソッドでINなら in_inside, どちらもOUTなら is_extra, 片方のみINは borderline → treat as IN
    final = (r[:in_inside_by_residual] || hull_results[i]) ? "in_inside" : "is_extra"

    puts "#{i+1}, [#{p.join(',')}], (#{'%.4f' % proj_xy[0]}|#{'%.4f' % proj_xy[1]}), #{'%.6f' % residual_norm}, #{in_res}, #{in_hull}, #{final}"
  end

  puts "\nDemo complete. Legend: final=in_inside  (accepted), is_extra (rejected)"

    puts "\n" + "=" * 140

    # テスト用整数データ（既に定義済みの test_data_int を再利用）
    puts "\n📊 テストデータ: test_data_int (#{test_data_int.size}点)"
    puts "   特徴: 整数座標のみ、値域が大きい（-12～3）"

    # ======== 1. 通常PCA (Float版) の実行 ========
    begin
      puts "\n【1】通常PCA (SpectreMath.pca_components - Float版)"
      # 配列サイズ4になるよう調整（pca_componentsは指定された数しか返さないがverify_pca_resultsは4つを要求する場合がある）
      # ここでは pca_components(..., 4) で呼んでいない場合、固有値等が4つ揃わない可能性があるため
      # 検証用に再度 4成分で計算し直す、あるいは verify_pca_results の要件に合わせてダミーを詰める等が考えられるが
      # 計画通り verify_pca_results は 4成分必須とするため、4成分で計算する。
      basis_standard_4, lambdas_standard_4 = SpectreMath.pca_components(test_data_int, 4, "standard_pca_verify")
      SpectreMath.verify_pca_results(
        test_data_int,
        basis_standard_4,
        lambdas_standard_4,
        label: "【1】通常PCA検証 (Float)",
        io: $stdout,
        projection_tolerance: test_data_int.size*0.01,
        check_algebraic: true
      )
      puts "✅ 通常PCA検証 PASS"
    rescue => e
      puts "❌ #{e.message}"
    end

  # ============================================================
  # 【追加】高精度PCA vs 通常PCA の精度差異検証
  # ============================================================
  if HIGHPRECISION_AVAILABLE
    # ======== 2. 高精度PCA (BigDecimal版) の実行 ========
    begin
      puts "\n【2】高精度PCA (HighPrecisionMath.high_precision_pca_int - BigDecimal版)"
      HighPrecisionMath.set_scale(200)  # 200桁精度に設定
      basis_hp, lambdas_hp = HighPrecisionMath.high_precision_pca_int(test_data_int, 4, "highprecision_pca")
      SpectreMath.verify_pca_results(
        test_data_int,
        basis_hp,
        lambdas_hp,
        label: "【2】高精度PCA検証 (BigDecimal)",
        io: $stdout,
        projection_tolerance: test_data_int.size*0.01,
        check_algebraic: true
      )
      puts "✅ 高精度PCA検証 PASS"
    rescue => e
      puts "❌ #{e.message}"
    end

    # ======== 3. 基底ベクトルの差異を符号不変で定量化（変更） ========
    puts "\n【3】基底ベクトルの差異評価（符号不変）"

    # ヘルパ: ベクトル正規化
    normalize_vec = ->(v) {
      mag = Math.sqrt(v.map { |x| x**2 }.sum)
      mag.zero? ? v : v.map { |x| x / mag }
    }

    diffs = []
    sign_flips = []

    # 4成分比較
    (0...4).each do |i|
      std_v = normalize_vec.call(basis_standard_4[i])
      hp_v = normalize_vec.call(basis_hp[i].map(&:to_f))

      diff_direct = std_v.zip(hp_v).map { |a, b| (a - b).abs }.max
      diff_neg = std_v.zip(hp_v.map { |x| -x }).map { |a, b| (a - b).abs }.max

      if diff_neg < diff_direct
        diffs << diff_neg
        sign_flips << true
      else
        diffs << diff_direct
        sign_flips << false
      end
    end

    # 簡易表示
    diffs.each_with_index do |d, i|
       puts "  基底[#{i}] 差分: #{format('%.10e', d)} (Flip: #{sign_flips[i]})"
    end

    # 固有値（小さい順）の比較（符号や並びの確認）
    # verify_pca_resultsで詳細が出ているので、ここでは差分のみ簡潔に
    lambdas_std_sorted = lambdas_standard_4.sort_by(&:abs)
    lambdas_hp_f = lambdas_hp.map(&:to_f) # hpはすでにsort済み(pca_int内)

    lambda_diffs = lambdas_std_sorted.zip(lambdas_hp_f).map { |a, b| (a - b).abs }
    puts "  固有値差分: #{lambda_diffs.map { |d| format('%.10e', d) }.join(', ')}"

    if diffs.all? { |d| d < SpectreMath.get_math_context(diffs[0].class.name, SpectreMath::CONVERGENCE_EPSILON) } &&
       lambda_diffs.all? { |d| d < SpectreMath.get_math_context(lambda_diffs[0].class.name, SpectreMath::CONVERGENCE_EPSILON) }
      puts "  ✅ 基底・固有値は実質一致（符号反転を除く）"
    else
      puts "  ⚠️ 基底または固有値に有意な差異あり（符号反転は許容）"
    end

  else
    puts "\n【追加テスト：スキップ】"
    puts "  HighPrecisionMath モジュールが利用不可"
    puts "  詳細テストを実行するには HighPrecisionMath/HighPrecisionMath.rb を配置してください"
  end


  # [7] SpectreDataLoader のビルダー注入テスト
  puts "\n【7】SpectreDataLoader のビルダー注入テスト"
  begin
    # HighPrecisionビルダーを定義
    hp_builder = ->(key, result_points) { HighPrecisionPCAGroupStatistics.new(key, result_points) }

    # ローダー生成 (builder注入)
    # ここではテスト用のモック列挙子を使用
    mock_shapes = [
      ShapeInfo.new([Vector[0,0,0,0], Vector[1,0,0,0], Vector[1,1,0,0]], 0.0, 1.0, shape_id: "mock1")
    ]
    # shapeのverticesを増やすために複製
    mock_shapes[0].instance_variable_set(:@vertices, test_data_int.take(4).map{|a| Vector.elements(a)})

    mock_enum = mock_shapes.each

    loader = SpectreDataLoader.new(statistics_builder: hp_builder)
    loader.load(mock_enum).analyze!

    manager = loader.statistics_manager
    # 登録された統計情報が HighPrecisionPCAGroupStatistics であるか確認
    # (StatisticsManager#groups は公開されていないため、instance_variable_getで確認するか、valid?で推測)
    registered_stats = manager.instance_variable_get(:@groups)["mock1"] # keyは shape.group_key = "0.0-1.0" のはずだが...
                                                                     # ShapeInfoデフォルトは 0.0-1.0

    registered_stats = manager.instance_variable_get(:@groups).values.first

    if registered_stats.is_a?(HighPrecisionPCAGroupStatistics)
      puts "  ✓ HighPrecisionPCAGroupStatistics が正しく注入・生成されました"
      puts "    Class: #{registered_stats.class}"
    else
      puts "  ❌ ビルダー注入失敗: 期待されるクラスではありません"
      puts "    Actual: #{registered_stats.class}"
    end

    # 標準ビルダー（デフォルト）のテスト
    loader_std = SpectreDataLoader.new
    loader_std.load(mock_enum).analyze!
    stats_std = loader_std.statistics_manager.instance_variable_get(:@groups).values.first
    if stats_std.is_a?(PCAGroupStatistics)
      puts "  ✓ デフォルトビルダー (PCAGroupStatistics) が正しく動作しました"
    else
      puts "  ❌ デフォルトビルダー失敗"
    end

  rescue => e
    puts "  ❌ SpectreDataLoader テスト失敗: #{e.message}"
    puts e.backtrace
  end

    # HighPrecisionPCAGroupStatistics の直接生成テスト
    if defined?(HighPrecisionPCAGroupStatistics)
      puts "\n【追加検証】HighPrecisionPCAGroupStatistics の動作確認"

      # テストデータ (Integer) を用意
      hp_test_data = [
        Vector[0, 0, 0, 0],
        Vector[10, 0, 0, 0],
        Vector[0, 10, 0, 0],
        Vector[0, 0, 10, 0]
      ]

      hp_stats = HighPrecisionPCAGroupStatistics.new("hp-test", hp_test_data, 0)
      puts "  ✓ インスタンス生成成功: #{hp_stats.class}"
      puts "  ✓ 基底ベクトル数: #{hp_stats.basis_vectors.size}"
      puts "  ✓ 基底ベクトル型: #{hp_stats.basis_vectors.first.first.class} (Expected: BigDecimal)"

      # valid? チェック
      in_point = Vector[2, 2, 2, 0] # 凸包内（たぶん）
      is_valid = hp_stats.valid?(in_point)
      puts "  ✓ valid? 判定 (in_point): #{is_valid}"
    end

end # main
