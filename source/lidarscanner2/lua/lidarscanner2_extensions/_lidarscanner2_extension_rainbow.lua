local th = 1.5
local function Q_rsqrt(number) local x2,y,i = number*0.5,number,number i = 0x5f3759df - bit.rshift(i,1) y = y * (th - (x2 * y * y)) return y end
return {
    name = "Rainbow colour",
    desc = "Just a rainbow. Slow.",
    version = "0.1",
    variables = {
        dist = true,
        hue = 256,
        saturation = 1,
        value = 1,
    },
    gui = {
        {type = "checkbox",name = "Distance",pos_x = 30,pos_y = 75,variable = "dist",def = 1,desc = "Use distance"},
        {type = "slider",name = "Hue",pos_x = 5,pos_y = 30,size = 180,variable = "hue",min = 1,max = 1440,dec = 0,def = 256,desc = "Colour hue"},
        {type = "slider",name = "Saturation",pos_x = 5,pos_y = 45,size = 180,variable = "saturation",min = 0,max = 1,dec = 2,def = 1,desc = "Colour saturation"},
        {type = "slider",name = "Brightness",pos_x = 5,pos_y = 60,size = 180,variable = "value",min = 0,max = 1,dec = 2,def = 1,desc = "Colour brightness"},
    },
    colourcalc = function(mattype,hitpos,hitnormal,ind,self,startpos)
        local ind = ind
        if self.dist then
            ind = startpos:DistToSqr(hitpos)
        end
        return HSVToColor(ind/self.hue,self.saturation,self.value)
    end,
}