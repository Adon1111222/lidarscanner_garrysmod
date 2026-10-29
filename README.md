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
which returns a table with the following structure: <br/>
&nbsp;string .name - extension name, minimum length - 6 characters <br/>
&nbsp;string .desc - extension description <br/>
&nbsp;string .version - extension version <br/>
&nbsp;table .variables - list of extension variables(can be left empty), structure: <br/>
&nbsp;&nbsp;["variable name"] = default value(boolean,number), <br/>
&nbsp;&nbsp;... <br/>
&nbsp;table .gui - extension GUI table elements, can be left empty. See ['Extension GUI table element'](#anchor-link1) below <br/>
&nbsp;function .colorcalc(number mattype,Vector hitpos,Vector hitnormal,number dotindex,table self,Vector scanpos) - callback function, <br/>
&nbsp;&nbsp;which will be called hundreds of times per frame. Returns Color <br/>
&nbsp;function .prescan() - callback function, which will be called before scanning <br/>
&nbsp;function .postscan() - callback function, which will be called after scanning <br/>
 
<a name="anchor-link1"></a>
### Extension GUI table element:

string .type - element type, one of the following: <br/>
&nbsp;"header" - Creates "Header" text with large text size <br/>
&nbsp;"text" - Creates text with default text size <br/>
&nbsp;"checkbox" - Creates boolean checkbox <br/>
&nbsp;"slider" - Creates numeric slider <br/>
&nbsp;"colourchange" - Creates colour changer <br/>
string .name - display name. This also sets text for "text" and "header" elements <br/>
string .desc - description that appears on mouse cursor hover <br/>
number .pos_x - X position <br/>
number .pos_y - Y position <br/>
**For controlling elements:** <br/>
number .size - slider only. horizontal size <br/>
string .variable - name of the variable from the variables table that this element controls <br/>
string .variable_r - colour changer only. name of the variable from the variables table that this element controls. Red component <br/>
string .variable_g - colour changer only. name of the variable from the variables table that this element controls. Green component <br/>
string .variable_b - colour changer only. name of the variable from the variables table that this element controls. Blue component <br/>
any .def - default value <br/>
number .min - slider only. minimum value <br/>
number .max - slider only. maximum value <br/>
number .dec - slider only. number of digits after the decimal point <br/>

**Examples of extensions can be seen in source/lidarscanner2/lua/lidarscanner2_extensions/** <br/>
**The source code of extensions is not checked and not restricted within the Lua global environment.** <br/>

## API
The `source/lidarscanner2/lua/autorun/lidarscanner2.lua` file contains all the key functionality for working with it. <br/>
Use the following global functions for scanning on clientside: <br/>
```
Adds a new FastScan action to the action queue. After scan complete, action will be removed from queue.
filter: a Filter value that will be directly passed to utraceline() arguments.
asynclinesfunc: function that will be asynchrously(at any time) called after action complete.
Returns ID of a new scan action
number LidarScanner_DoFastScan(vec_scanorigin,ang_scanang,filter,asynclinesfunc)

Adds a new BurstScan action to the action queue. After scan complete(when burst ang gets end), action will be removed from queue.
filter: a filter value that will be directly passed to utraceline() arguments.
asynclinesfunc: function that will be asynchrously(at any time) called after action complete. Burst scan calls this function multiple times.
Returns ID of a new scan action
number LidarScanner_DoBurstScan(vec_scanorigin,ang_scanang,filter,asynclinesfunc)

Updates Burst Scan values
Pass any value as nil to remove action from queue(filter value must be {})
LidarScanner_UpdateBurstScan(vec_scanorigin,ang_scanang,filter,scanid)

Clears last scan
LidarScanner_ClearLastScan()
```

## Additional
If you want to import dots into Blender: https://github.com/Adon1111222/lidarscanner_scanstoblender
