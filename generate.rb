require 'rubygems'
require 'bundler/setup'
require 'rqrcode_png'
require 'csv'
require 'RMagick'

include Magick

GENERATED_CODES_DIR = 'generated_codes'
GENERATED_CODES_HISTORY_FILE = 'history/generated_codes.csv'

# This file allows users to generate QR codes to affix onto their notes.
# The QR codes encode a string with the following format:
# "#{ Class }-#{ type }-#{ page_number }".
# The code will then be used to identify the page when it is scanned.
#
# In order to keep track of page numbering, past generated codes are
# located in history/generated_codes.csv.
# NOTE: When this file gets large, it will probably take a long time to
# parse. A better option would be to store the number of pages generated for
# each class and type in a database. This should be implemented at some point.


def generate_qr_code(class_name, type, page_number, options = {})
  # RQRCODE::QRCode#new will throw a QRCodeRunTimeError when the size of the code
  # specified is not sufficient to store the desired string. Unfortunately, the
  # default value of size is fixed at 4 instead of specifying the smallest
  # adequate size. The following is a hack to make our codes as small as possible if
  # no size option is passed:
  size = 1
  qr = nil
  padded_page_number = "%03d" % page_number.to_i
  string = "#{ class_name }-#{ type }-#{ padded_page_number }"
  puts string
  loop do
    begin
      qr = RQRCode::QRCode.new(string, {:size => size}.merge(options))
      break
    rescue RQRCode::QRCodeRunTimeError => e
      size += 1
    end
  end

  png = qr.to_img
  Dir.mkdir(GENERATED_CODES_DIR) unless File.directory?(GENERATED_CODES_DIR)
  processed_location = "generated_codes/#{ string }.png" # clean this part up later
  png.save("generated_codes/#{ string }.png") # TODO: Add string to png

  add_string_to_image(processed_location, string)

  CSV.open(GENERATED_CODES_HISTORY_FILE, 'ab') do |csv| # TODO: create this file if not present
    csv << [class_name, type, padded_page_number, Time.now.strftime('%F')]
  end
end

# this method name is a tad too verbose. Shorten it if you can think of a better name (:
def read_highest_page_number_for_each_class_from_generated_codes
  return unless File.exists? GENERATED_CODES_HISTORY_FILE
  max_number_for_class_type = Hash.new(0) # [class, type] => <MAX page number found for that class>

  CSV.foreach GENERATED_CODES_HISTORY_FILE, :headers => true do |l|
    # TODO: add checking for invalid rows
    key = [ l['class'], l['type'] ]
    n = l['page_number'].to_i(10)
    max_number_for_class_type[key] = n if max_number_for_class_type[key] < n
  end

  max_number_for_class_type
end

def generate_code_batch(class_name, type, n)
  start_number = read_highest_page_number_for_each_class_from_generated_codes[ [class_name, type] ].to_i
  # we want to start at the next page, unless there have been zero pages generated for that class
  start_number += 1 unless start_number == 0
  # For some reason, zbar has problems reading codes of size 3, so the size is hardcoded here
  n.times { |i| generate_qr_code class_name, type, start_number + i, :size => 4, :level => :h }
end

WIDTH_INCREASE = 270 # (Move to top)

def add_string_to_image(image_location, string)
  img = Magick::Image.read(image_location).first
  img = img.scale 4
  code_width = img.rows
  code_height = img.columns
  img = img.extent(code_width + WIDTH_INCREASE, code_height, 0, 0)
  text = Draw.new
  img.annotate(text, WIDTH_INCREASE, code_height, code_width, 0, string){
    text.pointsize = 32
    text.gravity = Magick::WestGravity
  }
  img.format = 'png'
  img.write image_location
end

# TODO: Present options for classes and types so they do not have to be typed in
# each time.
#

print "Please enter the class: "
class_name = gets.chomp

print "Please enter the type (L/T/Lb/M): "
type = gets.chomp

print "Please enter the number of pages you wish to generate: "
n = gets.chomp.to_i(10)

generate_code_batch(class_name, type, n)
