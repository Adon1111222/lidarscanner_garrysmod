# Lidar Scanner Garry's Mod
A small Garry's Mod project which implements the LIDAR Scanner function.
## Build
If you want to build from source code, you need to compress the code using minifycode in a folder or other application.
This will keep the file size to a minimum. Also, game should launch it without minify.

## Creating extensions

This addon supports extensions. Extensions can control the colour of the dots.

Each extension contains a file _lidarscanner2_extension_\extension_name\.lua which returns a table with the following architecture:
 name = "\extension name, minimum length - 6 characters\",
 desc = "\extension description\",
 version = "\extension version\",
 variables = {\list of extension variables('variable name' = 'default value', can be left empty\},
 gui = {\extension GUI table elements, can be left empty. see 'Extension GUI table elements' below.\},
 colorcalc = \function with input arguments: mattype, hitpos, hitnormal, ind, self, startpos. should return Color.\

### Extension GUI table elements:

{type = "\type, currently only checkbox and slider\",name = "\display name\",pos_x = \X position\,pos_y = \Y position\,variable = "\name of the variable from the variables table that controls this element\",def = \default value\,desc = "\description that appears on hover\",size = \size, available only with type slider\,min = \minimum value, available only with type slider\,max = \maximum value, available only with type slider\,dec = \number of numbers after the decimal point, available only with type slider\},

**Examples of extensions can be seen in source/lidarscanner2/lua/lidarscanner2_extensions/**
