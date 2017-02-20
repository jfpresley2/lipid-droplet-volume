  
import std.stdio;
import std.c.stdlib;
import std.string;
import std.math;
import std.getopt;
import std.random;
import std.conv;
import image;
import spots;
import convolve;
import circleFit;
import watershedLib;
import dialate;
//import wrapper;

enum Color { uncolored, red, yellow, green, blue };

double global_min_radius = 3.0;           // smallest radius to fit as green

struct Parms {
    string image = "";             // input image name (already background corrected)
    string gfpimage = "";          // gfp-image 
    string datafile = "dat.dat";   // name for output file to write to
    string mode = "fwhm";          // fwhm/basic/composite
    string scratch = "";           // scratch image used to compute spots
    int minPixels    = 6;
    int maxPixels    = 1_000_000;
    int thresh       = -1;
    double calValue  = -1.0;               // make sure default value invalid
    double gfpCal    = -1.0;               // convert GFP to number molecules
    double fract     = 0.5;                // spot fraction img1 default to FWHM
    double minRadius = 3.0;                // set from global_min_radius
    double pixelSize = 0.1;                // pixel size in microns

    void printParms() {
       writefln("Image: %s.", image);
       writefln("Gfpimage: %s.", gfpimage);
       writefln("Datafile: %s.", datafile);
       if (scratch == "") {
          writefln("Don't write scratch image -- not specified.");
       } else {
          writefln("Scratch Image: %s", scratch);
       }
       writefln("Mode(fwhm|basic|composite)=%s.", mode);
       writefln("minPixels: %d.", minPixels);
       writefln("maxPixels: %d.", maxPixels);
       writefln("calValue: %g.", calValue);
       writefln("gfpCal: %g.", gfpCal);
       writefln("thresh: %d", thresh);
       writefln("fract: %g", fract);
       writefln("minradius: %g", minRadius);
       writefln("pixelSize: %g", pixelSize);
       writeln("--------------------------------------");
       writeln();
    }
}

int[] sumThroughMask(Iplane img, Iplane mask, int maxspotnum) {
   int i;
   int[] sums = new int[maxspotnum];
   if (img.img.length != mask.img.length) {
      throw new Exception("scratch image and image to quan different lengths.");
   }
   for (i=0; i< img.img.length; i++) {
       int maskval = mask.img[i];
       if (maskval != 0) {
          if (maskval > maxspotnum) {
             throw new Exception("sumThroughMask got spotnum larger than expected");
          } else {
             sums[maskval] += img.img[i];
          }
          
       }
   }
   return sums;
}

Iplane sliceout(Iplane img, Iplane scratch, int n, int x1, int x2, int y1, int y2) {
    int x, y, xn, yn, index;   // img size must be same as scratch size, no checks done
    Iplane sliced = new Iplane("", x2-x1+1, y2-y1+1, 1, img.maxval); 

    for (y=y1; y<=y2; y++) {
      for (x=x1; x<=x2; x++) {
         index = y*scratch.xsize+x;
         if (scratch.img[index] == n) {
            yn = y - y1;
            xn = x - x1;
            sliced.img[yn*sliced.xsize+xn] = img.img[index];
            //sliced.img[yn*sliced.xsize+xn] = scratch.img[index];
            //if (index == 1) { sliced.img[yn*sliced.xsize+xn] = n; }
         }        
      }
    }
    return sliced;
}

int determineThreshold(Iplane img) {
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
   return (max / 10);
}


void printUsage() {
    writeln("sum_tip --calValue 322.2 --image image.pgm --gfpimage gfpimage.pgm [ --scratch scr.pgm default \"\" ] --data datafile.dat [--thresh -1 fract 0.5 --minradius 3.0 --mode fwhm --pixelSize 0.1 ]");
}

Parms parseArgs(string[] args) {
   Parms p;
   try {
     getopt(args, 
        "mode", &p.mode,
        "calValue", &p.calValue,
        "gfpCal", &p.gfpCal,
        "image", &p.image,
        "gfpimage", &p.gfpimage,
        "scratch", &p.scratch,
        "minPixels", &p.minPixels,
        "maxPixels", &p.maxPixels,
        "thresh", &p.thresh,
        "fract", &p.fract,
        "data", &p.datafile,
        "minradius", &p.minRadius,
        "pixelSize", &p.pixelSize,
     );
   } catch (Exception e) {
     printUsage();
     writeln("Program exiting.");
     exit(1);
   } 
   return p;
}

ulong diff(ulong a, ulong b) {
  if (a > b) {
     return a - b;
  } else {
     return b - a;
  }
}


bool goodFit(OutlineGetter o, CircData c, ref SpathSolver s, int spotNum) {
   const maxIterations  = 100;
   const double epsilon = 0.1;          // fit to 1/10 pixel
   double ssqTracked, oldSsqTracked;    // Tracked sum of squares
   int i;
   double n;
   Iplane img  = o.output;
   bool good   = false;
   
   oldSsqTracked = -50_000;             // clearly invalid value
   for(i=0; i < maxIterations; i++) {
      s.nextIteration();
      if ((i%10)==0) {
         if ((abs(oldSsqTracked - ssqTracked)/cast(float)s.n)<epsilon) {
            writefln("%d iterations to fit circle.", i);
            break;
         }
         oldSsqTracked = ssqTracked;
      }
      //writeln("Circle fit");
   }
   double ss       = s.sumOfSquares();
   n               = cast(double) s.n;
   double miss     = sqrt(ss/n) / s.rt;
   double areaCirc = 3.1415926 * s.rt * s.rt;
   double areaPix  = cast(double) o.spots[spotNum].pixels;
   double ratio    = areaCirc / areaPix;

   // use area of circles vs pixels to find fits that are badly off
   if ((ratio > 1.5) || (ratio < 0.667)) {
      return false;
   }
   if (cast(ulong)miss > (diff(o.spots[spotNum].x1, o.spots[spotNum].x2+
       diff(o.spots[spotNum].y1, o.spots[spotNum].y2)))) {
      return false;
   }

   // now test that goodness of fit is within threshold
   // threshold varies by size with worse fit to circle allowed at small sizes
   //writefln("Miss=%g", miss);
   if ((miss < 0.20) && (s.rt > 5.0)) {
      return true;
   } else if (((miss < 0.20) && (s.rt > 4.0) && (s.rt <= 5.0)) ||
             ((miss < 0.25) && (s.rt > 3.0) && (s.rt <= 4.0)) ||
             (miss < 0.25) && (s.rt == 3.0)) {
      write("d");
      return true;
   } else {
      write("y");
      return false;
   }
   
}

/* *** need to make mandatory calibration value for GFP fluorescence to molecules
   *** and calibration value lipid droplet fluorescence to volume
   *** other additions
   1) Calculate and output volume, radius and surface area of LD
   2) add background correction option
   3) Make possible to write out deleted image, write image with circles marked
*/

void main(string[] args) {
   Iplane   image, gfpimage;
   Parms parms = parseArgs(args);
   global_min_radius = parms.minRadius;
   if ((parms.image == "")||(parms.datafile == "")) {
     writeln("Input or output file missing");
     printUsage();
     exit(1);
   } 
   if (parms.gfpimage == "") {
     writeln("gfpimage missing, lipid drop image present");
     printUsage();
     exit(1);
   }
   if ((parms.calValue <= 0.0)||(parms.pixelSize<=0)) {
     writeln("Absent or invalid calibration value or pixel size.");
     printUsage();
     exit(1);
   } else {
       // parms.calValue is per pixel.  Readjust to be per square micron
       double pixelsMicron = 1 / parms.pixelSize;
       parms.calValue = parms.calValue * (pixelsMicron*pixelsMicron);
   }
   parms.printParms();

   // image should already be background corrected
   image    = readPNM(parms.image);
   gfpimage = readPNM(parms.gfpimage);

   int threshold = parms.thresh;
   if (threshold == -1) {
     threshold = determineThreshold(image);
   } 

   double fraction = parms.fract;     // may be different for composite mode


   // *** threshold and spot image FWHM
   auto spotter     = new OutlineGetter(image, threshold, parms.maxPixels, parms.minPixels, fraction);
   Iplane processed = spotter.kspots();
   Iplane deleted   = processed.blankClone();  // just get size
   auto spotlist    = spotter.spots;
   CircData c[]     = new CircData[spotlist.length];
   SpathSolver s[]  = new SpathSolver[spotlist.length];
   auto name        = image.name;   // not needed now, but useful in batch-processing version
   Iplane scratch   = spotter.scratch;
   bool killed;

   /*** select round spots ***/
   for(int o=1; o<spotter.numSpots; o++) {
      c[o]   = CircData(spotter.calculateOutlineArray(o));
      s[o]   = SpathSolver(c[o]);
      killed = !goodFit(spotter, c[o], s[o], o);
      if (killed) {
         write("k");
         spotter.deleteSpot(deleted, o);
      }
   }

   // Now need to reprocess to renumber the remaining round spots
   spotter.resetData();
   spotter.spot();
   processed        = spotter.output;
   scratch          = spotter.scratch;
   Iplane dscratch  = simpleDialate(scratch,2);   // *** later scale dialation with real space
   spotlist         = spotter.spots;

   // *** analyze tip image (already background corrected)
   

   // ** count tip image, applying spot number image
   // int[] sumThroughMask(Iplane img, Iplane mask, int maxspotnum) 
   int[] gfpsums = sumThroughMask(gfpimage, dscratch, spotlist.length);
   int lastsum;
   for (int i=1; i<gfpsums.length; i++) {
      // if past the last quantiated spot
      if (spotlist[i].x1 == -1) {
         lastsum = i;
         break;
      }
   }

   if (parms.scratch == "") {
      parms.scratch = "sum_tip_scratch.pgm";
   }
   if (parms.scratch != "") {
      Iplane scr   = spotter.scratch;
      writePNM(parms.scratch, scr);
   }

   if (parms.datafile == "") {
     parms.datafile = "sum_tip_default.dat";
   }
   if ((parms.datafile !="")&&(spotlist.length >= 1)) {
      File f = File(parms.datafile, "w");
      string title = spotlist[1].spotTitles(4096) ~ ",GFPsignal,GFPmolecules,Volume,Radius,Area,Molecues/micron\n";
      f.write(title);
      for(int i=1; i<lastsum; i++) {
         string line = spotlist[i].spotDataLine();
         f.write(line);
         
         int molecules = gfpsums[i] / to!int(parms.gfpCal);  // change to floating point?
         real volume =  (cast(real) spotlist[i].sum) / parms.calValue;  
         real radius = (3.0 / (4.0 * PI) * volume) ^^ (1.0/3.0);
         real area   = 4*PI*radius*radius;
         real density= molecules / area;
         f.writef(",%d,%d,%g,%g,%g,%g\n",gfpsums[i], molecules,volume,radius,area, density);
      }
      f.close();
   }

}
