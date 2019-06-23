-- Program to convert the given image to a iup Image table to be used in the GUI.
-- There are 4 imgTable2Str functions:
-- 1 - This one creates a pixels and a colors table with width and height for this definition: iup.image{width = width: number, height = height: number, pixels = pixels: table, colors = colors: table}
-- 2 - This one creates a table for the oldest definition: iup.image{line0: table, line1: table, ...; colors = colors: table} -> (elem: ihandle) [in Lua]
-- 3 - This one creates a table for the RGB definition on each pixel for the definition: iup.imagergb {width = width: number, height = height: number, pixels = pixels: table} -> (elem: ihandle) [in Lua]
-- 4 - This one creates a table for the RGBA definition on each pixel for the definition: iup.imagergba{width = width: number, height = height: number, pixels = pixels: table} -> (elem: ihandle) [in Lua]

-- For the RGBA creation there is a convertColor2Transparent routine which converts every occurrence of the given color to alpha=0 (transparent)

require("imlua")


-- with width height and pixels table
function imgTable2Str1(t)
	local str = "{\n\twidth="..t.width..",\n\theight="..t.height..",\n\tpixels={"
	for i = 1,#t.pixels do
		str = str.."\n\t\t"
		for j = 1,#t.pixels[i] do
			str = str..t.pixels[i][j]..","
		end
	end
	str = str:sub(1,-2)	-- remove last comma
	str = str.."\n\t};\n\tcolors={"
	for i = 1,#t.colors do
		str = str.."\n\t\t\""..t.colors[i].."\","
	end
	str = str:sub(1,-2) -- remove last comma
	str = str.."\n\t}\n}"
	return str	
end

-- With line by line tables
function imgTable2Str2(t)
	local str = "{"
	for i = 1,#t.pixels do
		str = str.."\n\t{"
		for j = 1,#t.pixels[i] do
			str = str..t.pixels[i][j]..","
		end
		str = str:sub(1,-2)	-- remove last comma
		str = str.."};"
	end
	str = str:sub(1,-2)	-- remove last comma
	str = str.."\n\tcolors={"
	for i = 1,#t.colors do
		str = str.."\n\t\t\""..t.colors[i].."\","
	end
	str = str:sub(1,-2) -- remove last comma
	str = str.."\n\t}\n}"
	return str	
end

-- for iup.imagergb
function imgTable2Str3(t)
	local r,g,b,chunk
	local str = "{\n\twidth="..t.width..",\n\theight="..t.height..",\n\tpixels={"
	for i = 1,#t.pixels do
		str = str.."\n\t\t"
		for j = 1,#t.pixels[i] do
			r,g,b = t.colors[t.pixels[i][j]]:match("^(.-) (.-) (.+)$")
			chunk = r..","..g..","..b..","
			str = str..chunk..string.rep(" ",15-#chunk)
		end
	end
	str = str:sub(1,-2)	-- remove last comma
	str = str.."\n\t}\n}"
	return str	
end

-- for iup.imagergba
function imgTable2Str4(t)
	local str = "{\n\twidth="..t.width..",\n\theight="..t.height..",\n\tpixels={"
	local chunk
	for i = 1,#t.pixels do
		str = str.."\n\t\t"
		for j = 1,#t.pixels[i] do
			r,g,b = t.colors[t.pixels[i][j]]:match("^(.-) (.-) (.+)$")
			chunk = r..","..g..","..b..","..a[t.height-i][j-1]..","
			str = str..chunk..string.rep(" ",19-#chunk)
		end
		--print(i)
	end
	str = str:sub(1,-2)	-- remove last comma
	str = str.."\n\t}\n}"
	return str	
end

function imgTable2Str5(t)
	local str = "{\n\t"
	local strr = ""
	local strg = ""
	local strb = ""
	local chunk
	for i = #t.pixels,1,-1 do
		strr = strr.."\n\t\t"
		strg = strg.."\n\t\t"
		strb = strb.."\n\t\t"
		for j = 1,#t.pixels[i] do
			r,g,b = t.colors[t.pixels[i][j]]:match("^(.-) (.-) (.+)$")
			chunk = r..","
			strr = strr..chunk..string.rep(" ",7-#chunk)
			chunk = g..","
			strg = strg..chunk..string.rep(" ",7-#chunk)
			chunk = b..","
			strb = strb..chunk..string.rep(" ",7-#chunk)
		end
		--print(i)
	end
	strb = strb:sub(1,-2)	-- remove last comma
	str = str.."\n\t\t--RED"..strr.."\n\t\t--GREEN"..strg.."\n\t\t--BLUE"..strb.."\n\t}"
	return str	
end

function imgTable2Str6(t)
	local str = "{\n\t"
	local strr = ""
	local strg = ""
	local strb = ""
	local stra = ""
	local chunk
	for i = #t.pixels,1,-1 do
		strr = strr.."\n\t\t"
		strg = strg.."\n\t\t"
		strb = strb.."\n\t\t"
		stra = stra.."\n\t\t"
		for j = 1,#t.pixels[i] do
			r,g,b = t.colors[t.pixels[i][j]]:match("^(.-) (.-) (.+)$")
			chunk = r..","
			strr = strr..chunk..string.rep(" ",7-#chunk)
			chunk = g..","
			strg = strg..chunk..string.rep(" ",7-#chunk)
			chunk = b..","
			strb = strb..chunk..string.rep(" ",7-#chunk)
			chunk = a[t.height-i][j-1]..","
			stra = stra..chunk..string.rep(" ",7-#chunk)
		end
		--print(i)
	end
	strb = strb:sub(1,-2)	-- remove last comma
	str = str.."\n\t\t--RED"..strr.."\n\t\t--GREEN"..strg.."\n\t\t--BLUE"..strb.."\n\t\t--ALPHA"..stra.."\n\t}"
	return str	
end

-- print usage information
print("img2table: script to convert a image file to a iup image table that can be loaded into iup.")
print("\nusage:")
print("\n>lua img2table document.bmp [tablefunction(1-6) r g b save_image]")
print("\n\t-r g b are numbers from 0-255 specifying a color in the image whose alpha has to be set to 0 (totally transparent)")
print("\tsave_image if anything passed for this then also saves the processed png image.")
print("\t-tablefunction is a integer from 1-6 specifying which conversion function needs to be used:")
print("\t\t1 - this one creates a pixels and a colors table with width and height for this definition: iup.image{width = width: number, height = height: number, pixels = pixels: table, colors = colors: table}")
print("\t\t2 - this one creates a table for the oldest definition: iup.image{line0: table, line1: table, ...; colors = colors: table} -> (elem: ihandle) [in lua]")
print("\t\t3 - this one creates a table for the rgb definition on each pixel for the definition: iup.imagergb {width = width: number, height = height: number, pixels = pixels: table} -> (elem: ihandle) [in lua]")
print("\t\t4 - this one creates a table for the rgba definition on each pixel for the definition: iup.imagergba{width = width: number, height = height: number, pixels = pixels: table} -> (elem: ihandle) [in lua]")
print("\t\t5 - this one creates a table for the pixels definition to create a RGB ImImage")
print("\t\t6 - this one creates a table for the pixels definition to create a RGBA ImImage")
print()

args = table.pack(...)
if args[1] then
	print(args[1])
	i = im.FileImageLoad(args[1])
	if i then
		print(i:Height(),i:Width())
		r = i[0]
		g = i[1]
		b = i[2]
		if i:HasAlpha() then
			a = i[3]
		else
			a = {}
			for k = 1,i:Height() do
				a[k-1] = {}
				for j = 1,i:Width() do
					a[k-1][j-1] = 255
				end
			end
		end

		function convertCol2Transparent(color)
			for row = 0,i:Height()-1 do
				for col = 0,i:Width()-1 do
					if r[row][col] == color.r and g[row][col] == color.g and b[row][col] == color.b then
						r[row][col] = 255
						g[row][col] = 255
						b[row][col] = 255					
						a[row][col] = 0
					end
				end
			end
		end

		local doAlpha = true
		for i = 3,5 do
			if not args[i] or tonumber(args[i]) < 0 or tonumber(args[i]) > 255 then
				doAlpha = false
				break
			end
		end
		if doAlpha then
			-- Change indicted color to transparent
			convertCol2Transparent({r=math.floor(tonumber(args[3])),g=math.floor(tonumber(args[4])),b=math.floor(tonumber(args[5]))})
		end
		imgo = {width = i:Width(), height=i:Height(),pixels = {};colors = {}}

		for row = 0,i:Height()-1 do
			imgo.pixels[i:Height()-row] = {}
			for col = 0,i:Width() - 1 do
				c = r[row][col].." "..g[row][col].." "..b[row][col]
				local cIndex
				for k = 1,#imgo.colors do
					if imgo.colors[k] == c then
						cIndex = k
						break
					end
				end
				if not cIndex then
					imgo.colors[#imgo.colors + 1] = c
					cIndex = #imgo.colors
				end
				imgo.pixels[i:Height()-row][col+1] = cIndex
				--print(r[row][col],g[row][col],b[row][col])
			end
		end

		-- Use the appropriate function number here
		if not args[2] or (math.floor(tonumber(args[2])) ~= 2 and math.floor(tonumber(args[2])) ~= 3 and 
		  math.floor(tonumber(args[2])) ~= 4 and math.floor(tonumber(args[2])) ~= 5 and math.floor(tonumber(args[2])) ~= 6) then
			ostr = imgTable2Str1(imgo)
		elseif math.floor(tonumber(args[2])) == 2 then
			ostr = imgTable2Str2(imgo)
		elseif math.floor(tonumber(args[2])) == 3 then
			ostr = imgTable2Str3(imgo)
		elseif math.floor(tonumber(args[2])) == 4 then
			ostr = imgTable2Str4(imgo)
		elseif math.floor(tonumber(args[2])) == 5 then
			ostr = imgTable2Str5(imgo)
		elseif math.floor(tonumber(args[2])) == 6 then
			ostr = imgTable2Str6(imgo)
		end
		--ostr = imgTable2Str4(imgo)
		if args[6] then
			-- Also save the image to disk
			local err = im.FileImageSave("out.png", "PNG", i)
		end
			
		f = io.open("out.lua","w+")
		f:write(ostr)
		f:close()
		print("DONE: out.lua created")
	else
		print("ERROR: Cannot open the document: "..args[1])
	end
else
	print("ERROR: Need the document name to convert.")
end
