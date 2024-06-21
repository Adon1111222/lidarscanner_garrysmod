local clrtable = {
    [MAT_CONCRETE] = Color(255,255,255),
    [MAT_DIRT] = Color(127,95,0),
    [MAT_GLASS] = Color(10,20,150),
    [MAT_DEFAULT] = Color(255,200,200),
    [MAT_SAND] = Color(155,155,0),
    [MAT_FLESH] = Color(255,0,0),
    [MAT_BLOODYFLESH] = Color(255,0,0),
    [MAT_GRASS] = Color(0,255,0),
}

return {
    name = "Default Colours",
    desc = "Standard colour table.",
    version = "1",
    variables = {
        calcpointcontent = true,
    },
    gui = {
        {type = "checkbox",name = "Point Contents Check",pos_x = 30,pos_y = 45,variable = "calcpointcontent",def = 1,desc = "Is water and other things tested for content?"},
        {type = "header",name = "Colour table:",pos_x = 0,pos_y = 60},
        {type = "text",name = "|    MAT_TYPE     |    COLOUR   |",pos_x = 0,pos_y = 75},
        {type = "text",name = "_________________________________",pos_x = 0,pos_y = 75},
        {type = "text",name = "|  MAT_CONCRETE   | 255,255,255 |",pos_x = 0,pos_y = 90},
        {type = "text",name = "|    MAT_DIRT     |   127,95,0  |",pos_x = 0,pos_y = 105},
        {type = "text",name = "|    MAT_GLASS    |  10,20,150  |",pos_x = 0,pos_y = 120},
        {type = "text",name = "|   MAT_DEFAULT   | 255,200,200 |",pos_x = 0,pos_y = 135},
        {type = "text",name = "|    MAT_SAND     |  155,155,0  |",pos_x = 0,pos_y = 150},
        {type = "text",name = "|    MAT_FLESH    |   255,0,0   |",pos_x = 0,pos_y = 165},
        {type = "text",name = "| MAT_BLOODYFLESH |   255,0,0   |",pos_x = 0,pos_y = 180},
        {type = "text",name = "|    MAT_GRASS    |   0,255,0   |",pos_x = 0,pos_y = 195},
    },
    colourcalc = function(mattype,hitpos,hitnormal,ind,self)
        if self.calcpointcontent then
            local cnt = util.PointContents(hitpos)
            if bit.band(cnt,CONTENTS_WATER) == CONTENTS_WATER then
                return Color(127,127,127)
            end
            if bit.band(cnt,CONTENTS_TRANSLUCENT) == CONTENTS_TRANSLUCENT then
                return Color(55,55,55)
            end
        end
        return clrtable[mattype] or Color(255,255,255)
    end,
}