class String
  # taken from http://stackoverflow.com/a/11482430/128709
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize("31;1")
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def pink
    colorize("35;1")
  end

  # inspired by http://stackoverflow.com/a/16363159/128709
  def no_colors
    self.gsub /\033\[\d*(;\d+)?m/, ''
  end
end