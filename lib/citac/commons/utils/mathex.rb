class Integer
  def factorial
    (1..self).reduce(1, :*)
  end

  def to_s_thousand_sep(sep = ' ')
    to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{sep}")
  end
end