local capture = require 'src.capture'

local function tester()
	local foo = 20
	error "Something went wrong!"
end

xpcall(tester, function(message)
	print("Error: "..message)
	print("Starting server for debugging...")
	capture.new(3):serve()
end)
