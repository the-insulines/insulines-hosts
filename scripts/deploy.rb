require "progressbar"
require "fileutils"
require "rmagick"

RESOURCE_TYPE_IMAGE = 0
RESOURCE_TYPE_TILED_IMAGE = 1
RESOURCE_TYPE_ANIMATION_FRAMES = 2
RESOURCE_TYPE_FONT = 3
RESOURCE_TYPE_SOUND = 4

WORLD_RESOLUTION_X = 1920
WORLD_RESOLUTION_Y = 1280

class Deploy
  attr_accessor :src_dir, :gfx_dir, :assets, :assets_dir, :code_dir, :screen_resolution_x, :screen_resolution_y
  def initialize ( src_dir, gfx_dir, screen_resolution_x, screen_resolution_y )
    self.src_dir = src_dir
    self.gfx_dir = gfx_dir
    self.screen_resolution_x = screen_resolution_x
    self.screen_resolution_y = screen_resolution_y
    self.assets_dir = 'assets/'
    self.code_dir = 'src/'
  end
  
  def is_a_sound(line)
    [ 'sleeps', 'wakes_up' ].each do |sound|
      return true if line.match(":#{sound} =>  {")
    end
    return false
  end
  
  def replace_constants(line)
    ['INVENTORY_ITEM_WIDTH', 'INVENTORY_ITEM_HEIGHT', 'DIALOG_BACKGROUND_WIDTH','DIALOG_BACKGROUND_HEIGHT',
     'DIALOG_WINDOW_WIDTH', 'DIALOG_WINDOW_HEIGHT', 'MAIN_CHARACTER_PIVOT', 'MOVEMENT_SECONDS_PER_FRAME',
     'DEFAULT_ANIMATION_SPEED', 'JOSH_GRABS_CELLPHONE_SECONDS_PER_FRAME', 'MOAITimer.NORMAL'].each do |constant|
      line.gsub!(constant, '0')
    end
    return line
  end
  
  def find_assets
    # Open defines.lua to parse all assets
    traversing_resources = false
    in_array = false
    in_sounds = false
    resources = "{\n"
    file = File.open( src_dir + "defines.lua", "r")
    
    
    file.readlines.each do |line|
      
      # If we're on the resources table, add that line to the resource string
      if traversing_resources
        # If we're not on a commented line, add it
        if !line.match (/^\s\s\-\-/)
          # Migrate hash keys from lua to ruby
          line.gsub!(/(?<key>\w*)\s=/, ':\k<key> => ')
          
          # Make arrays use [] instead of {} on multipliers
          if line.match(':tileMapSize =>')
            line.gsub!('{', '[')
            line.gsub!('}', ']')
          end

          # Make arrays use [] instead of {} on multipliers
          if line.match(':multipliers =>  {') || (in_sounds && is_a_sound(line))
            in_array = true
            line.gsub!('{', '[')
          end

          # Close arrays
          if line.match(/^\s*\},/) and in_array
            in_array = false
            line.gsub!('}', ']')
          end

          if line.match(':sounds =>  {') || (in_sounds && is_a_sound(line))
            in_sounds = true
          end

          if line.match(/^\s*\},/) and in_sounds
            in_sounds = false
          end
          
          resources += replace_constants(line)
        end
      end

      # Start adding resources
      if line.match("resources = {")
        traversing_resources = true
      end
      
      
      # Finish adding resources
      if line.match(/^\}/) and traversing_resources
        traversing_resources = false
      end

      
    end
    self.assets = eval(resources)
    file.close
  end
  
  def add_image(key, asset, used)
    if File.exists?(self.gfx_dir + asset[:fileName])
      used << asset[:fileName]
    else
      missing(asset[:fileName])
    end
  end
  
  def add_animation_frames(key, asset, used)
    asset[:animations].each do |key, animation|
      if key != :sounds
        # Directory is the key or the parent's key
        directory = animation[:parentAnimationName].nil? ? asset[:location] + key.to_s : asset[:location] + animation[:parentAnimationName]
        full_path = self.gfx_dir + directory + "/"
        if File.directory?(full_path)
          Dir.foreach(full_path) do |f|
            if f != '.' and f != '..' and f != 'sounds' and f != '.DS_Store' and !used.include?(full_path + f)
              if File.exist?(full_path + f)
                used << directory + '/' + f
              else
                missing(directory + '/' + f)
              end
            end
          end
        end
      end
    end
  end
  
  def add_animation_sounds(key, asset, used)
    if asset[:sounds]
      asset[:sounds].each do |key, sound|
        uri = asset[:location] + key.to_s + '/sounds/' + sound.first[:fileName] + '.mp3'
        if File.exist?(gfx_dir + uri)
          used << uri
        else
          missing(uri)
        end
      end
    end
  end
  
  def add_sound(key, asset, used)
    if File.exists?(self.gfx_dir + 'sounds/' + asset[:fileName])
      used << 'sounds/' + asset[:fileName]
    else
      missing('sounds/' + asset[:fileName])
    end
  end

  def add_font(key, asset, used)
    if File.exists?(self.gfx_dir + 'fonts/' + asset[:fileName])
      used << 'fonts/' + asset[:fileName]
    else
      missing('fonts/' + asset[:fileName])
    end
  end
  
  def used_assets
    find_assets if !self.assets
    used = []
    self.assets.each do |key,asset|
      if asset[:type] == RESOURCE_TYPE_IMAGE || asset[:type] == RESOURCE_TYPE_TILED_IMAGE
        add_image(key, asset, used)
      elsif asset[:type] == RESOURCE_TYPE_ANIMATION_FRAMES
        add_animation_frames(key, asset, used)
        add_animation_sounds(key, asset, used)
      elsif asset[:type] == RESOURCE_TYPE_FONT
        add_font(key, asset, used)
      elsif asset[:type] == RESOURCE_TYPE_SOUND
        add_sound(key,asset,used)
      end
    end
    return used.uniq
  end

  def missing(file)
    puts "Missing file #{file}"
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
  
  def update_assets
    # --------------------------------------------------------------------------------------------------------
    # Remove current files
    # --------------------------------------------------------------------------------------------------------
    puts "Removing current assets"
    FileUtils.rm_rf(assets_dir)
    
    # --------------------------------------------------------------------------------------------------------
    # Create directory structure
    # --------------------------------------------------------------------------------------------------------
    structure = directory_structure(self.gfx_dir, [])
    pbar = ProgressBar.new("Assets structure", structure.size + 1)

    FileUtils.mkdir(assets_dir)
    pbar.inc

    structure.each do |dir|
      dir.gsub!(self.gfx_dir, assets_dir)
      FileUtils.mkdir(dir)
      pbar.inc
    end
    puts ''
    
    # --------------------------------------------------------------------------------------------------------
    # Copy files
    # --------------------------------------------------------------------------------------------------------
    used = used_assets
    pbar = ProgressBar.new("Copying files", used.size)
    used.each do |f|
      FileUtils.cp(gfx_dir + f, assets_dir + f)
      pbar.inc
    end
    puts ''
    
    # --------------------------------------------------------------------------------------------------------
    # Resize files
    # --------------------------------------------------------------------------------------------------------
    resize_ratio_x = screen_resolution_x / WORLD_RESOLUTION_X.to_f
    resize_ratio_y = screen_resolution_y / WORLD_RESOLUTION_Y.to_f
    
    pbar = ProgressBar.new("Resizing imgs", used.size)
    used.each do |f|
      if f.match('png')
        # Resize image
        image = Magick::Image.read(assets_dir + f).first
        image.resize!(0.5)
        image.write(assets_dir + f)
      end
      pbar.inc
    end
    puts ''
    
    # --------------------------------------------------------------------------------------------------------
    # Optimize images
    # --------------------------------------------------------------------------------------------------------
    pbar = ProgressBar.new("Optimize imgs", used.size)
    used.each do |f|
      if f.match('png')
        system("./pngquant --ext .png -f " + assets_dir + f)
      end
      pbar.inc
    end
    puts ''
  end

  def update_code
    # --------------------------------------------------------------------------------------------------------
    # Remove current files
    # --------------------------------------------------------------------------------------------------------
    puts "Removing current source"
    FileUtils.rm_rf(code_dir)
    
    # --------------------------------------------------------------------------------------------------------
    # Create directory structure
    # --------------------------------------------------------------------------------------------------------
    structure = directory_structure(self.src_dir, [])
    pbar = ProgressBar.new("Code structure", structure.size + 1)

    FileUtils.mkdir(code_dir)
    pbar.inc

    structure.each do |dir|
      dir.gsub!(self.src_dir, code_dir)
      FileUtils.mkdir(dir)
      pbar.inc
    end
    puts ''
    
    # --------------------------------------------------------------------------------------------------------
    # Copy files
    # --------------------------------------------------------------------------------------------------------
    files = all_files_on(src_dir, [])
    pbar = ProgressBar.new("Copying files", files.size)
    files.each do |f|
      FileUtils.cp(f, f.gsub(self.src_dir, code_dir))
      pbar.inc
    end
    puts ''
    
  end
  
  def deploy
    puts "----------------------------------------------"
    puts "The Insulines Deployment script"
    puts "----------------------------------------------"
    puts ""
    update_assets
    puts ""
    update_code
    puts ""
  end
end

@d = Deploy.new( '../../insulines-src/src/', '../../insulines-gfx/', 960, 640 )

@d.deploy