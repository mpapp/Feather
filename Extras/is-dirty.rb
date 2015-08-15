#!/usr/bin/env ruby

if ARGF.read.downcase =~ /dirty/ then
  puts "THERE'S DIRT IN UR BUILD!"
  exit(-1)
end
