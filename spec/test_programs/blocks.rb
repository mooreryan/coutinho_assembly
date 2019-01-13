def lala *a, &b
  p a

  p b

  arst = yield b

  p arst
end


lala 1, 2, 3 do
  puts "block"

  "block return value"
end

