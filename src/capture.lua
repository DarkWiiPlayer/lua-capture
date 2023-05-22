local capture = {}

capture.__index = capture

local css = [[
	:is(h1, h2, h3, h4, h5, h6):before { display: none; }
]]

function capture.new(i)
	local stack = { version = _VERSION }
	i = i or 1
	for j = i + 1, math.huge do
		local info = debug.getinfo(j)
		if not info then
			break
		end
		info.locals = {}
		for li = 1, math.huge do
			local name, value = debug.getlocal(j, li)
			if not name then
				break
			end
			table.insert(info.locals, {name=name, value=value})
		end
		info.upvalues = {}
		for ui = 1, math.huge do
			local name, value = debug.getupvalue(info.func, ui)
			if not name then
				break
			end
			table.insert(info.upvalues, {name=name, value=value})
		end
		stack[j-i] = info
	end
	return setmetatable(stack, capture)
end

function capture:map(fn)
	local res = {}
	for key, value in ipairs(self) do
		res[key] = fn(value)
	end
	return res
end

local function getdef(info)
	local file, err = io.open(info.short_src)
	if file then
		local buf = {}
		local lnum = 0
		if info.linedefined > 0 then
			for line in file:lines() do
				lnum = lnum + 1
				if lnum > info.lastlinedefined then
					return buf
				end
				if lnum >= info.linedefined then
					table.insert(buf, {num=lnum, text=line})
				end
			end
		else
			for line in file:lines() do
				lnum = lnum + 1
				table.insert(buf, {num=lnum, text=line})
			end
			return buf
		end
	else
		return nil, err
	end
end

local function funcname(info)
	if info.name then
		return info.name
	elseif info.short_src then
		if info.linedefined > 0 then
			return string.format("(anon) %s:%i", info.short_src, info.linedefined)
		else
			return info.short_src
		end
	end
end

function capture:report()
	local html = require 'skooma.html'
	function html.inspect(element, trace)
		do local current = trace
			while current do
				if element == current[2] then
					return tostring(element)
				end
				current = current[1]
			end
		end
		if type(element) == "table" then
			local keys = {}
			for key in pairs(element) do table.insert(keys, key) end
			if #keys > 0 then
				return html.details (
					html.summary(tostring(element)),
					html.table(self.map(keys, function(key)
						return html.tr(
							html.th(key),
							html.td(html.inspect(element[key], {trace, element}))
						)
					end))
				)
			else
				return "{}"
			end
		elseif type(element) == "function" then
			local info = debug.getinfo(element)
			local lines = getdef(info)
			if lines then
				return html.details(
					html.summary(tostring(element)),
					html.code(self.map(lines, function(line)
						return html.div(html.lineNumber(line.num), line.text)
					end))
				)
			else
				return tostring(element)
			end
		else
			return tostring(element)
		end
	end

	return html.html (
		html.link { rel = "stylesheet", href = "https://darkwiiplayer.github.io/css/all.css" },
		--html.link { rel = "stylesheet", href = "https://darkwiiplayer.github.io/css/schemes/talia.css" },
		html.style(css),
		html.main (
			html.h1 "Stack trace",
			html.p(self.version),
			self:map(function(info)
				return html.details {
					open = true;
					html.summary(funcname(info));
					function()
						local lines = getdef(info)
						if lines then
							return html.details(
								html.summary "Definition",
								html.code(self.map(lines, function(line)
									return html.div(html.lineNumber(line.num), line.text)
								end))
							)
						else
							return {}
						end
					end,
					html.h3 "Locals";
					html.table(
						self.map(info.locals, function(variable)
							return html.tr(
								html.th(html.code(variable.name)),
								html.td(html.inspect(variable.value))
							)
						end)
					),
					html.h3 "Upvalues";
					html.table(
						self.map(info.upvalues, function(variable)
							return html.tr(
								html.th(html.code(variable.name)),
								html.td(html.inspect(variable.value))
							)
						end)
					),
					html.details (
						html.summary("dump"),
						html.pre(html.code(require("inspect")(info)))
					)
				}
			end)
		)
	)
end

function capture:serve(port)
	local pegasus = require 'pegasus'

	local server = pegasus:new { port = port or "8080", location = "." }

	server:start(function(_request, response)
		response
			:addHeader("Content-Type", "text/html;charset=utf8")
			:write(tostring(self:report()))
	end)
end

return capture
