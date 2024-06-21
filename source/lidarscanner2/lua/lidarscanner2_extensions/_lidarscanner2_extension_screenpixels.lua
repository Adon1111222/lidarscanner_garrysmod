return {
    name = "Screen Pixels",
    desc = "Takes colours from the real world.\nVery slow.\nMUST BE ENABLED lidarscanner_prescan !!!!!!\n\nDO NOT FORGET TO DISABLE IT AFTER USE!!!!!!",
    version = "0.1",
    variables = {},
    gui = {},
    colourcalc = function(mattype,hitpos,hitnormal,ind,self,burstyaw)
        local trhitposscr = hitpos:ToScreen()
        local r,g,b = render.ReadPixel(trhitposscr.x,trhitposscr.y)
        return Color(r,g,b)
    end,
    prescan = function()
        render.CapturePixels()
    end,
}