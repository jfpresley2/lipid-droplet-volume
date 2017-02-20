// *** pixelSize needs to be checked and made mandatory parameter
// *** It also needs to be in the documentation!!!
  
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
    string image = "";                      // input image name
    string datafile = "dat.dat";            // name for output file to write to
    string marginfile = "marginfile.dat";   // output file with margin adjustment
    string mode = "fwhm";                   // fwhm/basic/composite
 
    int minPixels    = 6;
    int maxPixels    = 1_000_000;
    int thresh       = -1;
    double calValue  = -1.0;               // make sure default value invalid
    double fract     = 0.5;                // spot fraction img1 default to FWHM
    double minRadius = 3.0;                // set from global_min_radius
    double pixelSize = 0.1;                // pixel size in microns

    void printParms() {
       writefln("Image: %s.", image);
       writefln("Datafile: %s.", datafile);
       writefln("Marginfile: %s.", marginfile);
       writefln("Mode(fwhm|basic|composite)=%s.", mode);
       writefln("minPixels: %d.", minPixels);
       writefln("maxPixels: %d.", maxPixels);
       writefln("calValue: %g.", calValue);
       writefln("thresh: %d", thresh);
       writefln("fract: %g", fract);
       writefln("minradius: %g", minRadius);
       writefln("pixelSize: %g", pixelSize);
       writeln("--------------------------------------");
       writeln();
    }
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
   return (max / 10);
}


void printUsage() {
    writeln("sum_volume --calValue 322.2 --image image.pgm --data datafile.dat --pixelSize 0.1 [--margin marginfile.dat --thresh -1 --fract 0.5 --minradius 3.0 --mode fwhm ]");
}

Parms parseArgs(string[] args) {
   Parms p;
   try {
     getopt(args, 
        "mode", &p.mode,
        "calValue", &p.calValue,
        "image", &p.image,
        "minPixels", &p.minPixels,
        "maxPixels", &p.maxPixels,
        "thresh", &p.thresh,
        "fract", &p.fract,
        "data", &p.datafile,
        "marginfile", &p.marginfile,
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

void main(string[] args) {
   Iplane   image;
   Parms parms = parseArgs(args);
   global_min_radius = parms.minRadius;
   if ((parms.image == "")||(parms.datafile == "")) {
     writeln("Input or output file missing");
     printUsage();
     exit(1);
   } 
   if (parms.calValue < 0.0) {
     writeln("Absent or invalid calibration value.");
     printUsage();
     exit(1);
   }
   parms.printParms();

   // image should already be background corrected
   image = readPNM(parms.image);

   int threshold = parms.thresh;
   if (threshold == -1) {
     threshold = determineThreshold(image);
   } 

   double fraction = parms.fract;     // may be different for composite mode
   

   // *** threshold and spot image FWHM
   auto spotter     = new OutlineGetter(image, threshold, parms.maxPixels, parms.minPixels, fraction);
   Iplane processed = spotter.kspots();
   auto spotlist    = spotter.spots;
   auto name        = image.name;   // not needed now, but useful in batch-processing version

   double volumeSum   = 0.0;
   // open output file, log file, write title lines into them
   File outfile = File(parms.datafile,"w");
   //File logfile = new File("logfile.txt", "a");
   outfile.writeln(spotlist[0].spotTitles(image.maxval) ~ ",volume");

   /*
    * Spot fluorescence is in unknown units per pixel (we can call it fluors/pixel).  
    * We don't really care what the units are, but we need to give the output in
    * fluors / cubic micron so we need to calculate the conversion.
    *   Assuming 0.1 microns / pixel and remember we are looking at projections 
    *   of spherical structures.
    *   Thus, a calibration value of 341 fluors/pixel implies 
    *   341 / pixel**3. or 341*(pixel**3) cubic microns or 341,000 fluors / micron**3 
    *
    *
    */

   int counter = -1;
   parms.calValue = parms.calValue / 0.875;   // *** puts back fluorescence trimmed in initial program
   foreach(SpotInfo spot; spotlist) {
     if (spot.spotNo < 0) {
       if (++counter > 0) {
         break;
       }
     }
     if (spot.spotNo <= 0) {
        continue;             // First one is always empty.
     }
   
     // *** very careful about units here. calibration is currently fluorescence/ cubic_pixels
     // *** but user might be thinking in fluorescence cubic micron.  All needs to be coherent and clear to user 
     // *** how to do the calibration,and what units to input

     double volume = spot.sum  / (parms.calValue * pow(1.0/parms.pixelSize,3.0));   
     //volume        = volume / 0.86948;                                           
     volumeSum    += volume;
     string line = std.string.format("%s,%g", spot.spotDataLine(), volume);
     outfile.writeln(line);  
   }
   writefln("Total volume of all spots is %g.", volumeSum);
//dBundle dialateWithSpots(SpotInfo[] s, iPlane original, iPlane scratch, double calibrationFactor, double micronsPerPixel)
   dBundle marginData = dialateWithSpots(spotlist, spotter.img, spotter.scratch, parms.calValue * pow(1.0/parms.pixelSize,3.0), parms.pixelSize);
   auto marginFile = File(parms.marginfile,"w");
   auto marginLength = marginData.length();
   marginFile.writeln(marginData.header);
   for (int i=1; i<marginLength; i++) {
      marginFile.writeln(marginData.printLine(i));
   }
   outfile.close();
   //logfile.close();
}
