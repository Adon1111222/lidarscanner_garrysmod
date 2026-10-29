# Lidar Scanner Garry's Mod
A small Garry's Mod project which implements the "LIDAR" Scanner function.

## Download
Latest release(zip): https://github.com/Adon1111222/lidarscanner_garrysmod/releases/latest/download/lidarscanner2.zip

## Build
There is also a tool called "minify" that can compress source code by removing comments and whitespace.
It does not work perfectly, so you might prefer to use other tools instead. Also you can simply leave the source code uncompressed.

## Creating extensions
This addon supports extensions. Extensions can control the colour of the scanned dots.

Each extension contains a Lua file `lidarscanner2_extensions/_lidarscanner2_extension_extname.lua` (where 'extname' is the id of the extension)
which returns a table with the following structure:
 string .name - extension name, minimum length - 6 characters
 string .desc - extension description
 string .version - extension version
 table .variables - list of extension variables(can be left empty), structure:
   ["variable name"] = default value(boolean,number),
   ...
 table .gui - extension GUI table elements, can be left empty. See 'Extension GUI table element' below
 function .colorcalc(number mattype,Vector hitpos,Vector hitnormal,number dotindex,table self,Vector scanpos) - callback function,
   which will be called hundreds of times per frame. Returns Color
 function .prescan() - callback function, which will be called before scanning
 function .postscan() - callback function, which will be called after scanning

### Extension GUI table element:

string .type - element type, one of the following:
  "header" - Creates "Header" text with large text size
  "text" - Creates text with default text size
  "checkbox" - Creates boolean checkbox
  "slider" - Creates numeric slider
  "colourchange" - Creates colour changer
string .name - display name. This also sets text for "text" and "header" elements
string .desc - description that appears on mouse cursor hover
number .pos_x - X position
number .pos_y - Y position
**For controlling elements:**
number .size - slider only. horizontal size
string .variable - name of the variable from the variables table that this element controls
string .variable_r - colour changer only. name of the variable from the variables table that this element controls. Red component
string .variable_g - colour changer only. name of the variable from the variables table that this element controls. Green component
string .variable_b - colour changer only. name of the variable from the variables table that this element controls. Blue component
any .def - default value
number .min - slider only. minimum value
number .max - slider only. maximum value
number .dec - slider only. number of digits after the decimal point

**Examples of extensions can be seen in source/lidarscanner2/lua/lidarscanner2_extensions/**
**The source code of extensions is not checked and not restricted within the Lua global environment.**

## Additional
If you want to import dots into Blender: https://github.com/Adon1111222/lidarscanner_scanstoblender
