def walk(f):
  . as $in |
  if type == "object" then
    reduce keys_unsorted[] as $key ( {}; . + {($key): ( $in[$key] | walk(f) )} ) | f
  elif type == "array" then map(walk(f)) | f
  else f
end;

#reduce inputs as $i ({}; . + { ($i): (input | fromjson? // split(",") - [""] | [.[] | tonumber? // .]) })
