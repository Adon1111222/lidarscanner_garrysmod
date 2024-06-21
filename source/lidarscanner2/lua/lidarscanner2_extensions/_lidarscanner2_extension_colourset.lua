return {
    name = "Colour Set",
    desc = "Allows you to set a specific scan colour.",
    version = "1",
    variables = {
        colour_R = 255,
        colour_G = 255,
        colour_B = 255,
    },
    gui = {
        {type = "slider",name = "Color R",pos_x = 5,pos_y = 30,size = 180,variable = "colour_R",min = 0,max = 255,dec = 0,def = 255,desc = "Set R of scan colour"},
        {type = "slider",name = "Color G",pos_x = 5,pos_y = 45,size = 180,variable = "colour_G",min = 0,max = 255,dec = 0,def = 255,desc = "Set G of scan colour"},
        {type = "slider",name = "Color B",pos_x = 5,pos_y = 60,size = 180,variable = "colour_B",min = 0,max = 255,dec = 0,def = 255,desc = "Set B of scan colour"},
    },
    colourcalc = function(mattype,hitpos,hitnormal,ind,self)
        return Color(self.colour_R,self.colour_G,self.colour_B)
    end,
}