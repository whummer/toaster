

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

# takes two state property hashes (pre-state and post-state)
# and returns an array of state property changes
def diff__packages(p1, p2)
  result = []
  pkg_names = Set.new
  p1 = eliminate_json_map_entries(p1)
  p2 = eliminate_json_map_entries(p2)

  p1.each do |k,v| pkg_names.add(k) end
  p2.each do |k,v| pkg_names.add(k) end
  pkg_names.each do |pn|

    d = create_diff_for_package(p1, p2, pn)
    result << d if d

  end

  return result
end

# takes two state property hashes (pre-state and post-state)
# and returns a pair of states which are either equal to or 
# a subset of the given states.
def reduce__packages(p1, p2)
  any_changes = false
  max_items = 100
  if p1.size > max_items
    p1.keys.dup.each do |k|
      if p1.size <= max_items
        break
      end
      if p1[k] == p2[k]
        p1.delete(k)
        p2.delete(k)
        any_changes = true
      end
    end
  end
  if any_changes
    p1["__INFO__"] = "Some items left out."
    p2["__INFO__"] = "Some items left out."
  end
end

def create_diff_for_package(p1, p2, pkg)
  pkg1 = p1[pkg]
  pkg2 = p2[pkg]
  return nil if pkg1 && pkg2 && pkg1 == pkg2
  name = "packages['#{pkg}']"
  if pkg1 && !pkg2
    return StatePropertyChange.new(name, StatePropertyChange::ACTION_DELETE, pkg1)
  elsif !pkg1 && pkg2
    return StatePropertyChange.new(name, StatePropertyChange::ACTION_INSERT, pkg2)
  elsif pkg1 && pkg2 && pkg1 != pkg2
    return StatePropertyChange.new(name, StatePropertyChange::ACTION_MODIFY, pkg2, pkg1)
  end
end

def eliminate_json_map_entries(p)
  return if !p
  p = p.dup
  sub = p[MarkupUtil::JSON_MAP_ENTRY_NAME]
  p.delete(MarkupUtil::JSON_MAP_ENTRY_NAME)
  if sub
    sub.each do |pair|
      key = pair[MarkupUtil::JSON_MAP_ENTRY_KEY]
      val = pair[MarkupUtil::JSON_MAP_ENTRY_VALUE]
      p[key] = val if key && val
    end
  end
  return p
end


# return a list of properties which should not be 
# considered for test case generation or computation
# of the state transition graphs
def ignore_properties__packages()
  return []
end
