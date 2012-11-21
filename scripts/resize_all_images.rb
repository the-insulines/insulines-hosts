require "progressbar"
require "fileutils"
require "rmagick"

WORLD_RESOLUTION_X = 960
WORLD_RESOLUTION_Y = 480

def directory_structure(dir, files)
  if File.directory?(dir)
    Dir.foreach(dir) do |file|
      if !['.', '..', '.DS_Store', '.gitignore', '.git' ].include?(file)
        if File.directory?(dir + file)
          files << (dir + file)
          directory_structure(dir + file + '/', files)
        end
      end
    end
  end
  files
end

def all_files_on(dir, files)
  if File.directory?(dir)
    Dir.foreach(dir) do |file|
      if !['.', '..', '.DS_Store', '.gitignore', '.git' ].include?(file)
        if File.directory?(dir + file)
          all_files_on(dir + file + '/', files)
        else
          files << "#{dir}#{file}"
        end
      end
    end
  end
  files
end

# # --------------------------------------------------------------------------------------------------------
# # Resize files
# # --------------------------------------------------------------------------------------------------------
# resize_ratio_x = screen_resolution_x / WORLD_RESOLUTION_X.to_f
# resize_ratio_y = screen_resolution_y / WORLD_RESOLUTION_Y.to_f
# 
# pbar = ProgressBar.new("Resizing imgs", used.size)
# used.each do |f|
#   if f.match('png')
#     # Resize image
#     image = Magick::Image.read(assets_dir + f).first
#     image.resize!(0.5)
#     image.write(assets_dir + f)
#   end
#   pbar.inc
# end
# puts ''
