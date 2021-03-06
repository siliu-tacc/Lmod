#!@path_to_lua@/lua
-- -*- lua -*-

--------------------------------------------------------------------------
-- This is ml script front end to modules.  You can pretty much do
-- everything with the ml script that you can do with the module command.
-- With the "--old_style" option it can be used with the TCL/C module
-- system.
-- @script ml

--------------------------------------------------------------------------
-- Lmod License
--------------------------------------------------------------------------
--
--  Lmod is licensed under the terms of the MIT license reproduced below.
--  This means that Lmod is free software and can be used for both academic
--  and commercial purposes at absolutely no cost.
--
--  ----------------------------------------------------------------------
--
--  Copyright (C) 2008-2014 Robert McLay
--
--  Permission is hereby granted, free of charge, to any person obtaining
--  a copy of this software and associated documentation files (the
--  "Software"), to deal in the Software without restriction, including
--  without limitation the rights to use, copy, modify, merge, publish,
--  distribute, sublicense, and/or sell copies of the Software, and to
--  permit persons to whom the Software is furnished to do so, subject
--  to the following conditions:
--
--  The above copyright notice and this permission notice shall be
--  included in all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.
--
--------------------------------------------------------------------------

------------------------------------------------------------------------
-- Use command name to add the command directory to the package.path
local LuaCommandName = arg[0]
local i,j = LuaCommandName:find(".*/")
local LuaCommandName_dir = "./"
if (i) then
   LuaCommandName_dir = LuaCommandName:sub(1,j)
end
package.path = LuaCommandName_dir .. "../tools/?.lua;" ..
               LuaCommandName_dir .. "?.lua;"       .. package.path


pcall(require("strict"))

local concatTbl = table.concat

--------------------------------------------------------------------------
-- Wrap an entity in single quotes.
-- @param a a entity to wrap in quotes.
local function quoteWrap(a)
   return "'" .. tostring(a) .. "'"
end

--------------------------------------------------------------------------
-- Simple usage message.
function usage()
   io.stderr:write("\n",
                   "ml: A handy front end for the module command:\n\n",
                   "Simple usage:\n",
                   " -------------\n",
                   "  $ ml\n",
                   "                           means: module list\n",
                   "  $ ml foo bar\n",
                   "                           means: module load foo bar\n",
                   "  $ ml -foo -bar baz goo\n",
                   "                           means: module unload foo bar;\n",
                   "                                  module load baz goo;\n\n",
                   "Command usage:\n",
                   "--------------\n\n",
                   "Any module command can be given after ml:\n\n",
                   "if name is avail, save, restore, show, swap,...\n",
                   "    $ ml name  arg1 arg2 ...\n\n",
                   "Then this is the same :\n",
                   "    $ module name arg1 arg2 ...\n\n",
                   "In other words you can not load a module named: show swap etc\n")

   io.stderr:write("\n\n-----------------------------------------------\n",
                   "  Robert McLay, TACC\n",
                   "     mclay@tacc.utexas.edu\n")
end



--------------------------------------------------------------------------
-- The main program.  Process options and generate module command.
function main()

   local argA     = {}
   local optA     = {}
   local cmdA     = {}

   ------------------------------------------------------------
   -- lmodOptT: Hash table of command line arguments.  The key
   --           is the name of the argument and the value is the
   --           number of arguments the option requires

   local lmodOptT = {
      ["--old_style"] = 0,
      ["-D"]=0,
      ["-?"] = 0, ["-h"] = 0, ["--help"] = 0, ["-H"] = 0,
      ["--default"]=0,  ["-d"]=0,
      ["--dumpversion"] = 0,
      ["--expert"]=0,   ["--novice"]=0,
      ["--force"] = 0,
      ["--gitversion"] = 0,
      ["--ignore_cache"] = 0,  ["--ignore-cache"] = 0,
      ["--initial_load"] = 0,  ["--initial-load"] = 0,
      ["--latest"] = 0,
      ["--localvar"]=1,
      ["--pin_versions"]=0, ["--pin-versions"]=0,
      ["--mt"] = 0,
      ["--quiet"] = 0,  ["-q"] = 0,
      ["--redirect"] = 0, ["--no_redirect"] = 0, ["--no-redirect"] = 0,
      ["--spider_timeout"] = 1,       ["--spider-timeout"] = 1,
      ["--terse"] = 0,  ["-t"] = 0,
      ["--timer"] = 0,
      ["--version"]=0,  ["--versoin"]=0, ["--ver"]=0, ["--v"]=0, ["-v"]=0,
      ['--config'] = 0,
      ['--raw'] = 0,
      ['--regexp'] = 0, ['-r'] = 0,
      ['--show_hidden'] = 0, ['--show-hidden'] = 0,
      ['--style'] = 1,  ['-s'] = 1,
      ['--width'] = 1,  ['-w'] = 1,
   }

   local translateT = {
      ["--versoin"]="--version",
      ["--ver"]="--version",
      ["--v"]="--version",
      ["-v"]="--version",
   }

   ------------------------------------------------------------
   -- lmodCmdT: Hash table of module commands.  The value just
   --           has to be non-nil

   local lmodCmdT = {
      avail="avail",  av="avail",
      describe="describe", mcc="describe",
      getdefault="getdefault", gd="getdefault",
      help="help",
      key="keyword", keyword="keyword",
      list="list",
      listdefault="listdefault", ld="listdefault",
      load="load", add="load",
      purge="purge",
      r="restore", restore="restore",
      refresh="refresh",
      reset="reset",
      s="save",
      save="save",
      savelist="savelist", sl="savelist",
      setdefault="save", sd="save",
      search="search",
      show="show",
      spider="spider",
      swap="swap", sw="swap",
      tablelist="tablelist",
      ['try-load'] = "try-load",
      unload="unload", rm = "unload", del = "unload", delete="unload",      unuse="unuse",
      update="update",
      use="use",
      whatis="whatis",
   }
   local grab     = 0
   local verbose  = false
   local oldStyle = false
   local show     = false
   local cmdFound = false

   --------------------------------------------------------------------------
   -- Loop over command line options and process each one.  Note that this
   -- loop uses the for -- repeat ... until true end trick for simulating
   -- the continue stmt (which doesn't exist in Lua).

   for _,v in ipairs(arg) do
      repeat
         if (grab > 0) then
            optA[#optA+1] = v
            grab          = grab - 1
            break
         end

         if (v == "--Verbose") then
            verbose = true
            break
         end

         if (v == "--old_style") then
            oldStyle = true
            break
         end

         if (v == "--show") then
            show   = true
            break
         end

         if (v == "--help" or v == "-?" or v== "-h") then
            usage()
            return
         end

         local num = lmodOptT[v]
         if (num) then
            grab          = num
            optA[#optA+1] = translateT[v] or v
            break
         end

         local cmd = lmodCmdT[v]
         if (cmd and not cmdFound) then
            cmdA[#cmdA + 1] = cmd
            cmdFound        = true
            break
         end

         argA[#argA+1] = v
      until true
   end

   if (#cmdA > 1) then
      io.stderr:write("ml error: too many commands\n")
      os.exit(1)
   end

   local opts = concatTbl(optA," ")

   local a = {}

   local kind = nil

   a[#a + 1] = "module"
   a[#a + 1] = opts

   if (#cmdA == 1) then
      a[#a + 1] = cmdA[1]
   elseif (#argA < 1) then
      a[#a + 1] = "list"
   else
      if (oldStyle) then
         kind      = "load"
      else
         a[#a + 1] = "load"
      end
   end

   if (kind == 'load') then
      local b = {}
      local u = {}
      for i = 1,#argA do
         if (argA[i]:sub(1,1) == "-") then
            u[#u+1] = quoteWrap(argA[i]:sub(2,-1))
         else
            b[#b+1] = quoteWrap(argA[i])
         end
      end
      if (#u > 0) then
         a[#a+1] = "unload"
         a[#a+1] = concatTbl(u," ")
         if (#b > 0) then
            a[#a+1] = "; module"
            a[#a+1] = opts
         end
      end

      if (#b > 0) then
         a[#a+1] = "load "
         a[#a+1] = concatTbl(b," ")
      end
   else
      for i = 1,#argA do
         a[#a+1] = quoteWrap(argA[i])
      end
   end

   local s = concatTbl(a," ")

   -- print module command to stderr so user can see what
   -- this command will do.
   if (verbose or show) then
      io.stderr:write(s, "\n")
   end

   -- Output module command
   if (not show) then
      io.stdout:write(s, "\n")
   end
end

main()
