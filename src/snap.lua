
local M = {}
package.loaded[...] = M 
_ENV = M  --Lua 5.2+

--adjust x, or x should be multiple of grid_x
Sx = function(x, grid_x)
    if x%grid_x ~= 0 then   --if x is not multiple of grid_x then we have to adjust it
      if x%grid_x >= grid_x/2 then   --upper bound 
        x = x + ( grid_x - x%grid_x )
      elseif x%grid_x < grid_x/2 then -- lower bound
        x = x - x%grid_x
      end
    end
    return x
  end

Sy = function(y, grid_y)
    if y%grid_y ~= 0 then   --if x is not multiple of grid_y then we have to adjust it
      if y%grid_y >= grid_y/2 then   --upper bound 
        y = y + ( grid_y - y%grid_y )
      elseif y%grid_y < grid_y/2 then -- lower bound
        y = y - y%grid_y
      end
    end
    return y
  end
