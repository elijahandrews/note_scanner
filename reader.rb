require "rubygems"
require "bundler/setup"
require 'zbar'
require 'RMagick'

# NOTE: the zbar gem currently only accepts jpg and
# pgm files as input. We use RMagick to convert pngs
# to the appropriate format. A fast solution should
# be investigated.
# From https://github.com/willglynn/ruby-zbar/issues/2 
# (thanks sberryman!)

# load the image via rmagick
input = Magick::Image.read('sample.png').first

# convert to PGM
input.format = 'PGM'

# load the image from a string
image = ZBar::Image.from_pgm(input.to_blob)

image.process.each do |result|
  puts "Code: #{result.data} - Type: #{result.symbology} - Quality: #{result.quality}"
end
