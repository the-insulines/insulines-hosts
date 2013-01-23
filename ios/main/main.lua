--==============================================================
-- The Insulines
-- Copyright (c) 2010-2012 quov.is
-- All Rights Reserved. 
-- http://quov.is // http://theinsulines.com
--==============================================================
DEFAULT_ASSETS_PATH = './assets/'
SOUND_ENGINE = 'untz'
-- SCREEN_RESOLUTION_Y = SCREEN_RESOLUTION_X * ( 320 / 480)

-- if SCREEN_RESOLUTION_X == 1024 * 2 then
--   SCREEN_RESOLUTION_Y = 768 * 2
-- end

SCREEN_TO_WORLD_RATIO = 1
require 'src/requires'

MOAISim.openWindow ( 'The Insulines', SCREEN_RESOLUTION_X, SCREEN_RESOLUTION_Y )


function main ()
  game:start ()
end


gameThread = MOAIThread.new ()
gameThread:run ( main )
