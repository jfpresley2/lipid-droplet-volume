   
import std.stdio;
import std.file;
import std.c.stdlib;
import std.string;
import std.math;
import std.getopt;
import std.conv;
import std.algorithm;
import image;
import medianLib;
import perimeter;

//----------------------------------------------------------//

struct Parms {
    string image = "";             // input image name (already background corrected)
    string boundaries = "";        // whole image if never defined
    string spots = "";             // spotfile if you want to use it
    string outfile = "out.dat";
    string mode = "mode";          // method to background correct image
                                   // median_neighborhood || mode || none
                                   // are the valid values.  Anything else generates a warning
                                   // and "none". 
    
    void printParms() {
       writefln("Image: %s.", image); // later should take multiple channels
       if (boundaries == "") {
          writeln("No file with cell boundaries.");
       } else {
          writefln("Polygon file with cell boundaries is %s.", boundaries);
       }
       if (spots == "") {
          writeln("Not quantitating spots file.");
       } else {
          writefln("Spot data is contained in the file %s.", spots);
       }
       writefln("Output Data: %s.", outfile);
       writefln("File containing cell boundaries: %s.", boundaries);
       writefln("Mode: %s.", mode);
       writeln("--------------------------------------");
       writeln();
    }
}

//----------------------------------------------------------//

struct CellAccum {
   string name;
   int sum;
   real rsum;             // Usually, only one of sum, rsum used.
   bool isreal;

   this(string n) {
     name   = n;
     sum    = 0;
     rsum   = 0.0;
     isreal = false;
   }

   this(string n, int s) {
     name = n;
     sum  = s;
   }

  CellAccum blankcloneWithName() {
     CellAccum result = CellAccum(name);
     return result;
  }

  void add(int n) {
    sum += n;
  }

  void radd(real n) {
    rsum += n;
    isreal = true;
  }

  void reset() {
    // doesn't alter whether int or real
    sum  = 0;
    rsum = 0.0;
  }
}


//----------------------------------------------------------//

struct Spot {
   int spotNo;
   real x, y;
   int sum, pixels;
   real volume;
}

struct summedSpots {
  int totalSpots = 0;
  int sumFluorescence = 0;
  int  pixels = 0;
  real volume = 0.0;
}

summedSpots sumSpotsInPolygon(Spot[] spots, Perimeter p) {
   summedSpots results;
   Point point;
   foreach(Spot s; spots) {
      point.x = cast(int) floor(s.x+0.5);
      point.y = cast(int) floor(s.y+0.5);
      if (p.inBoundaryQ(point)) {
         results.totalSpots++;
         results.sumFluorescence += s.sum;
         results.pixels          += s.pixels;
         results.volume          += s.volume;
      }
   }
   return results;
}

Spot[] readSpotlistFromFile(string filename) {
   Spot s;
   Spot[] spotlist;
   spotlist.reserve(500);             // can later figure how many lines in file
   File f = File(filename, "r");
   string line;
   string[] valus;
   line=f.readln();         // read header
   if (!validHeader(line)) {
     throw new Exception("Spotfile does not have valid header.");
   }
   while ((line=f.readln()) !is null) {
      line  = line.chomp();
      valus = line.split(",");
      if (valus.length < 11) {
         continue;
      }
      s = Spot();
      s.spotNo = to!int(valus[0]);
      s.x      = to!real(valus[1]);
      s.y      = to!real(valus[2]);
      s.sum    = to!int(valus[3]);
      s.pixels = to!int(valus[4]);
      s.volume = to!real(valus[10]);
      spotlist ~= s;
   }
   return spotlist;
}

/*
 * Must verify header format
 * spotNo,x,y,sum,pixels,maxPixel(###),x1,y1,x2,y2,volume
 * Of these, maxPixel,x1,y1,x2,y2 can be disregarded
 * Could modify the whole thing later to be smarter (columns in any order,
 * other irrelevant columns there, etc)
 */

bool validHeader(string line) {
  string values[] = line.chomp.split(",");
  if (values[0] == "spotNo" &&
      values[1] == "x"      &&
      values[2] == "y"      &&
      values[3] == "sum"    &&
      values[4] == "pixels" &&
      values[10] == "volume")
  {  
     return true; 
  }
  else 
  { 
     return false;
  } 

}

//----------------------------------------------------------//

int sumImage(Iplane img) {
   int sum = 0;
   int i;
 
   for (i=0; i< img.img.length; i++) {
      sum += img.img[i];
   }
   return sum;
}

int determineMaxVal(Iplane img) {
   // works for single channel images only
   if (img.tuple != 1) {
      throw new Exception("determineThreshold does not work for multi-channel images.");
   }
   int max = 0;
   int i;
   for (i=0; i < img.img.length; i++) {
       max = (max < img.img[i] ? img.img[i] : max);
   }
   writefln("Max is %d.", max);
   return max;
}


// Determines background modal value by finding histogram peak

int determineHistogramPeak(Iplane img) {
   int i;
   int peak;
   int peakval = -1;     // negative cannot be valid

   // works for single channel images only
   // *** will fail nastily if any values are negative -- check this later

   if (img.tuple != 1) {
      throw new Exception("determineHistogramPeak does not work for multi-channel images.");
   }
   // determine max value
   int max = determineMaxVal(img);

   // make histogram
   int[] hist = new int[max + 1];   // zero will go into lowest slot
   for (i=0; i < img.img.length; i++) { hist[img.img[i]]++; }   

   // find peak
   for (i=0; i < hist.length; i++) {
      if (hist[i] > peakval) {
         peakval = hist[i];
         peak    = i;
      }
   }
   return peak;
}

void printUsage() {
    writeln("sum_cells --image image.pgm --out image_sum.dat [ --boundaries boundary.dat --mode mode --spotfile spots.dat ]");
}

Parms parseArgs(string[] args) {
   Parms p;
   try {
     getopt(args, 
        "image", &p.image,
        "out", &p.outfile,
        "spotfile", &p.spots,
        "boundaries", &p.boundaries,
        "mode", &p.mode,
     );
   } catch (Exception e) {
     printUsage();
     writeln("Program exiting.");
     exit(1);
   } 
   return p;
}

void main(string[] args) {
   Iplane   image, outputImage;
   Iplane[] imgs;
   CellAccum[] frames;
   Perimeter[] polygons;
   Spot[] spotList;
   bool rgb  = false;
   bool quanSpots = false;
   string CellName;
   // *** comprehensive parm checking required
   Parms parms = parseArgs(args);
   if (parms.outfile == "") {
     writeln("Output file missing");
     printUsage();
     exit(1);
   } 
   if (parms.spots != "") {
     quanSpots = true;
     if (exists(parms.spots)) {
        spotList = readSpotlistFromFile(parms.spots);
     } else {
        writefln("Spots file <%s> does not exist!", parms.spots);
        exit(1);
     }
   }
   writeln("---- sum_cells started ----");
   parms.printParms();

   if (parms.image != "") {
      image       = readPNM(parms.image);
      writeln("Image exists and was read");
      // *** fragment image if multi-channel
      if (image.tuple == 1) {
        writeln("Single channel image.");
        imgs = [ image ];
      } else {
         writeln("Multi channel image");
         imgs = image.explode();
      }
      writeln("Image exploded");
      if (imgs.length == 3) {
        rgb = true;             // we don't care except what to call the channels
      } else {
        rgb = false;
      }
   } 
   writeln("About to read boundary file.");
   if (parms.boundaries ~= "") {
     /*** for now, invert x-coordinate.  This flips from Cocoa.
      *** Later, allow this to be set from command line
      ***/
     polygons = readBoundaries(parms.boundaries, image.xsize, image.ysize, true); 
   } 
   writeln("Boundary file read.");
   // *** background correct cell depending on mode
   if (parms.image != "") {
      if (parms.mode == "mode") {
         foreach (ref Iplane my_i; imgs) {
            int background = determineHistogramPeak(my_i);
            foreach(ref pixel; my_i.img) {
               pixel = pixel - background;
               if (pixel < 0) { pixel = 0; }
            }
         }
      } else {
           // *** for now do nothing
                 // *** median filter to come later median_neighborhood median_32
                 // *** will be normal syntax
                 // *** fixed_15 will be normal for subtracting preset value
                 // *** that or "none" should be explicit, otherwise warn
      }
   }
   // *** for each cell boundary, create an accumulator
   // -- here create an array of cells
   // *** this all needs to be disposed of since not needed any more
   // *** as soon as I figure out how to red/green/blue label later
   if (imgs.length > 0) {
      frames = new CellAccum[imgs.length];
   } else {
      frames = new CellAccum[1];
   }
   int counter = 1;
   if (rgb) {
      frames[0] = CellAccum("red");
      frames[1] = CellAccum("green");
      frames[2] = CellAccum("blue");
   } else {
       foreach (ref CellAccum frame; frames) {
         frame = CellAccum("frame" ~ to!string(counter));
         counter++;
       }
   }

   /* *** below should cycle through images, not old frames
    * only reason I'm still doing this way is to re-use rgb names
    */
   writeln("About to start quantification.");
   CellAccum[][] all_results;    
   CellAccum[] results_cell;   // results from one cell.  Assumes the same number of
                               // channels in each image analyzed that are written to the same
                               // output file across multiple runs of this program.  
                               // If not, the output will be a big incomprehensible mess!
   foreach(Perimeter polygon; polygons) {
      foreach(int n, CellAccum frame; frames) {
         CellName = "Cell_" ~ to!string(n);
         CellAccum result = CellAccum(frame.name ~ "_" ~ polygon.name);
         /**/ writeln("Summing image using perimeter.");
         if (parms.image != "") {
             result.sum       = sumImageUsingPerimeter(imgs[n], polygon);
         } else {
             result.sum       = -1;
         }
         /**/ writefln("Sum is %d.", result.sum);     
         results_cell ~= result;    
      }
      if (quanSpots) {
         summedSpots ssum = sumSpotsInPolygon(spotList,polygon);
         CellAccum ss     = CellAccum("Droplet_Fluorescence");
         CellAccum tp     = CellAccum("Droplet_Pixels");
         CellAccum dv     = CellAccum("Droplet_Volume");
         CellAccum dc     = CellAccum("Droplet_Count");
         ss.add(ssum.sumFluorescence);
         tp.add(ssum.pixels);
         dv.radd(ssum.volume);
         dc.add(ssum.totalSpots);
         results_cell ~= dc;
         results_cell ~= tp;
         results_cell ~= ss;
         results_cell ~= dv;
      }
      all_results ~= results_cell;
      results_cell = [];
   }

   // Make sure no crash later if no data.
   if ((all_results.length < 1)||(all_results[0].length < 1)) {      
      writeln("Nothing quantitated.  Won't write to output file.");
      exit(0);
   }
   
   File f;
   if (!exists(parms.outfile)) {   
       f = File(parms.outfile,"w");
       f.writef("%s", "Filename,Cellname");
       // All cells should have same channels.
       foreach(CellAccum r; all_results[0]) {
          f.writef(",%s", r.name);
       }
       //if (quanSpots) {
       //   f.writef("%s",",Droplet_Count,Droplet_Pixels,Droplet_Fluorescence,Droplet_Volume")'
       //}
       f.writeln();
   } else {
       f = File(parms.outfile,"a");
   }
   foreach(CellAccum[] result_cell; all_results) {
      string[] strlist = result_cell[0].name.split("_");
      string cellname = strlist[$-1];
      f.writef("%s,%s", parms.image, cellname);
      foreach(CellAccum result; result_cell) {
         if (result.isreal) { 
            f.writef(",%g", result.rsum);
         } else {          // is integer value
            f.writef(",%d", result.sum);
         }         
      }
      f.writeln();

   } 
   f.close();

}

      //f.writefln("%s,%s,%d", parms.image, result.name, result.sum);
