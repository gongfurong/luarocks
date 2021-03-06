local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local write_file = test_env.write_file

test_env.unload_luarocks()

local extra_rocks = {
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/lpeg-0.12-1.src.rock",
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec"
}

describe("luarocks make #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      finally(function()
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("empty")
      end)
      assert(lfs.mkdir("empty"))
      assert(lfs.chdir("empty"))
      assert.is_false(run.luarocks_bool("make"))
   end)

   it("with rockspec", function()
      finally(function()
         -- delete downloaded and unpacked files
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("luasocket-3.0rc1-2")
         os.remove("luasocket-3.0rc1-2.src.rock")
      end)
   
      -- make luasocket
      assert.is_true(run.luarocks_bool("download --source luasocket 3.0rc1-2"))
      assert.is_true(run.luarocks_bool("unpack luasocket-3.0rc1-2.src.rock"))
      lfs.chdir("luasocket-3.0rc1-2/luasocket-3.0-rc1/")
      assert.is_true(run.luarocks_bool("make luasocket-3.0rc1-2.rockspec"))

      -- test it
      assert.is_true(run.luarocks_bool("show luasocket"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/luasocket/3.0rc1-2/luasocket-3.0rc1-2.rockspec"))
   end)

   it("--no-doc", function()
      finally(function()
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("luasocket-3.0rc1-2")
         os.remove("luasocket-3.0rc1-2.src.rock")
      end)

      assert.is_true(run.luarocks_bool("download --source luasocket 3.0rc1-2"))
      assert.is_true(run.luarocks_bool("unpack luasocket-3.0rc1-2.src.rock"))
      lfs.chdir("luasocket-3.0rc1-2/luasocket-3.0-rc1/")
      assert.is_true(run.luarocks_bool("make --no-doc luasocket-3.0rc1-2.rockspec"))

      assert.is_true(run.luarocks_bool("show luasocket"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/luasocket/3.0rc1-2/doc"))
   end)

   it("--only-deps", function()
      local rockspec = testing_paths.fixtures_dir .. "/build_only_deps-0.1-1.rockspec"

      test_env.remove_dir("build_only_deps-0.1-1/")
      assert.is_true(run.luarocks_bool("unpack " .. rockspec))
      lfs.chdir("build_only_deps-0.1-1/")
      assert.is_true(run.luarocks_bool("make " .. rockspec .. " --only-deps"))
      assert.is_false(run.luarocks_bool("show build_only_deps"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/build_only_deps/0.1-1/build_only_deps-0.1-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
   end)

   describe("LuaRocks making rockspecs (using lxsh)", function()
      --download lxsh and unpack it
      before_each(function()
         assert.is_true(run.luarocks_bool("download --source lxsh 0.8.6-2"))
         assert.is_true(run.luarocks_bool("unpack lxsh-0.8.6-2.src.rock"))
         assert.is_true(lfs.chdir("lxsh-0.8.6-2/lxsh-0.8.6-1/"))
      end)
   
      -- delete downloaded and unpacked files
      after_each(function()
         assert(lfs.chdir(testing_paths.testrun_dir))
         test_env.remove_dir("lxsh-0.8.6-2")
         assert.is_true(os.remove("lxsh-0.8.6-2.src.rock"))
      end)         

      it("default rockspec", function()
         assert.is_true(run.luarocks_bool("new_version lxsh-0.8.6-2.rockspec"))
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show lxsh"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/0.8.6-3/lxsh-0.8.6-3.rockspec"))
      end)

      it("unnamed rockspec", function()
         finally(function()
            os.remove("rockspec")
         end)
      
         test_env.copy("lxsh-0.8.6-2.rockspec", "rockspec")
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show lxsh"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      end)
      
      it("ambiguous rockspec", function()
         assert.is.truthy(os.rename("lxsh-0.8.6-2.rockspec", "lxsh2-0.8.6-2.rockspec"))
         local output = run.luarocks("make")
         assert.is.truthy(output:match("Error: Inconsistency between rockspec filename"))

         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      end)

      it("ambiguous unnamed rockspec", function()
         assert.is.truthy(os.rename("lxsh-0.8.6-2.rockspec", "1_rockspec"))
         test_env.copy("1_rockspec", "2_rockspec")
         local output = run.luarocks("make")
         assert.is.truthy(output:match("Error: Please specify which rockspec file to use"))

         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      end)
      
      it("pack binary rock", function()
         assert.is_true(run.luarocks_bool("make --deps-mode=none --pack-binary-rock"))
         assert.is.truthy(lfs.attributes("lxsh-0.8.6-2.all.rock"))
      end)
   end)

   it("supports --pin #pinning", function()
      test_env.run_in_tmp(function(tmpdir)
         write_file("test-1.0-1.rockspec", [[
            package = "test"
            version = "1.0-1"
            source = {
               url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
            }
            dependencies = {
               "a_rock 1.0"
            }
            build = {
               type = "builtin", 
               modules = {
                  test = "test.lua"
               }
            }
         ]], finally)
         write_file("test.lua", "return {}", finally)

         assert.is_true(run.luarocks_bool("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --pin --tree=lua_modules"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/luarocks.lock"
         assert.is.truthy(lfs.attributes(lockfilename))
         local lockdata = loadfile(lockfilename)()
         assert.same({
            dependencies = {
               ["a_rock"] = "1.0-1",
               ["lua"] = test_env.lua_version .. "-1",
            }
         }, lockdata)
      end)
   end)

   it("respects luarocks.lock when present #pinning", function()
      test_env.run_in_tmp(function(tmpdir)
         write_file("test-2.0-1.rockspec", [[
            package = "test"
            version = "2.0-1"
            source = {
               url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
            }
            dependencies = {
               "a_rock >= 0.8"
            }
            build = {
               type = "builtin", 
               modules = {
                  test = "test.lua"
               }
            }
         ]], finally)
         write_file("test.lua", "return {}", finally)
         write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]], finally)

         print(run.luarocks("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --tree=lua_modules"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/2.0-1/test-2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/2.0-1/luarocks.lock"
         assert.is.truthy(lfs.attributes(lockfilename))
         local lockdata = loadfile(lockfilename)()
         assert.same({
            dependencies = {
               ["a_rock"] = "1.0-1",
            }
         }, lockdata)
      end)
   end)

   it("overrides luarocks.lock with --pin #pinning", function()
      test_env.run_in_tmp(function(tmpdir)
         write_file("test-2.0-1.rockspec", [[
            package = "test"
            version = "2.0-1"
            source = {
               url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
            }
            dependencies = {
               "a_rock >= 0.8"
            }
            build = {
               type = "builtin", 
               modules = {
                  test = "test.lua"
               }
            }
         ]], finally)
         write_file("test.lua", "return {}", finally)
         write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]], finally)

         print(run.luarocks("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --tree=lua_modules --pin"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/2.0-1/test-2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/2.0-1/luarocks.lock"
         assert.is.truthy(lfs.attributes(lockfilename))
         local lockdata = loadfile(lockfilename)()
         assert.same({
            dependencies = {
               ["a_rock"] = "2.0-1",
               ["lua"] = test_env.lua_version .. "-1",
            }
         }, lockdata)
      end)
   end)

   describe("#ddt upgrading rockspecs with double deploy types", function()
      local deploy_lib_dir = testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION
      local deploy_lua_dir = testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION
      local so = test_env.lib_extension
   
      before_each(function()
         test_env.copy_dir(testing_paths.fixtures_dir .. "/double_deploy_type", "ddt")
      end)

      after_each(function()
         test_env.remove_dir("ddt")
         os.remove("ddt."..test_env.lib_extension)
      end)

      it("when upgrading", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt1", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))
  
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt2", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))
      end)

      it("modules with same name from lua/ and lib/ when upgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt1", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt2", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/double_deploy_type_0_1_0_1-ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt.lua"))
         assert.same("ddt1", loadfile(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt2", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt1", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt2", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt.lua"))
         assert.same("ddt2", loadfile(deploy_lua_dir.."/ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/ddt_file"))
         assert.is.falsy(lfs.attributes(deploy_lib_dir.."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(deploy_lua_dir.."/ddt_file~"))
         assert.is.truthy(lfs.attributes(deploy_lib_dir.."/double_deploy_type_0_1_0_1-ddt."..so))
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt.lua"))
         assert.same("ddt1", loadfile(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt.lua")())
         assert.is.truthy(lfs.attributes(deploy_lua_dir.."/double_deploy_type_0_1_0_1-ddt_file"))
      end)
   end)

   describe("upgrading rockspecs with mixed deploy types", function()
      before_each(function()
         test_env.copy_dir(testing_paths.fixtures_dir .. "/mixed_deploy_type", "mdt")
      end)

      after_each(function()
         test_env.remove_dir("mdt")
         os.remove("mdt."..test_env.lib_extension)
      end)

      it("modules with same name from lua/ and lib/ when upgrading", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when upgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt."..test_env.lib_extension))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt_file"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt.lua"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mdt_file"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)
   end)
end)
