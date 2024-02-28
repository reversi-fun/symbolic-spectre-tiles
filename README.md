# symbolic-spectre-tiles
This Ruby script generates symbolic exact plane coordinates for family of "spectres" tiles, expressed as a formula.<br>
This Ruby script not only generates SVG files for Tile(a,b) coefficients but also produces a CSV file containing exact plane coordinates like the expression:
```
((-19.5)*A + (6.5)*B*√3)  -  ((28.5)*B + (21.5)*A*√3)*i 
  == -2.842170943040401e-14  -633.9745962155613*i
```
* “family of shapes”

    * “Spectres”:

       Refers to the edges of Tile(Edge_a,Edge_b) that produce a “family of shapes” we call “Spectres”.
       That is not requires its own mirror reflections.   
       The set includes belows:

          * when (Edge_a == Edge_b) => "Spectre". 
          * when (Edge_a != Edge_b) => {“Chevron,” and “Comet”} <br>
                                    or {14-sided Hat and Turtle}.
    
    * “Weakly Chiral Aperiodic Monotile”:
      
       Describes the 14-sided polygon where Tile(1,1) == Tile(Edge_a,Edge_b) {Edge_a == Edge_b} is a monotile.


    * "The Hat": 

        Refers to the 13-sided polygon that requires its own mirror reflections.<br>
       Although the shape of ‘The Hat’(13-sided) is similar(14-sided Hat), it is unrelated to this project.


# Usage
## Edit Configurations
You can update the following parameters at the beginning of the Ruby script:


```Ruby
## Configuration
#* Increase this number for larger tilings.
N_ITERATIONS = 4
#* Shape Edge_ratio tile(Edge_a, Edge_b)
Edge_a = 10.0 # 20.0 / (Math.sqrt(3) + 1.0)
Edge_b = 10.0 # 20.0 - Edge_a
## End of Configuration.
```

## Generating SVG Files Quickly
If you want to generate only SVG files promptly, spectre-tiles_float.rb is the tool for you.
Simply run the following command:
```
> ruby spectre-tiles_float.rb
```

## Generating SVG Files with CSV File Containing Symbolic Coordinates.
If you want to create both SVG files with floating-point transfer coordinates and a CSV file containing symbolic coordinates, you can use the spectre-tiles_Symbolic.rb script. 
Simply run the following command:
   ```
   ruby spectre-tiles_Symbolic.rb
   ```

* ![console outputs](./spectre-tile7.3-12.6-4.log.txt)

  it provides useful information for verifying the drawn Spectre tiles 
  and for convenient clipping.
  The output includes the following details:
  * Spectre Shape Coordinates by symbolic and floating-point for given ration of Edge_a Edge_b.
  * Spectre tiling Quad points Coordinates.
  * total number of Spectre tile's.
  * Spectre tile's Count by rotated angles. 

```
coef A = 7.320508075688773		Ratio(0.366)
coef B = 12.679491924311227		Ratio(0.634)
SPECTRE_POINTS = [
	0+0i, 		(0.0 + 0.0*i),
	((1.0)*A)+0i, 		(7.3205 + 0.0*i),
	((1.5)*A)-((0.5)*A*√3)*i, 		(10.9808 + -6.3397*i),
	((1.5)*A + (0.5)*B*√3)+((0.5)*B + (-0.5)*A*√3)*i, 		(21.9615 + 0.0*i),
	((1.5)*A + (0.5)*B*√3)+((1.5)*B + (-0.5)*A*√3)*i, 		(21.9615 + 12.6795*i),
	((2.5)*A + (0.5)*B*√3)+((1.5)*B + (-0.5)*A*√3)*i, 		(29.282 + 12.6795*i),
	((3.0)*A + (0.5)*B*√3)+((1.5)*B)*i, 		(32.9423 + 19.0192*i),
	((3.0)*A)+((2.0)*B)*i, 		(21.9615 + 25.359*i),
	((3.0)*A + (-0.5)*B*√3)+((1.5)*B)*i, 		(10.9808 + 19.0192*i),
	((2.5)*A + (-0.5)*B*√3)+((1.5)*B + (0.5)*A*√3)*i, 		(7.3205 + 25.359*i),
	((1.5)*A + (-0.5)*B*√3)+((1.5)*B + (0.5)*A*√3)*i, 		(**0.0** + 25.359*i),
	((0.5)*A + (-0.5)*B*√3)+((1.5)*B + (0.5)*A*√3)*i, 		(-7.3205 + 25.359*i),
	((-0.5)*B*√3)+((1.5)*B)*i, 		(-10.9808 + 19.0192*i),
	0+((1.0)*B)*i, 		(0.0 + 12.6795*i),
]
Mystic_SPECTRE_POINTS = [
	0+0i, 		(0.0 + 0.0*i),
	((1.0)*B)+0i, 		(12.6795 + 0.0*i),
	((1.5)*B)-((0.5)*B*√3)*i, 		(19.0192 + -10.9808*i),
	((1.5)*B + (0.5)*A*√3)-((-0.5)*A + (0.5)*B*√3)*i, 		(25.359 + -7.3205*i),
	((1.5)*B + (0.5)*A*√3)+((1.5)*A + (-0.5)*B*√3)*i, 		(25.359 +  **0.0*i**),
	((2.5)*B + (0.5)*A*√3)+((1.5)*A + (-0.5)*B*√3)*i, 		(38.0385 + **0.0*i**),
	((3.0)*B + (0.5)*A*√3)+((1.5)*A)*i, 		(44.3782 + 10.9808*i),
	((3.0)*B)+((2.0)*A)*i, 		(38.0385 + 14.641*i),
	((3.0)*B + (-0.5)*A*√3)+((1.5)*A)*i, 		(31.6987 + 10.9808*i),
	((2.5)*B + (-0.5)*A*√3)+((1.5)*A + (0.5)*B*√3)*i, 		(25.359 + 21.9615*i),
	((1.5)*B + (-0.5)*A*√3)+((1.5)*A + (0.5)*B*√3)*i, 		(12.6795 + 21.9615*i),
	((0.5)*B + (-0.5)*A*√3)+((1.5)*A + (0.5)*B*√3)*i, 		(0.0 + 21.9615*i),
	((-0.5)*A*√3)+((1.5)*A)*i, 		(-6.3397 + 10.9808*i),
	0+((1.0)*A)*i, 		(0.0 + 7.3205*i),
]
  init quad
   quad[0] = ((1.5)*A + (0.5)*B*√3)+((0.5)*B + (-0.5)*A*√3)*i	(21.96152422706632)+(8.881784197001252e-16)*i
   quad[1] = ((2.5)*A + (0.5)*B*√3)+((1.5)*B + (-0.5)*A*√3)*i	(29.28203230275509)+(12.679491924311227)*i
   quad[2] = ((3.0)*A)+((2.0)*B)*i	(21.96152422706632)+(25.358983848622454)*i
   quad[3] = ((0.5)*A + (-0.5)*B*√3)+((1.5)*B + (0.5)*A*√3)*i	(-7.320508075688772)+(25.35898384862245)*i
  ..... (omitted for brevity) .....
  4 Iterationed transformations["Delta"][[6,5,3,0]]
   transformations[6] = { angle: -60,	 moveTo: (((-21.0)*A + (27.5)*B*√3)) + (((-55.5)*B + (-55.0)*A*√3))*i }
   transformations[5] = { angle: 0,	 moveTo: (((27.0)*A + (54.0)*B*√3)) + (((-45.0)*B + (-78.0)*A*√3))*i }
   transformations[3] = { angle: 60,	 moveTo: (((72.0)*A + (41.5)*B*√3)) + (((13.5)*B + (-38.0)*A*√3))*i }
   transformations[0] = { angle: 180,	 moveTo: (0) + (0)*i }
  4 Iterationed quad["Delta"]
   quad[0] = ((-10.5)*A + (42.5)*B*√3)-((65.5)*B + (74.5)*A*√3)*i	(856.4994448555865)+(-1775.1288694035716)*i
   quad[1] = ((68.5)*A + (58.5)*B*√3)-((10.5)*B + (66.5)*A*√3)*i	(1786.2039704680606)+(-976.3208781719644)*i
   quad[2] = ((96.0)*A + (39.0)*B*√3)+((41.0)*B + (-23.0)*A*√3)*i	(1559.2682201217085)+(228.2308546376022)*i
   quad[3] = ((-41.5)*A + (-4.5)*B*√3)-((34.5)*B + (11.5)*A*√3)*i	(-402.6279441628825)+(-583.2566285183163)*i
* 4 Iterations, generated 4401 tiles
buildSpectreTiles process 0.0757302sec.
 each angle's tile count =	{-150=>74, -120=>638, -90=>79, -60=>659, -30=>87, 0=>674, 30=>90, 60=>664, 90=>87, 120=>641, 150=>79, 180=>629, 360=>496}
"svg file write process 0.1384604sec"
"csv file write process 0.1252199sec"
"total process time 0.3395227sec"
"save filename="
"spectre-tile7.3-12.6-4-4401tiles.svg"
```

* Contents of the SVG File

  * shape's coordinates

    The original JavaScript code used 28 floating-point numbers to draw a single Spectre shape, resulting in a file size of approximately 500 characters.<br>
    Additionally, the Python code it was based on utilized 6 floating-point numbers, including affine transformation coefficients, and resulted in a file size of around 200 characters.<br>
    Notably, the Python code often expressed values like cos(60 deg) = 0.5 as lengthy strings such as 0.499999999999.

    In contrast, this program generates a more compact SVG file for a single Spectre shape using only 2 floating-point numbers to represent translation (movement) and 1 integer to denote rotation angle.

    Focusing on the quad coordinates of the Spectre shape rather than examining all 14 vertex coordinates can provide more concise insights.

  * Spectre Shapes and Their Colors

    In the original JavaScript code, colors were assigned based on the label type for the Spectre shapes.<br>
    The arrangement of labels in a fractal pattern is crucial evidence for generating tilings of the weakly chiral aperiodic monotile Tile(1,1) known as “Spectre”.

    In this code, In this code, the tiles are colored using **four colors** to ensure that adjacent tiles have different colors.<br>
    In addition, this code also includes a mechanism to color the tiles with six different colors based on their rotation angles.<br>
    This approach facilitates the discovery of locally similar clusters within the generated shapes.<br>
    Additionally, the labels are displayed using &lt;text&gt; tags that specify the same rotation angle as the shape.<br>
    If you find the label text distracting, you can simply comment out the code that outputs the &lt;text&gt; tags.

    Take a look at the image below:
      
      
      Mystec Spectre Shapes Clusters　<img src="./spectre-color-for_find_mystec-clusters.png" width="60%"/>   
      

    
     Feel free to explore the fascinating patterns and colors!
  

* ![Contents of the CSV File](./spectre-tile7.3-12.6-4-4401tiles.svg.csv)

    This compact CSV file provides essential information for working with Spectre shapes. The quad coordinates of the Spectre shape can be easily extracted from this data.

    - **label**: The label associated with original Papers.
        This header also contains the values of the coefficients A and B
    - **transform**: The transformation expressed as a complex number (e.g.,  "((-1.5)*A + (-1.0)*B*√3)+((0.5)*A*√3)*i" ).
    - **angle**: The rotation angle in degrees(0,30,60,90,120,180,240).
    - **transform\[0\].x** ~~ **transform\[1\].y**: Affine transformation coefficients of rotation. it not Includes SVG-file.
    - **transform\[2\].x** and **transform\[2\].y**: The coordinate of transformation. same as SVG-file.<br>
        Its value is the value obtained by substituting the values of the coefficients A and B into the expression in **transform** field.
        *spectre-tiles_Symbolic.rb* can calculate more accurate coordinates than *spectre-tiles_float.rb* .<br>
        However, as shown in the example below, it does contain floating-point errors.
      
        * A = 20.0 / (Math.sqrt(3) + 1.0) == 7.320508075688773
        * B = 20.0 - A == 12.679491924311227 
        * **transform** (algebraic expression) == "((-19.5)*A + (6.5)*B*√3)-((28.5)*B + (21.5)*A*√3)*i"
        * transform\[2\].x == -2.842170943040401e-14<br> 
                              (includes floating-points error) ==> non-obvious, but the correct value is zero.
        * transform\[2\].y == -633.9745962155613 
  

    - **pt0-coef a0**, **a1**, **b0**, **b1**:

        An integer factor that indicates the exact planar coordinates of the reference point of the spectre shape.<br>
        Here,{a0,a1,b0,b1} are integers that appear to be almost uncorrelated arbitrary integers,<br>
        but have constraints that are not yet known or unknown.
        ```
            pt[0] = (A*(a0 + a1 / 2) + B*(b1 * (sqrt(3) / 2))) +
                    (B*(b0 + b1 / 2) + A*(a1 * (sqrt(3) / 2)))*i
        ```


| label | transform<br> {A:7.320508075688773,<br>  B:12.679491924311227} | angle | transform\[0\].x | transform\[0\].y | transform\[1\].x | transform\[1\].y | transform\[2\].x | transform\[2\].y | pt0-coef:a0 | a1 | b0 | b1 |
|-------|-----------------------------------------------------|----:|-----------------|-----------------|-----------------|-----------------|-----------------|-----------------|---:|---:|---:|---:|
| "Psi" | "0+0i"                                              | 0     | 1.0             | 0.0             | 0.0             | 1.0             | 0.0             | 0.0             | 0 | 0 | 0 | 0 |
| "Delta" | "((-1.5)*A)-((0.5)*A*√3)*i"                        | 60    | 0.5             | 0.8660254037844386 | -0.8660254037844386 | 0.5 | -10.98076211353316 | -6.339745962155613 | -1 | -1 | 0 | 0 |
| "Psi" | "((-1.5)*A + (-1.0)*B*√3)+((0.5)*A*√3)*i" | 60 |0.5 |0.8660254037844386|-0.8660254037844386 |0.5|-32.94228634059948 | 6.339745962155613 | -2 | 1 | 1 | -2 |
|  | ... (omitted for brevity) ...
| "Gamma1" | "((-12.0)*A + (18.0)*B*√3)-((36.0)*B + (36.0)*A*√3)*i" |  0 | 1.0 | 0.0 | 0.0 | 1.0 | 307.4613391789284 | -912.9234185504083 | 24 | -72 | -54 | 36 |
| "Gamma2" | "((-9.0)*A + (17.5)*B*√3)-((34.5)*B + (36.0)*A*√3)*i"  | 30 | 0.8660254037844386| 0.5 | -0.5 |0.8660254037844386 | 318.4421012924616 | -893.9041806639415 | 27 | -72 | -52 | 35 |


# clipping SVG Files
  To crop a rectangular region from the SVG files generated by the previous command, you can use **svg-cutter2.rb**.<br> 
  When specifying the minimum X and Y coordinates as well as the maximum X and Y coordinates for cropping a rectangular region, you can refer to the quad vertex coordinates output by the previous command.

  * The general format is: 
  ```
  ruby svg-cutter2.rb input_svg_filename min_x min_y max_x max_y
  ```

  * Explanation
	- **Input SVG File**: The original SVG file you want to crop.
	- **min_x**, **min_y**: The minimum X and Y coordinates of the rectangular clipping area.
	- **max_x**, **max_y**: The maximum X and Y coordinates of the rectangular clipping area.
	- **Output File**: The resulting SVG file containing the cropped region.

  * exsample output
    
      ```
      > ruby svg-cutter2.rb spectre-tile7.3-12.6-4-4401tiles.svg  300 -1000 1400 -700
      ```
      ```
      ["rect point X,Y", 856.4994448555865, -1775.1288694035716]
      ["rect point X,Y", 1786.2039704680606, -976.3208781719644]
      ["rect point X,Y", 1559.2682201217085, 228.2308546376022]
      ["rect point X,Y", -402.6279441628825, -583.2566285183163]
      input range=(-538.0573435631248,-1889.2442967223728)-(1921.633369868303,1065.077321642143)
       output file = "spectre-tile7.3-12.6-4-4401tiles_(300,-1000)-(1400,-700).svg" 
      ```

  * Clipped SVG File
      ![ "spectre-tile7.3-12.6-4-4401tiles_(300,-1000)-(1400,-700).svg"](./spectre-tile7.3-12.6-4-4401tiles_(300,-1000)-(1400,-700).svg)


# Message to Contributors
## Adding Self-Verification and Debugging Information
    
   In the source code of this program, we’ve included code for self-verification and debugging purposes.<br>
   For visual validation, I found it convenient to change the colors of the tiles.<br>
   As a result, I’ve left several color-coding processes for debugging purposes.<br>
   We encourage adding information for analyzing the features of Spectre tileings and retaining the self-verification code as comments without removing it.<br>

   Providing such detailed information in the README file for MPL-licensed source code helps other developers understand the codebase more effectively.<br>
   The self-verification and debugging comments contribute to improving the overall quality of the project. 

## Help Needed: Four-Coloring of Tiling

   I was able to color 559 tiles with 4 colors based on the following appendix:<br>

   ![Appendix: four-colourings of the Hats and Spectre tilings](https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/aperiodic-spectre/#four-colouring)

   However, the algorithm I derived solely from the appendix failed to color the 4-layer cluster of 4401 tiles, as below figure. <br>

   <img src="./four-coloring-failed-Level4.png" width="60%">four-coloring-failed-Level 4 tiles</img>


   Subsequently, using my own algorithm, I managed to color 34,649 tiles across 5 layers with 4 colors.<br>
   However, I haven’t been able to verify how many layers my custom algorithm can color with 4 colors.<br>
   Could someone **provide a validation** method?<br>

  If you have any further requests or need additional assistance, feel free to ask!
  
# Acknowledgments
This project provides a Ruby script that can generate the weakly chiral aperiodic monotile called Tile(a,b) “Spectre”.<br>
This Ruby script is a port of the original Python script available here.<br> 
Additionally, the Python script[4] [5] itself was inspired by the research paper authored by the creators.<br>
ported from JavaScript from the web app [1] provided [2] by the authors of the original research paper [3].<br>

[1]: https://cs.uwaterloo.ca/~csk/spectre/app.html

[2]: https://cs.uwaterloo.ca/~csk/spectre/

[3]: https://arxiv.org/abs/2305.17743

[4]: https://github.com/shrx/spectre/issues/1

[5]: https://github.com/reversi-fun/spectre
    
