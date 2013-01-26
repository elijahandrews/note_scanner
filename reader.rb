require 'rubygems'
require 'bundler/setup'
require 'zbar'
require 'RMagick'
require 'fileutils'

DROPOFF_DIR = 'dropoff'
PROCESSED_DIR = 'processed'
ERRORED_DIR = 'errored'

# This script checks in the dropoff folder to any new page pngs.
# For every image it finds in this folder, it will attempt to
# read scan the QR code. If it reads the code correctly, it will
# store it in the appropriate folder. If an error occurs while reading
# code, the image will be moved to the errored folder.

def process_image(location)
  puts "Processing #{ location }..."
  begin
    # NOTE: the zbar gem currently only accepts jpg and
    # pgm files as input. We use RMagick to convert pngs
    # to the appropriate format. A fast solution should
    # be investigated.
    # From https://github.com/willglynn/ruby-zbar/issues/2
    # (thanks sberryman!)

    # load the image via rmagick
    input = Magick::Image.read(location).first
    # convert to PGM
    input.format = 'PGM'
    # load the image from a string
    image = ZBar::Image.from_pgm(input.to_blob)
    results = image.process
    raise 'No QR code found' if results.empty?

    # We assume only one code is on the sheet. May want to change this in the future.
    qr_code = results.first.data
    puts "Parsed QR code: #{ qr_code }"
    raise 'Invalid QR code' unless qr_code =~ /^\w+-\w+-\d+$/

    split_qr_code = qr_code.split('-')
    class_name = split_qr_code.first
    type = split_qr_code[1]
    page_number = split_qr_code.last

    destination_filename = page_number << ".png"
    destination_dir = "#{ PROCESSED_DIR }/#{ class_name }-#{ type }"
    move_file location, destination_dir, destination_filename
  rescue Exception => e
    puts "****Error processing #{ location }: #{e}"
    move_file(location, ERRORED_DIR)
  ensure
    puts # For nice terminal formatting
  end

  # useful line to show the zbar result API
    # puts "Code: #{result.data} - Type: #{result.symbology} - Quality: #{result.quality}"
end

def move_file(original_location, destination_dir, destination_filename = nil)
  FileUtils.mkdir_p(destination_dir) unless File.directory?(destination_dir)
  if destination_filename.nil?
    destination = "#{ destination_dir }/#{ File.basename(original_location) }"
  else
    destination = "#{ destination_dir }/#{ destination_filename }"
  end
  while File.exists?(destination) do
    destination = destination.split('.').insert(-2, "dupl").join('.')
  end
  puts "Moving #{ original_location } to #{ destination }"
  FileUtils.mv original_location, destination
end

Dir.glob("#{ DROPOFF_DIR }/*.png") { |png| process_image png }
