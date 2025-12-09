require 'matrix'
require 'bigdecimal'
require 'bigdecimal/math' # BigMath のために必要

module HighPrecisionMath
  # --- 共通定数と制御変数 ---

  # 1. 精度設定 (標準値: 200桁)
  @@precision = 200

  # 3. ゼロ判定用最小値 (極端なゼロ除算回避用)
  @@singularity_threshold = BigDecimal('10') ** (-180)

  # 2. 収束判定用イプシロン (初期値)
  @@convergence_epsilon = BigDecimal('10') ** (-160)

  # 3. ジオメトリック判定用イプシロン (初期値)
  @@geometric_tolerance = BigDecimal('10') ** (-16)

  # --- 設定変更メソッド ---

  # 外部から精度を設定し、関連する定数を更新する
  def self.set_scale(new_precision)
    raise ArgumentError, "Precision must be a positive integer." unless new_precision.is_a?(Integer) && new_precision > 0

    @@precision = new_precision
    BigDecimal.limit(@@precision) # BigDecimalのグローバル精度を更新

    # イプシロンと最小値を新しい精度に連動させて更新
    # 収束判定には有効桁数全体を使用するのが安全なため、10^(-PRECISION) を採用
    @@singularity_threshold = BigDecimal('10') ** (-(@@precision*0.9).to_i) # 極端なゼロ除算回避用は、最も厳しく
    @@convergence_epsilon = BigDecimal('10') ** (-(@@precision*0.8).to_i) # 収束判定用イプシロンは、若干緩く
    @@geometric_tolerance = BigDecimal('10') ** (-16) # ジオメトリック判定用イプシロンは、最も緩く

    puts "✅ HighPrecisionMath scale updated: PRECISION=#{@@precision}, EPSILON=#{@@convergence_epsilon.to_s('E')}"
    return @@precision
  end

  # 現在の精度を取得
  def self.precision
    @@precision
  end

  # 現在のイプシロンを取得
  def self.epsilon
    @@convergence_epsilon
  end

  # --- 1. 高精度数学関数 ---

  # BigDecimalでの平方根 (BigDecimalインスタンスメソッドを使用)
  # 負の値に対しては FloatDomainError が自動的に発生する。
  # ゼロに対しては BigDecimal('0') が返る。
  def self.sqrt(x)
    x.sqrt(@@precision)
  end

  # BigDecimalでの atan2 (BigMath::atan と BigMath::PI を使用)
  def self.atan2(y, x)
    pi = BigMath::PI(@@precision) # 現在の精度でPIを取得

    if x.abs < @@singularity_threshold
      # 垂直方向 (x ≈ 0)
      if y > BigDecimal('0')
        return pi / BigDecimal('2') # +π/2
      elsif y < BigDecimal('0')
        return -(pi / BigDecimal('2')) # -π/2
      else
        raise RuntimeError, "atan2(0, 0) is undefined."
      end
    end

    ratio = y / x
    atan_val = BigMath::atan(ratio, @@precision) # 現在の精度で atan を計算

    # 象限の調整
    if x < BigDecimal('0')
      if y >= BigDecimal('0')
        atan_val += pi # 第二象限
      else
        atan_val -= pi # 第三象限
      end
    end

    atan_val
  rescue ZeroDivisionError => e
    raise "Exception in atan2 due to unexpected zero division: #{e.message}"
  end

  # --- 2. ベクトル/行列演算 ---
  # BigDecimal 対応の外積 (outer product)
  # v1, v2 は配列または Vector。要素は BigDecimal か数値で指定可能。
  def self.outer_product(v1, v2)
    a1 = v1.respond_to?(:to_a) ? v1.to_a : v1
    a2 = v2.respond_to?(:to_a) ? v2.to_a : v2

    # 要素を BigDecimal に統一
    a1_bd = a1.map { |x| x.is_a?(BigDecimal) ? x : BigDecimal(x.to_s) }
    a2_bd = a2.map { |x| x.is_a?(BigDecimal) ? x : BigDecimal(x.to_s) }

    Matrix.rows(a1_bd.map { |x| a2_bd.map { |y| x * y } })
  end

  # ベクトルの内積 (BigDecimal)
  def self.dot_product(v1, v2)
    raise ArgumentError, "Vector sizes must match: #{v1.size} != #{v2.size}" unless v1.size == v2.size
    v1.to_a.zip(v2.to_a).map { |a, b| a * b }.reduce(BigDecimal('0.0'), :+)
  end

  # ベクトルの正規化 (BigDecimal)
  def self.normalize(v)
    norm_sq = dot_product(v, v)

    # ノルムが極端にゼロに近い場合
    if norm_sq.abs < @@singularity_threshold
        raise RuntimeError, "Cannot normalize a near-zero vector. Norm: #{norm_sq.to_s('E')}"
    end

    norm = sqrt(norm_sq)
    v.map { |x| x / norm }
  end

  # Gram-Schmidt直交化
  def self.gram_schmidt(vectors)
    ortho_vectors = []

    vectors.each_with_index do |v, i|
        w = v.dup
        ortho_vectors.each do |u_i|
            dot_v_u = dot_product(v, u_i)
            dot_u_u = dot_product(u_i, u_i)

            # 直交基底が近ゼロでないかチェック (@@singularity_threshold を使用)
            if dot_u_u.abs < @@singularity_threshold
                raise RuntimeError, "Gram-Schmidt encountered a near-zero basis vector (u#{ortho_vectors.size}) during orthogonalization."
            end

            alpha = dot_v_u / dot_u_u
            projection = u_i.map { |x| x * alpha }
            w = w - projection
        end

        # ゼロベクトル判定: w がゼロベクトルに近い場合、正規化せずにスキップ
        if dot_product(w, w).abs < @@singularity_threshold
            # ゼロベクトルと見なす。この軸は線形従属なのでスキップする。
            puts "⚠️ Warning: Gram-Schmidt skipped a near-zero vector (linearly dependent axis)."
            next
        end
        # 正規化
        ortho_vectors << normalize(w)
    end


    ortho_vectors
  end

  # 連分数展開 (Continued Fraction Expansion)
  # Input: x (BigDecimal) - 展開したい数値
  #        max_terms (Integer) - 最大項数 (デフォルト: 20)
  # Output: Array<Integer> - 連分数の係数 [a0, a1, a2, ...]
  #
  # x = a0 + 1/(a1 + 1/(a2 + 1/(a3 + ...)))
  #
  # 負の数の場合、floor を正しく適用して展開する
  # 例: -0.5 = -1 + 0.5, つまり [-1, 2]
  # --- 連分数展開 (Continued Fraction) ---
  # 符号を最初の要素（"+" または "-"）として分離し、
  # 第2要素以降に非負の整数（絶対値）を格納する形式に変更
  def self.continued_fraction(val, max_terms: 20)
    # 値が数値でない、または無限大/NaNの場合はエラーシンボルを返す
    return [:error] unless val.is_a?(Numeric) && val.finite?

    # --- 1. 符号の分離 ---
    sign = (val >= 0) ? "+" : "-"
    x_abs = val.abs

    # 整数に近い場合は即座に終了 (絶対値で判定)
    if (x_abs - x_abs.round).abs < epsilon
        # [符号, 整数値] を返す
        return [sign, x_abs.round]
    end

    coeffs = []
    x = x_abs # 正の値から展開を開始

    max_terms.times do
        i = x.floor # i は常に非負
        coeffs << i
        x = x - i

        if x.abs < epsilon
            break
        end

        begin
            # ここでは正の値の逆数を取るため、xは必ず正
            x = 1.0 / x
        rescue ZeroDivisionError
            break
        end

        # 発散チェック
        if x.abs > 1.0/epsilon
            # 発散項は通常省略
            break
        end
    end

    # [符号, a0, a1, a2, ...] の形式で返す
    return [sign] + coeffs
  end

  # 連分数係数からBigDecimalを復元
  # Input: coeffs (Array<Integer>) - 連分数の係数
  # Output: BigDecimal - 復元された値
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

  # --- 3. 高精度固有値分解: Jacobi法 ---

  # Matrix m は必ず BigDecimal の要素を持つ対称行列 (4x4) を想定
  def self.jacobi_eigen(m, max_iter: 500)
    n = m.row_count
    raise ArgumentError, "Matrix must be 4x4, got #{n}x#{n}" unless n == 4

    # 対称性のチェック
    n.times do |i|
      (i + 1).upto(n - 1) do |j|
        diff = (m[i, j] - m[j, i]).abs
        if diff > @@convergence_epsilon
          raise ArgumentError, "Input Matrix is not symmetric (m[#{i}, #{j}] != m[#{j}, #{i}]), difference: #{diff.to_s('E')}"
        end
      end
    end

    a = m.map { |x| x } # 現在の行列 (対角化される)
    v = Matrix.identity(n).map { |x| BigDecimal(x.to_s) } # 固有ベクトル行列

    iter = 0

    while iter < max_iter
      max_off_diag = BigDecimal('0')
      p, q = 0, 0

      # 1. 最大の非対角要素を見つける
      n.times do |i|
        (i + 1).upto(n - 1) do |j|
          off_diag = a[i, j].abs
          if off_diag > max_off_diag
            max_off_diag = off_diag
            p, q = i, j
          end
        end
      end

      # 2. 収束判定
      if max_off_diag < @@convergence_epsilon
        break
      end

      # 3. 回転角の計算 (tau から t = tan(theta) を導出)
      # tau = (Aqq - App) / 2Apq
      tau = (a[q, q] - a[p, p]) / (BigDecimal('2') * a[p, q])

      # t = tan(theta) = sgn(tau) / (|tau| + sqrt(tau^2 + 1))
      t_denom = sqrt(tau**2 + 1)

      # ゼロ除算回避 (tau が極端に大きくても t_denom は 1 に近いため問題ない)
      t = tau >= 0 ?
          (BigDecimal('1') / (tau + t_denom)) :
          (BigDecimal('-1') / (-tau + t_denom))

      # c = cos(theta), s = sin(theta)
      c_denom = sqrt(t**2 + 1)
      c = BigDecimal('1') / c_denom
      s = t * c

      [c, s, t].each do |val|
        raise RuntimeError, "Non-finite value detected in c/s/t: #{val.to_s}" unless val.finite?
      end

      # 4. 行列 A の更新 (A = J^T A J)
      a_new = a.map { |x| x }
      n.times do |k|
        if k != p && k != q
          a_pk = c * a[p, k] - s * a[q, k]
          a_qk = s * a[p, k] + c * a[q, k]
          a_new[p, k] = a_pk; a_new[k, p] = a_pk
          a_new[q, k] = a_qk; a_new[k, q] = a_qk
        end
      end
      a_new[p, p] = a[p, p] - t * a[p, q]
      a_new[q, q] = a[q, q] + t * a[p, q]
      a_new[p, q] = BigDecimal('0'); a_new[q, p] = BigDecimal('0')
      a = a_new

      # 5. 固有ベクトル行列 V の更新 (V = V J)
      v_new = Matrix.build(n, n) { |r, c| v[r, c] }
      n.times do |k|
        v_kp = v[k, p] * c - v[k, q] * s
        v_kq = v[k, p] * s + v[k, q] * c
        v_new[k, p] = v_kp
        v_new[k, q] = v_kq
      end
      v = v_new

      iter += 1
    end

    if iter >= max_iter
      raise "Maximum iterations reached (#{max_iter}). Jacobi failed to converge."
    end

    eigenvalues = n.times.map { |i| a[i, i] }
    eigenvectors = v.column_vectors

    return eigenvalues, eigenvectors
  end

  def self.high_precision_pca_int(data_int,n_components=2,key="")
    return [] if data_int.empty?

    m = data_int.size # 行数 (サンプル数)
    n = data_int.first.size # 列数 (特徴量数、ここでは4を想定)

    # --- 1. Integer データを BigDecimal に変換 (メモリは増えるが、高精度化のため必須) ---
    # Integer から直接 BigDecimal オブジェクトを作成するため、Float の丸め誤差を回避
    data = data_int.map { |row| row.map { |x| BigDecimal(x.to_s) } }

    # --- 2. 平均値 (Mean) の計算 (転置を避ける) ---

    col_sums = Array.new(n, BigDecimal('0.0'))

    data.each do |row|
      n.times { |j| col_sums[j] += row[j] }
    end

    m_big = BigDecimal(m.to_s)
    mean = Vector.elements(col_sums.map { |sum| sum / m_big })

    # --- 3. 共分散行列 (Covariance Matrix) の計算 (Centered Arrayを回避) ---

    # Covariance Matrix は n x n (4x4)
    cov_matrix = Matrix.zero(n).map { |x| BigDecimal('0.0') }

    data.each do |row|
      v = Vector.elements(row)
      centered_v = v - mean

      # 外積 outer_product(v, v) を手動で計算し、cov_matrix に加算
      n.times do |i|
        n.times do |j|
          term = centered_v[i] * centered_v[j]
          # Matrixの要素を更新
          # Matrix#[]= はRuby 3.3.0で非推奨の場合があるため、一時的に配列に戻して操作
          cov_matrix_array = cov_matrix.to_a
          cov_matrix_array[i][j] += term
          cov_matrix = Matrix.rows(cov_matrix_array)
        end
      end
    end

    # 共分散行列を m で割る
    cov_matrix = cov_matrix.map { |x| x / m_big }

    # ----------------------------------------------------
    # 4. 固有値分解 (Jacobi法)
    # ----------------------------------------------------

    eigenvalues, eigenvectors = HighPrecisionMath.jacobi_eigen(cov_matrix)

    # ----------------------------------------------------
    # 5. 固有値のソートと主成分の抽出
    # ----------------------------------------------------

    # 固有値を絶対値で昇順ソート (小さい順)
    sorted_results = eigenvalues.zip(eigenvectors)
                              .sort_by { |val, _| val.abs }

    # n_components個の小さい固有値に対応する固有ベクトルを抽出
    extracted_vectors = sorted_results.first(n_components).map { |_, vec| vec }

    # 直交性を保証するための Gram-Schmidt直交化
    final_components = HighPrecisionMath.gram_schmidt(extracted_vectors)

    # 最終結果は BigDecimal の Vector の配列と全固有値
    # 返り値: [固有ベクトル配列, 最小n_components個の固有値]
    [final_components.map { |vec| vec.to_a }, sorted_results.first(n_components).map { |lambda, _| lambda }]
  end
end

# --- 初期設定の実行 ---
HighPrecisionMath.set_scale(200)

# --- テストと使用例 ---
if __FILE__ == $0
  puts "\n--- HighPrecisionMath テスト ---"

  # 1. 精度変更のテスト
  HighPrecisionMath.set_scale(50)

  # 2. 定数確認
  puts "Current PRECISION: #{HighPrecisionMath.precision}"
  puts "Current EPSILON:   #{HighPrecisionMath.epsilon.to_s('E')}"

  # 3. atan2のテスト
  y = BigDecimal('1')
  x = BigDecimal('-1')
  result = HighPrecisionMath.atan2(y, x)

  # 期待値: 3π/4 (第二象限)
  expected_pi = BigMath::PI(HighPrecisionMath.precision)
  expected = expected_pi * BigDecimal('0.75')

  puts "\natan2(1, -1) Result:  #{result.to_s('E')}"
  puts "atan2(1, -1) Expected: #{expected.to_s('E')}"

  # 4. Gram-Schmidtのテスト (簡単な基底)
  v1 = Vector.elements([BigDecimal('1'), BigDecimal('0'), BigDecimal('0')])
  v2 = Vector.elements([BigDecimal('1'), BigDecimal('1'), BigDecimal('0')])

  ortho = HighPrecisionMath.gram_schmidt([v1, v2])

  puts "\nGram-Schmidt Result (v1 · v2'):"
  dot_test = HighPrecisionMath.dot_product(ortho[0], ortho[1])
  puts "  内積: #{dot_test.to_s('E')}"

  if dot_test.abs < HighPrecisionMath.epsilon
    puts "  ✅ 直交性検証成功 (内積はイプシロン以下)"
  end

  # 5. 連分数展開のテスト
  puts "\n--- 🔢 連分数展開テスト ---"

  # √2 の連分数展開 (理論値: [1; 2, 2, 2, 2, ...])
  sqrt2_test = HighPrecisionMath.sqrt(BigDecimal('2'))
  cf_sqrt2 = HighPrecisionMath.continued_fraction(sqrt2_test, max_terms: 10)
  puts "√2 の連分数展開: #{cf_sqrt2.inspect}"
  puts "  (理論値: [1, 2, 2, 2, 2, ...])"

  # π の連分数展開 (不規則的)
  pi_test = BigMath::PI(HighPrecisionMath.precision)
  cf_pi = HighPrecisionMath.continued_fraction(pi_test, max_terms: 10)
  puts "\nπ の連分数展開: #{cf_pi.inspect}"
  puts "  (不規則的なパターン)"

  # 黄金比 φ = (1+√5)/2 の連分数展開 (理論値: [1; 1, 1, 1, ...])
  phi_test = (BigDecimal('1') + HighPrecisionMath.sqrt(BigDecimal('5'))) / BigDecimal('2')
  cf_phi = HighPrecisionMath.continued_fraction(phi_test, max_terms: 10)
  puts "\n黄金比 φ の連分数展開: #{cf_phi.inspect}"
  puts "  (理論値: [1, 1, 1, 1, 1, ...])"

  # 復元テスト
  restored_sqrt2 = HighPrecisionMath.continued_fraction_to_decimal(cf_sqrt2)
  error_sqrt2 = (sqrt2_test - restored_sqrt2).abs
  puts "\n✅ 復元テスト (√2):"
  puts "  元の値:   #{sqrt2_test.to_s('E')}"
  puts "  復元値:   #{restored_sqrt2.to_s('E')}"
  puts "  誤差:     #{error_sqrt2.to_s('E')}"

  # --- Jacobi法テストコード (検算付き) ---

  # 初期設定
  HighPrecisionMath.set_scale(200)
  PRECISION = HighPrecisionMath.precision
  EPSILON = HighPrecisionMath.epsilon

  puts "\n--- 🔬 Jacobi法 (無理数係数) 検算テスト ---"

  # ----------------------------------------------------
  # 1. テスト用対称行列 A の定義 (無理数を係数に含む)
  # ----------------------------------------------------

  # 無理数定義
  sqrt2 = HighPrecisionMath.sqrt(BigDecimal('2'))
  sqrt3 = HighPrecisionMath.sqrt(BigDecimal('3'))

  # 意図的に構成した4x4対称行列 A (固有値が 1, 2, 1e-5, 1e-10 に近い行列)
  # 全ての要素を BigDecimal で定義
  a11 = BigDecimal('5') + sqrt2
  a12 = sqrt3 / BigDecimal('2')
  a34 = BigDecimal('1e-10') * sqrt2

  m_array = [
    [a11,             a12,             BigDecimal('0'), a34],
    [a12,             BigDecimal('4'), BigDecimal('0'), BigDecimal('0')],
    [BigDecimal('0'), BigDecimal('0'), BigDecimal('1e-5'), BigDecimal('0')],
    [a34,             BigDecimal('0'), BigDecimal('0'), BigDecimal('1e-10') + BigDecimal('1e-15')]
  ]

  test_matrix = Matrix.rows(m_array)

  puts "📝 入力行列 A (一部抜粋):"
  puts "  A[0,0]: #{test_matrix[0, 0].to_s('E')}"
  puts "  A[0,1]: #{test_matrix[0, 1].to_s('E')}"

  # ----------------------------------------------------
  # 2. Jacobi法による固有値分解の実行
  # ----------------------------------------------------

  begin
    eigenvalues, eigenvectors = HighPrecisionMath.jacobi_eigen(test_matrix)

    puts "\n✅ 固有値分解 実行成功"

    # 固有値と固有ベクトルをペアにして、絶対値の小さい順にソート
    sorted_results = eigenvalues.zip(eigenvectors)
                               .sort_by { |val, _| val.abs }

    puts "\n📊 ソートされた固有値 (絶対値が小さい順):"

    # ----------------------------------------------------
    # 3. 検算 (A*v = lambda*v の検証)
    # ----------------------------------------------------
    puts "\n--- 🔢 固有対の検算 (A * v - lambda * v) ---"

    sorted_results.each_with_index do |(lambda_val, v_vec), i|

      # (A * v) の計算
      a_times_v = test_matrix * v_vec

      # (lambda * v) の計算
      lambda_times_v = v_vec.map { |x| x * lambda_val }

      # 残差 (Residual) = (A * v) - (lambda * v)
      residual = a_times_v - lambda_times_v

      # 残差ベクトルのノルム (L2ノルム) を計算
      residual_norm = HighPrecisionMath.sqrt(HighPrecisionMath.dot_product(residual, residual))

      puts "  λ#{i+1} (値: #{lambda_val.to_s('E')}):"
      puts "    残差ノルム: #{residual_norm.to_f}"

      # 検証
      if residual_norm < EPSILON * BigDecimal('1e5') # 許容誤差を EPSILON の 10^5 倍に設定 (収束精度より緩く)
        puts "    → 検算OK"
      else
        puts "    → ❌ 検算失敗: 残差が許容範囲外です"
      end
    end

    # ----------------------------------------------------
    # 4. Gram-Schmidt直交化とゼロベクトル確認
    # ----------------------------------------------------

    # 最小の2つの固有ベクトルを抽出 (PC3, PC4に対応)
    min_eigenvectors = sorted_results.first(2).map { |_, vec| vec }
    orthogonalized_vectors = HighPrecisionMath.gram_schmidt(min_eigenvectors)

    puts "\n--- 💡 最小変動基底の直交化と確認 ---"
    v3 = orthogonalized_vectors[0]
    v4 = orthogonalized_vectors[1]

    # 最小変動ベクトルの内積 (直交性)
    dot_product_v3_v4 = HighPrecisionMath.dot_product(v3, v4)
    puts "  PC3 · PC4 (内積): #{dot_product_v3_v4.to_s('E')}"

    # 最小変動ベクトルが元のデータに掛けたときに概ねゼロになることの確認 (これはPCAの定義に戻る)
    # ここでは、データ行列 X が不明なため、最小固有値の確認がこれに相当する。

  rescue ArgumentError, RuntimeError => e
    puts "\n❌ エラーが発生しました: #{e.message}"
    e.backtrace.each { |line| puts line }
  end

  puts "\n--- High Precision PCA (Integer Input) 実行テスト ---"

  # 仮想データ (Integerの配列として入力)
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
[-24, 15, 5, -19]
  ]

  # 4つの固有値と固有ベクトルを取得
  components, lambdas = HighPrecisionMath.high_precision_pca_int(test_data_int, 4)

  begin
    puts "✅ PCA計算成功 (Integer入力, 高精度)"

    # 抽出された主成分の表示
    components.each_with_index do |vec, i|
      puts "  Component #{i+1}:"
      vec.each_with_index do |val, j|
        puts "    v[#{j}]: #{val.to_s('F')[0..60]}..."
        cf = HighPrecisionMath.continued_fraction(val, max_terms: 20)
        puts "           連分数: #{cf.inspect}"
      end
    end

    # --- 残差分析 (Residual Analysis) ---
    puts "\n--- 📉 残差分析: データと抽出基底との射影 ---"
    puts "=" * 140

    # 1. BigDecimal化と平均値の計算
    m_size = test_data_int.size
    n_cols = test_data_int[0].size
    m_bd = BigDecimal(m_size.to_s)

    data_bd = test_data_int.map { |row| row.map { |x| BigDecimal(x.to_s) } }

    col_sums = Array.new(n_cols, BigDecimal('0'))
    data_bd.each { |row| row.each_with_index { |x, j| col_sums[j] += x } }
    mean_vals = col_sums.map { |s| s / m_bd }

    puts "データの平均値: [#{mean_vals.map { |x| x.round(6).to_f }.inspect}]"

    # 2. 各データの残差計算と表示
    puts "\n各データ点と抽出基底との内積 (中心化後の射影値):"
    puts "  形式: Data[i] → [Component1への射影, Component2への射影]"

    mae_sums = Array.new(components.size, BigDecimal('0')) # Mean Absolute Error用

    data_bd.each_with_index do |row, i|
      # 中心化
      centered = row.zip(mean_vals).map { |x, mu| x - mu }

      # 各コンポーネントとの内積（射影値）
      projections = components.map do |comp|
        centered.zip(comp).map { |a, b| a * b }.sum(BigDecimal('0'))
      end

      # 統計蓄積
      projections.each_with_index { |val, j| mae_sums[j] += val.abs }

      puts "  Data[#{i.to_s.rjust(2)}]: [#{projections.map { |x| format('%20.10e', x.to_f) }.join(', ')}]"
    end

    # 3. 平均残差の表示
    puts "\n📊 射影の平均絶対値 (Mean Absolute Projection):"
    components.each_with_index do |_, j|
      mae = mae_sums[j] / m_bd
      puts "  Component #{j+1}: #{format('%.10e', mae.to_f)}"
    end

    puts "\n💡 解釈:"
    puts "  - 射影値が小さい → データがその基底方向に変動しない（正しいPCA）"
    puts "  - 射影値が大きい → データがその基底方向に変動する（基底が主成分を捉えていない）"
    puts "=" * 140

    # --- 4つの固有値と固有ベクトルの詳細検証 ---
    puts "\n🔬 4つの固有値と固有ベクトルの詳細検証"
    puts "=" * 140

    puts "📊 固有値 (小さい順):"
    lambdas.each_with_index do |lambda_val, i|
      puts "  λ#{i+1}: #{format('%.10e', lambda_val.to_f)}"
    end

    # 固有値の合計と寄与率の計算
    sum_lambdas = lambdas.map { |λ| λ.abs }.sum
    puts "\n📈 寄与率:"
    lambdas.each_with_index do |lambda_val, i|
      contribution = (lambda_val.abs / sum_lambdas * 100)
      # 固定小数点で小数点下2桁表示
      puts "  λ#{i+1} の寄与率: #{format('%.2f', contribution)}%"
    end

    cumsum = 0.0
    puts "\n📊 累積寄与率:"
    lambdas.each_with_index do |lambda_val, i|
      cumsum += (lambda_val.abs / sum_lambdas * 100)
      puts "  λ1～λ#{i+1}: #{format('%.2f', cumsum)}%"
    end

    # --- 固有ベクトルの正規化と直交性の検証 ---
    puts "\n✅ 固有ベクトルの検証:"
    puts "=" * 140

    puts "【正規化チェック】"
    components.each_with_index do |vec, i|
      vec_bd = Vector.elements(vec)
      norm = HighPrecisionMath.sqrt(HighPrecisionMath.dot_product(vec_bd, vec_bd))

      puts "  v#{i+1} のノルム: #{format('%.10f', norm.to_f)}"
      puts "    → #{(norm - 1.0).abs < 1e-6 ? '✅ 正規化済み' : '⚠️ 正規化されていない'}"
    end

    puts "\n【直交性チェック】"
    components.each_with_index do |vec_i, i|
      vec_i_bd = Vector.elements(vec_i)
      (i + 1).upto(components.size - 1) do |j|
        vec_j_bd = Vector.elements(components[j])
        dot_prod = HighPrecisionMath.dot_product(vec_i_bd, vec_j_bd)

        puts "  v#{i+1} · v#{j+1}: #{format('%.10e', dot_prod.to_f)}"
        puts "    → #{dot_prod.abs < 1e-6 ? '✅ 直交' : '⚠️ 非直交'}"
      end
    end

    # --- 固有値方程式 A*v = λ*v の検証 ---
    puts "\n【固有値方程式 A*v = λ*v の検証】"
    puts "=" * 140

    # 共分散行列を計算
    data = test_data_int.map { |row| row.map { |x| BigDecimal(x.to_s) } }
    col_sums = Array.new(4, BigDecimal('0.0'))
    data.each { |row| 4.times { |j| col_sums[j] += row[j] } }
    m_big = BigDecimal(test_data_int.size.to_s)
    mean = Vector.elements(col_sums.map { |sum| sum / m_big })

    cov_matrix = Matrix.zero(4).map { |x| BigDecimal('0.0') }
    data.each do |row|
      v = Vector.elements(row)
      centered_v = v - mean
      4.times do |i|
        4.times do |j|
          term = centered_v[i] * centered_v[j]
          cov_matrix_array = cov_matrix.to_a
          cov_matrix_array[i][j] += term
          cov_matrix = Matrix.rows(cov_matrix_array)
        end
      end
    end
    cov_matrix = cov_matrix.map { |x| x / m_big }

    components.each_with_index do |vec, i|
      vec_bd = Vector.elements(vec)

      # A*v を計算
      av = cov_matrix * vec_bd

      # λ*v を計算
      lambda_v = vec_bd.map { |x| x * lambdas[i] }

      # 残差 A*v - λ*v を計算
      residual = av - lambda_v
      residual_norm = HighPrecisionMath.sqrt(HighPrecisionMath.dot_product(residual, residual))

      puts "  v#{i+1} (λ#{i+1} = #{format('%.6e', lambdas[i].to_f)}):"
      puts "    ||A*v - λ*v|| = #{format('%.6e', residual_norm.to_f)}"
      puts "    → #{residual_norm.to_f < 1e-6 ? '✅ 固有値方程式成立' : '⚠️ 検証失敗'}"
    end

    # --- 2次元性/3次元性の評価 ---
    puts "\n💡 データの次元性評価:"
    puts "=" * 140

    total_variance = lambdas.map { |λ| λ.abs }.sum
    puts "総分散 (Σλ_i): #{format('%.6e', total_variance.to_f)}"

    min_2_variance = (lambdas[0].abs + lambdas[1].abs)
    min_2_ratio = (min_2_variance / total_variance * 100).round(4)

    max_2_variance = (lambdas[2].abs + lambdas[3].abs)
    max_2_ratio = (max_2_variance / total_variance * 100).round(4)

    puts "\n最小2つの固有値 (λ1 + λ2) の寄与率: #{min_2_ratio}%"
    puts "最大2つの固有値 (λ3 + λ4) の寄与率: #{max_2_ratio}%"

    if min_2_ratio < 0.1
      puts "→ ✅ ほぼ完全に2次元構造（最小方向の分散が0.1%未満）"
    elsif min_2_ratio < 1.0
      puts "→ ✅ 強い2次元構造（最小方向の分散が1%未満）"
    elsif min_2_ratio < 5.0
      puts "→ ⚠️ 2次元成分が主流（最小方向の分散が5%未満）"
    else
      puts "→ ❌ 3次元以上の重要な成分あり"
    end

    puts "\n連分数展開による固有値の代数的性質:"
    puts "=" * 140
    max_terms = 30
    lambdas.each_with_index do |lambda_val, i|
      cf = HighPrecisionMath.continued_fraction(lambda_val, max_terms: max_terms)
      puts "  λ#{i+1} の連分数展開: #{cf.inspect}"

      if cf.size > 1 && !cf.include?(:inf)
        restored = HighPrecisionMath.continued_fraction_to_decimal(cf)
        error = (lambda_val - restored).abs
        puts "    復元値: #{format('%.10e', restored.to_f)}"
        puts "    誤差:  #{format('%.10e', error.to_f)}"
      end
    end

    # --- 追加: 固有ベクトルの各成分について連分数展開と復元誤差を表示 ---
    puts "\n🔍 固有ベクトルの連分数展開と復元誤差（各成分）"
    puts "=" * 140
    components.each_with_index do |vec, vi|
      puts "  固有ベクトル v#{vi+1}:"
      vec.each_with_index do |comp, ci|
        # comp は BigDecimal である想定
        begin
          cf_comp = HighPrecisionMath.continued_fraction(BigDecimal(comp.to_s), max_terms: max_terms)
        rescue => e
          cf_comp = [:error]
        end

        if cf_comp == [:error] || cf_comp.empty? || cf_comp.include?(:inf)
          puts "    成分[#{ci}]: 連分数展開不可または発散: #{cf_comp.inspect}"
          next
        end

        # 復元と誤差計算
        restored_comp = HighPrecisionMath.continued_fraction_to_decimal(cf_comp)
        comp_bd = BigDecimal(comp.to_s)
        err_comp = (comp_bd - restored_comp).abs

        # 表示: 連分数, 復元値(指数表記), 誤差(指数表記)
        puts "    成分[#{ci}]: 連分数=#{cf_comp.inspect}, 復元=#{format('%.10e', restored_comp.to_f)}, 誤差=#{format('%.6e', err_comp.to_f)}"
      end
    end

    puts "=" * 140

  rescue => e
    puts "❌ エラー: #{e.message}"
    e.backtrace.each { |line| puts "  #{line}" }
  end
end
