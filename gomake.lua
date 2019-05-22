#!/bin/env lua

-- Copyright 2019 Herewetech China

-- Permission is hereby granted, free of charge,
-- to any person obtaining a copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction,
-- including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- gomake.lua
-- @author Dr.NP <np@corp.herewetech.com>
-- @since 05/09/2019

VERSION = '0.1'

local me = arg[0]
local sub_cmd = arg[1]
local target_directory = arg[2]

if sub_cmd == nil then sub_cmd = 'help' else sub_cmd = tostring(sub_cmd) end
if target_directory == nil then target_directory = '.' else target_directory = tostring(target_directory) end

local vendor_queue = {}
local vendor_processed = {}

-- Ruturn values
R_OK = 0
R_FATAL = 255
R_ERROR = 1

-- For better console output
-- Colors
COLORS = {
    reset = 0, clear = 0, bright = 1, dim = 2, underscore = 4, blink = 5, reverse = 7, hidden = 8,
    black = 30, red = 31, green = 32, yellow = 33, blue = 34, magenta = 35, cyan = 36, white = 37,
    onblack = 40, onred = 41, ongreen = 42, onyellow = 43, onblue = 44, onmagenta = 45, oncyan = 46, onwhite = 47,
}

function output_ex(data, ...)
    local _arg = {}
    for k, v in pairs({...}) do _arg[k] = v end
    local color = _arg[1]
    local attribute = _arg[2]
    local output = string.char(27) .. '['
    if color ~= nil then
        color = tonumber(color)
    else
        color = COLORS.white
    end

    if attribute ~= nil then
        attribute = tonumber(attribute)
        output = output .. attribute .. ';' .. color .. 'm'
    else
        output = output .. color .. 'm'
    end

    output = output .. data .. string.char(27) .. '[0m'

    return output
end

function echo_ex(data)
    local f = io.output(io.stdout)
    f:write(data)
    f:close()
end

function print_ex(data)
    echo_ex(data .. "\n")
end

-- Runtime
function run_cmd(cmd, debug)
    if debug == nil then
        cmd = cmd .. ' 2>/dev/null'
    end

    local ro = {}
    local chk = assert(io.popen(cmd))
    for line in chk:lines() do
        ro[#ro + 1] = line
    end
    local rc = chk:close()

    return rc, ro
end

function assert_git()
    local cmd = 'git --version'
    local c, _ = run_cmd(cmd)
    if c == nil then
        print(output_ex('Git missed !', COLORS.red, COLORS.bright))

        os.exit(R_FATAL)
    end
end

function md5_sum(input)
    local cmd = 'echo "' .. input .. '" | md5sum'
    local c, o = run_cmd(cmd)
    local v = o[1]
    local output = ''
    if v ~= nil then
        output = string.match(v, '%x+')
    end

    return output
end

function scan_dir(dir, wildcast)
    if dir == nil then dir = '.' else dir = tostring(dir) end
    if wildcast == nil then wildcast = '*' else wildcast = tostring(wildcast) end
    local list = {}
    local cmd = 'find ' .. dir .. ' -type f -name "' .. wildcast .. '"'
    cmd = cmd .. ' -not -path "' .. dir .. '/vendor*"'
    cmd = cmd .. ' -not -path "' .. dir .. '/.git*"'
    cmd = cmd .. ' -not -path "*_test.go"'
    local c, l = run_cmd(cmd)

    return l
end

function is_gopath(dir)
    if dir == null then dir = '.' else dir = tostring(dir) end
    local c, l = run_cmd('find ' .. dir .. ' -type d -name "src"')
    if c ~= nil and #l > 0 then
        return true
    end

    return false
end

function make_gopath(dir)
    local cmd = 'mkdir ' .. dir .. '/src -p'
    local c, _ = run_cmd(cmd)
    if c ~= nil then
        local fp = assert(io.open(dir .. '/.gitignore', 'w'))
        fp:write('/bin\n')
        fp:write('/src/vendor\n')
        fp:close()
        cmd = 'git init -q ' .. dir
        c, _ = run_cmd(cmd)
        if c ~= nil then
            return true
        end
    end

    return false
end

-- Queue
function queue_push(q, e)
    if type(q) == 'table' then
        table.insert(q, e)
    end
end

function queue_pop(q)
    local e = nil
    if type(q) == 'table' then
        e = table.remove(q, 1)
    end

    return e
end

-- Original files
function gen_makefile()
    m = [[
PROJECT=_PROJECT_
PREFIX=$(shell pwd)
VERSION=$(shell git describe --match 'v[0-9]*' --dirty='.m' --always)
VENDOR=src/vendor

# Env
ifndef GO
	GO=/usr/bin/go
endif

ifndef GOFMT
	GOFMT=/usr/bin/gofmt
endif

.PHONY: all clean install uninstall
.DEFAULT: all

# Targets
all: fmt build

fmt:
	@echo -e "\033[1;32m * Source code format checking ...\033[0m"
	@echo -e "\033[1;37m   @ gofmt\033[0m source code"
	@test -z "$$(find src -name \"*.go\" -not -path \"$(VENDOR)/*\" -exec $(GOFMT) -s -l '{}' +)"

build:
	@echo -e "\033[1;33m + Building ${PROJECT} ...\033[0m"
	@mkdir -p ./bin
	@echo -e "\033[1;37m   @ `$(GO) version`\033[0m"
_BUILD_BINARIES_

clean:
	@echo
	@echo -e "\033[1;35m - Cleaning ${PROJECT} ...\033[0m"
	@rm ./bin/* -f
	@rm $(VENDOR)/* -rf
	@echo
	@echo

install:
	@echo
	@echo "\033[1;34m + Installing ${PROJECT} ...\033[0m"
	@cp ./bin/* /usr/local/bin
	@echo
	@echo

uninstall:
	@echo
	@echo "\033[1;33m - Uninstall ${PROJECT} ...\033[0m"
_UNINSTALL_BINARIES_
	@echo
	@echo

]]

    return m
end

function gen_dockerfile()
    m = [[
FROM scratch
]]
end

function gen_dockerfile()
    return
end

function parse_binary(content)
    content = string.gsub(content, '(//.-\n', '')
    content = string.gsub(content, '/%*.-%*/', '')
    local package = string.match(content, 'package%s-(%w+)\n')
    if package == 'main' then
        -- Find main func
        if string.match(content, 'func%s-main%(') then
            return true
        end
    end

    return false
end

-- Vendor FS
function valid_vendor_import(import)
    return import:match('^([%w%-_]+%..-/.-/[%w%-_]+)')
end

local VENDOR_ALIASES = {
    {
        pattern = 'cloud.google.com/go',
        repo = 'github.com/googleapis/google-cloud-go.git',
        vendor_dir = target_directory .. '/src/vendor/cloud.google.com/go',
        repo_dir = target_directory .. '/src/vendor/cloud.google.com',
        vendor_r = 'cloud.google.com/go',
        recursive = false
    },
    {
        pattern = 'google.golang.org/api',
        repo = 'github.com/googleapis/google-api-go-client.git',
        vendor_dir = target_directory .. '/src/vendor/google.golang.org/api',
        repo_dir = target_directory .. '/src/vendor/google.golang.org',
        vendor_r = 'google.golang.org/api',
        recursive = false
    },
    {
        pattern = 'google.golang.org/grpc',
        repo = 'github.com/grpc/grpc-go.git',
        vendor_dir = target_directory .. '/src/vendor/google.golang.org/grpc',
        repo_dir = target_directory .. '/src/vendor/google.golang.org',
        vendor_r = 'google.golang.org/grpc',
        recursive = false
    },
    {
        pattern = 'google.golang.org/genproto',
        repo = 'github.com/google/go-genproto.git',
        vendor_dir = target_directory .. '/src/vendor/google.golang.org/genproto',
        repo_dir = target_directory .. '/src/vendor/google.golang.org',
        vendor_r = 'google.golang.org/genproto',
        recursive = false
    },
    {
        pattern = 'google.golang.org/appengine',
        repo = 'github.com/golang/appengine.git',
        vendor_dir = target_directory .. '/src/vendor/google.golang.org/appengine',
        repo_dir = target_directory .. '/src/vendor/google.golang.org',
        vendor_r = 'google.golang.org/appengine',
        recursive = false
    },
    {
        pattern = 'go4.org',
        repo = 'github.com/go4org/go4.git',
        vendor_dir = target_directory .. '/src/vendor/go4.org',
        repo_dir = target_directory .. '/src/vendor',
        recursive = true
    },
    {
        pattern = 'go.opencensus.io',
        repo = 'github.com/census-instrumentation/opencensus-go.git',
        vendor_dir = target_directory .. '/src/vendor/go.opencensus.io',
        repo_dir = target_directory .. '/src/vendor',
        recursive = true
    },
    {
        pattern = 'honnef.co/go/tools',
        repo = 'github.com/dominikh/go-tools.git',
        vendor_dir = target_directory .. '/src/vendor/honnef.co/go/tools',
        repo_dir = target_directory .. '/src/vendor/honnef.co/go',
        recursive = true
    },
    {
        pattern = 'honnef.co/go/js',
        repo = 'github.com/dominikh/go-js-dom.git',
        vendor_dir = target_directory .. '/src/vendor/honnef.co/go/js',
        repo_dir = target_directory .. '/src/vendor/honnef.co/go',
        recursive = true
    },
    {
        pattern = 'bazil.org/fuse',
        repo = 'github.com/bazil/fuse.git',
        vendor_dir = target_directory .. '/src/vendor/bazil.org/fuse',
        repo_dir = target_directory .. '/src/vendor/bazil.org',
        recursive = true
    }
}

function prepare_vendor(vendor)
    local r = {
        repo = vendor,
        vendor_dir = target_directory .. '/src/vendor/' .. vendor,
        repo_dir = target_directory .. '/src/vendor/' .. string.match(vendor, '(.+)/'),
        recursive = true
    }

    if string.match(vendor, '^github.com') then
        r['repo'] = r['repo'] .. '.git'
    end

    for k, item in pairs(VENDOR_ALIASES) do
        if string.find(vendor, item.pattern) then
            r['repo'] = item.repo
            r['vendor_dir'] = item.vendor_dir
            r['repo_dir'] = item.repo_dir
            r['recursive'] = item.recursive
            break
        end
    end

    if string.find(vendor, 'golang.org/x') then
        r['repo'] = string.gsub(vendor, 'golang.org/x', 'github.com/golang') .. '.git'
        r['recursive'] = false
    end

    if string.find(vendor, 'k8s.io') then
        r['repo'] = string.gsub(vendor, 'k8s.io', 'github.com/kubernetes') .. '.git'
        r['recursive'] = false
    end

    r['repo'] = 'https://' .. r['repo']
    if r['vendor_r'] == nil then
        r['vendor_r'] = vendor
    end

    return r
end

function process_vendor(vendor, force_recursive)
    print('Process vendor : ' .. vendor)
    local r = prepare_vendor(vendor)
    local cmd = 'mkdir -p ' .. r.repo_dir
    run_cmd(cmd)

    print(output_ex('Updating vendor ', COLORS.yellow, COLORS.bright) .. output_ex(vendor, COLORS.green, COLORS.bright) .. output_ex(' fron ', COLORS.yellow, COLORS.bright) .. output_ex(r.repo, COLORS.magenta, COLORS.bright) .. output_ex(' into ', COLORS.yellow, COLORS.bright) .. output_ex(r.repo_dir, COLORS.cyan, COLORS.bright) .. output_ex(' ...', COLORS.yellow, COLORS.bright))
    -- Test git repo
    local chk_fp = io.open(r.vendor_dir .. '/.git/HEAD')
    if chk_fp == nil then
        cmd = 'git clone ' .. r.repo .. ' ' .. r.vendor_dir
    else
        io.close(chk_fp)
        cmd = 'git -C ' .. r.vendor_dir .. ' pull origin master'
    end

    c, _ = run_cmd(cmd, true)
    if c == nil then
        return false
    end

    if r.recursive == true or force_recursive == true then
        queue_push(vendor_queue, r.vendor_dir)
    end

    return true
end

function append_vendor(vendor)
    r = prepare_vendor(vendor)
    local vendor_hash = md5_sum(r.vendor_r)
    if vendor_processed[vendor_hash] ~= nil then
        print(output_ex('Vendor : ', COLORS.blue, COLORS.bright) .. output_ex(vendor, COLORS.green, COLORS.bright) .. output_ex(' Exists', COLORS.magenta, COLORS.bright))
        return
    end

    if process_vendor(vendor) == true then
        print(output_ex('Vendor : ', COLORS.blue, COLORS.bright) .. output_ex(vendor, COLORS.green, COLORS.bright) .. output_ex(' Proceesed', COLORS.blue, COLORS.bright))
        vendor_processed[vendor_hash] = vendor
    end
end

function parse_imports(content)
    local vendor = ''
    content = string.gsub(content, '(//.-\n', '')
    content = string.gsub(content, '/%*.-%*/', '')
    local s_imports = content:gmatch('import[%s]-%"(.-)%"')
    for import in s_imports do
        vendor = valid_vendor_import(import)
        if vendor ~= nil then
            append_vendor(vendor)
        end
    end

    local m_imports = content:match('import[%s]-%((.-)%)')
    if m_imports ~= nil then
        for import in m_imports:gmatch('%"(.-)%"') do
            vendor = valid_vendor_import(import)
            if vendor ~= nil then
                append_vendor(vendor)
            end
        end
    end

    return
end

function consume_vendor_queue()
    while true do
        local dir = queue_pop(vendor_queue)
        if dir == nil then break end
        local l = scan_dir(dir, '*.go')
        for _, f in pairs(l) do
            local fp = assert(io.open(f))
            local content = fp:read('*all')
            fp:close()
            if type(content) == 'string' then
                parse_imports(content)
            end
        end
    end

    return R_OK
end

-- Sub-commands
local _sub_init = function()
    print(output_ex('Initialize new gomake project in directory <', COLORS.magenta, COLORS.bright) .. output_ex(target_directory, COLORS.green, COLORS.bright) .. output_ex('> ...', COLORS.magenta, COLORS.bright))
    make_gopath(target_directory)

    return R_OK
end

local _sub_makefile = function()
    local chk = is_gopath(target_directory)
    if chk ~= true then
        print(output_ex('Directory <' .. target_directory .. '> was not a valid gomake project directory', COLORS.red, COLORS.bright))
        return R_ERROR
    end

    local list = scan_dir(target_directory .. '/src', '*.go')
    local binaries = {}
    if type(list) == 'table' then
        for _, f in pairs(list) do
            local fp = assert(io.open(f))
            local content = fp:read('*all')
            fp:close()

            if true == parse_binary(content) then
                -- TODO: same name
                local sub, filename = string.match(f, '([%w%-_]+)/([%w%-_]+)%.go')
                local build_target = string.gsub(f, '([%w%-_]+%.go)', '')
                if filename == 'main' and sub ~= 'src' then
                    binaries[#binaries + 1] = {binary = sub, target = build_target, source = f}
                else
                    binaries[#binaries + 1] = {binary = filename, target = build_target, source = f}
                end
            end
        end
    end

    local build_binaries = ''
    local uninstall_binaries = ''
    for k, v in pairs(binaries) do
        build_binaries = build_binaries .. '\t@echo -e "\\033[0;34m     + ' .. v.binary .. '\\033[0m"\n'
        build_binaries = build_binaries .. '\t@GOPATH=${PWD} CGO_ENABLED=0 GOOS=linux $(GO) build -a -ldflags \'-extldflags "-static"\' -o ./bin/' .. v.binary .. ' ' .. v.target .. '\n'
        uninstall_binaries = uninstall_binaries .. '\t@rm /usr/local/bin/' .. v.binary .. ' -f\n'
    end

    local project = ''
    echo_ex(output_ex('Project name : ', COLORS.magenta, COLORS.bright))
    local tline = io.read()
    if tline ~= nil then
        project = string.match(tline, '([%w%-_]+)')
    end

    local content = gen_makefile()
    content = string.gsub(content, '_BUILD_BINARIES_', build_binaries)
    content = string.gsub(content, '_UNINSTALL_BINARIES_', uninstall_binaries)
    content = string.gsub(content, '_PROJECT_', project)
    local fp = assert(io.open(target_directory .. '/Makefile', 'w'), 'Open Makefile error')
    fp:write(content)
    fp:close()

    return R_OK
end

local _sub_dockerfile = function()
    local content = gen_dockerfile()
    local fp = assert(io.open(target_directory .. '/Dockerfile', 'w'), 'Open Dockerfile error')
    fp:write(content)
    fp:close()

    return R_OK
end

local _sub_vendor = function()
    local chk = is_gopath(target_directory)
    if chk ~= true then
        print(output_ex('Directory <' .. target_directory .. '> was not a valid gomake project directory', COLORS.red, COLORS.bright))
        return R_ERROR
    end

    queue_push(vendor_queue, target_directory .. '/src')

    return consume_vendor_queue()
end

local _sub_help = function()
    print()
    print(output_ex('== Gomake help topic ==', COLORS.white, COLORS.bright))
    print(output_ex('Usage:', COLORS.magenta))
    print(output_ex('\tgomake', COLORS.green, COLORS.bright) .. output_ex(' <command>', COLORS.yellow, COLORS.bright) .. output_ex(' [target directory]', COLORS.blue, COLORS.bright))
    print()
    print(output_ex('Commands:', COLORS.magenta))
    print(output_ex('\tinit        ', COLORS.white, COLORS.bright) .. output_ex('Initialize a gomake project.', COLORS.white))
    print(output_ex('\tvendor      ', COLORS.white, COLORS.bright) .. output_ex('Search and prepare vendor packages.', COLORS.white))
    print(output_ex('\tmakefile    ', COLORS.white, COLORS.bright) .. output_ex('Generate Makefile of project.', COLORS.white))
    print(output_ex('\tdockerfile  ', COLORS.white, COLORS.bright) .. output_ex('Generate Dockerfile of project.', COLORS.white))
    print(output_ex('\thelp        ', COLORS.white, COLORS.bright) .. output_ex('This topic. [Default value]', COLORS.white))
    print()
    print(output_ex('Directory:', COLORS.magenta))
    print(output_ex('\tGomake project directory, default value is current directory.', COLORS.white))
    print()
end

local sub_funcs = {
    init = _sub_init,
    makefile = _sub_makefile,
    dockerfile = _sub_dockerfile,
    vendor = _sub_vendor,

    help = _sub_help
}

-- Portal
function main()
    print(output_ex('Gomake ' .. VERSION .. ' Powered by Herewetech ...', COLORS.green, COLORS.bright))
    print(output_ex('Sub-command:', COLORS.cyan, COLORS.bright), sub_cmd)
    print(output_ex('Target directory:', COLORS.cyan, COLORS.bright), target_directory)
    assert_git()

    if type(sub_funcs[sub_cmd]) == 'function' then
        -- Go through
        return sub_funcs[sub_cmd]()
    else
        print(output_ex('Unsupported sub-command <' .. sub_cmd .. '>', COLORS.red, COLORS.bright))
        return R_ERROR
    end

    return R_OK
end

os.exit(main())
