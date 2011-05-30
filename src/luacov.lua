
local M = {}

local stats = require("luacov.stats")
local data = stats.load()
local statsfile = stats.start()
M.statsfile = statsfile

local tick = package.loaded["luacov.tick"]
local ctr = 0
local luacovlock = os.tmpname()

local function on_line(_, line_nr)
   if tick then
      ctr = ctr + 1
      if ctr == 100 then
         ctr = 0
         stats.save(data, statsfile)
      end
   end

   local name = debug.getinfo(2, "S").source
   if name:match("^@") then
      name = name:sub(2)
      local file = data[name]
      if not file then
         file = {}
         file.max = 0
         data[name] = file
      end
      if line_nr > file.max then
         file.max = line_nr
      end
      local current = file[line_nr]
      if not current then
         file[line_nr] = 1
      else
         file[line_nr] = current + 1
      end
   end
end

local function on_exit()
   os.remove(luacovlock)
   stats.save(data, statsfile)
   stats.stop(statsfile)
end

local function init()
   if not tick then
      M.on_exit_trick = io.open(luacovlock, "w")
      debug.setmetatable(M.on_exit_trick, { __gc = on_exit } )
   end

   debug.sethook(on_line, "l")

   local rawcoroutinecreate = coroutine.create
   coroutine.create = function(...)
      local co = rawcoroutinecreate(...)
      debug.sethook(co, on_line, "l")
      return co
   end
   coroutine.wrap = function(...)
      local co = rawcoroutinecreate(...)
      debug.sethook(co, on_line, "l")
      return function()
         local r = { coroutine.resume(co) }
         if not r[1] then
            error(r[2])
         end
         return unpack(r, 2)
      end
   end

   local rawexit = os.exit
   os.exit = function(...)
      on_exit()
      rawexit(...)
   end
end

init()

return M
