
class BaseController < ActionController::Base

  def l(hash=nil) 
    $session = session
    return get_link(hash)
  end

  def get_link(hash=nil)
    hash1 = get_query_params()
    hash1['t'] = $current_page
    hash1.delete('p')
    hash = {} if !hash
    hash = hash1.merge(hash)
    if !hash['sessionID']
      hash['sessionID'] = $session['session_id']
    end
    link = "?"
    if hash.include?("p")
      link = "#{hash['p']}?"
      hash.delete('p')
    end
    count = 0
    hash.each do |k,v|
      if k.to_s.strip != "" && v.to_s.strip != ""
        link += "&amp;" if (count+=1) > 1
        link += "#{k}=#{v}"
      end
    end
    return link
  end

  $user_params = {}
  def param(name, default="")
    return $user_params[name] if $user_params[name]
    return $cgi[name] if $cgi && $cgi[name] && $cgi[name].strip != ""
    p = get_query_params()[name]
    return p if p && p != ""
    return default
  end

  def get_query_params(hash=nil)
    hash = {} if !hash
    query_values = params
    query_values.each do |k,v|
      v = v.kind_of?(Array) ? v[0] : v.to_s
      if !hash.include?(k)
        hash[k] = v
      end
      if $user_params.include?(k)
        hash[k] = $user_params[k]
        if $user_params[k].nil?
          hash.delete(k)
        end
      end
    end
    return hash
  end

  def set_param(name, value)
    $user_params[name] = value
    if value.nil?
      $user_params.delete(name)
    end
  end

  def format_minutes(seconds)
    return to_minutes(seconds)
  end
  def to_minutes(seconds)
    return "n/a" if seconds.nil? || seconds.to_f.nan? || (seconds < 0)
    m = (seconds.to_f/60.0).floor
    s = (seconds - (m * 60.0)).round
    return "%02d:%02d" % [ m, s ]
  end
  def format_date(secs)
    return format_time(secs)
  end
  def format_time(secs)
    if !secs || "#{secs}".empty?
      return "n/a"
    end
    secs = secs.to_s.to_i
    Time.at(secs).strftime("%Y-%m-%d %H:%M:%S")
  end
  def format_float(f, digits_after_comma=2)
    return "%.#{digits_after_comma}f" % f
  end

  helper_method :l, :lk, :set_param, :param, :current_user, 
    :format_time, :to_minutes, :format_float
end
