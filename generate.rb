require "rubygems"
require "bundler/setup"
require 'rqrcode_png'

GENERATED_CODES_DIR = 'generated_codes'

# RQRCODE::QRCode#new will throw a QRCodeRunTimeError when the size of the code
# specified is not sufficient to store the desired string. Unfortunately, the
# default value of size is fixed at 4 instead of specifying the smallest
# adequate size. The following is a hack to make our codes as small as possible:

size = 1
qr = nil
string = 'ECE250-L-001' # in the form "#{class}-#{type}-#{page_number}"

loop do
  begin
    qr = RQRCode::QRCode.new( string, :size => size, :level => :h )
    break
  rescue RQRCode::QRCodeRunTimeError => e
    size += 1
  end
end

png = qr.to_img
Dir.mkdir(GENERATED_CODES_DIR) unless File.directory?(GENERATED_CODES_DIR)
png.save("generated_codes/#{string}.png")
