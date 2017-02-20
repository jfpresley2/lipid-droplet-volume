  
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
//import wrapper;

enum Color { uncolored, red, yellow, green, blue };

double global_min_radius = 3.0;           // smallest radius to fit as green

struct Parms {
    string[] calibration;     // calibration image list
    string[] warn;            // saturation warning image list (optional)
    string dataName  = "";    // data files to write
    string imgDat    = "";    // data file with all pixel vals for each spot

    int minPixels    = 6;
    int maxPixels    = 1_000_000;
    int thresh       = -1;
    double fract     = 0.5;                // spot fraction img1 default to FWHM
    double minRadius = 3.0;                // set from global_min_radius

    void printParms() {
       writeln("Calibration image list:");
       foreach(s; calibration) {
          writefln("    %s", s);
       }
       writeln("Saturation warning image list:");
       foreach(s; warn) {
          writefln("    %s", s);
       }
       writefln("Datafile: %s.", dataName);
       writefln("minPixels: %d.", minPixels);
       writefln("maxPixels: %d.", maxPixels);
       writefln("thresh: %d", thresh);
       writefln("fract: %g", fract);
       writefln("minradius: %g", minRadius);
       writeln("--------------------------------------");
       writeln();
    }
}


void bresenhamCircle(Iplane img, int x0, int y0, int r, int fill) {
   if (img.tuple != 1) {
      throw new Exception("drawCircle can't handle multi-tuple images.");
   }
   int xs= img.xsize;
   int x = r;
   int y = 0;
   int offRadius = 1-x;
   while (x>=y) {
      img.setPixel(x+x0, y+y0, fill);
      img.setPixel(x0+y, x+y0, fill);
      img.setPixel(x0-x, y+y0, fill);
      img.setPixel(x0-y, x+y0, fill);
      img.setPixel(y+x0, y0-x, fill); 
      img.setPixel(x0-x, y0-y, fill);
      img.setPixel(x0-y, y0-x, fill);
      img.setPixel(x0+x, y0-y, fill);          

      y++;
      if(offRadius<0) {
        offRadius += 2*y+1;
      } else {
        x--;
        offRadius+=2*(y-x+1);
      }
   }
   return;
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

struct CalibrationResult {
   Iplane cutout;
   string name;            // filename of original image
   int x1, x2, y1, y2;     // location chopped out of image
   real radius;            // fit circle radius
   real volumeFromRadius;  // volume calculated from radius, assumes FWHM cut
   real volumeFromFit;     // left at 0
   SpotInfo spot;          // raw spot info (original image)
   Circle c;               // fit results

   string headerLine() {
     return std.string.format("filename,radius,volumeFromRadius,volumeFromFit,fluorescence,x1,x2,y1,y2,x0,y0\n");     
   }

   string lineForWriting() {
     return std.string.format("%s,%g,%g,-1.0,%g,%d,%d,%d,%d,%g,%g\n", name,
       radius, volumeFromRadius, cast(real) spot.sum, x1,x2,y1,y2, spot.x, spot.y);
   }

   void writeToFile(File f) {
      f.writeln("***");
      f.write(this.headerLine());
      f.write(this.lineForWriting());
      int size = cutout.xsize * cutout.ysize;
      f.writefln("%d %d", cutout.xsize, cutout.ysize);
      for (int i=0; i<size; i++) {
         f.writef("%d ", cutout.img[i]);
      }
      f.writeln("");
   }
}

CalibrationResult[] processCalibrationImage(Iplane img, Iplane warning, int threshold, int minPixels, real fract, real minRadius, out Iplane circles) {
   // kspots image, keep scratch!
   // warning image marks saturated or invalid pixels to not fit, can be null if not needed
   // note that for the moment, not much is done with this data

    auto spotter     = new OutlineGetter(img, threshold, 1_000_000, minPixels, 0.5);
    Iplane processed = spotter.kspots();
    Iplane scratch   = spotter.scratch;
    auto spotList    = spotter.spots;
    auto name        = img.name;        // filename of original image
    int i, j;
    int n            = spotter.numSpots;
    writefln("%d spots isolated.", n);

    // set up output image
    Iplane red, green, blue;
    red   = processed.clone();
    green = processed.clone();
    blue  = processed.clone();

    SpathSolver s;
    CircData c;
    CalibrationResult[] list;
    CalibrationResult spotResult;

    for(i=1; i<n; i++) {
      SpotInfo spot = spotList[i];
      auto edgemap  = spotter.calculateOutlineArray(i);
      c = CircData(edgemap);
      s = SpathSolver(c);
      for (j=0; j<100; j++) {
          s.nextIteration();
          // later throw in termination condition
      }
      double ss = cast(double) s.sumOfSquares();
      double nn = cast(double) s.n;
      double miss = sqrt(ss/n) / cast(double) s.rt;
      double areaCirc = 3.1415926 * s.rt * s.rt;
      double areaPix  = cast(double) spot.pixels;
      double ratio    = areaCirc / areaPix;
      // no good if area in pixels too different from area fit circle
      if ((ratio > 1.5) || (ratio < 0.667)) {
         continue;
      }
      // if deviation from fit acceptable, keep spot
      // writefln("global_min_radius == %g", global_min_radius);
      //writefln("miss = %g;  s.rt = %g", miss, s.rt);
      if ((miss < 0.1)&&(s.rt > global_min_radius)) {
         spotResult = CalibrationResult();
         //*** fill in fields here
         spotResult.x1   = spot.x1;
         spotResult.x2   = spot.x2;
         spotResult.y1   = spot.y1;
         spotResult.y2   = spot.y2;
         spotResult.spot = spot;
         spotResult.c    = s.solvedCircle(); // what happens to names if I do different solver?
         spotResult.name = name;             // original image filename for the record
         // must calculate radius from circle fit
         // this must take into account the FWHM clip
         const FWHMradiusConversion = 1.0 / sqrt(0.75);
         spotResult.radius          = spotResult.c.r*FWHMradiusConversion; 
         spotResult.volumeFromRadius  = 4.0/3.0*3.1415926* spotResult.radius^^3;
         //*** copy selected ones to output image or draw circles
         bresenhamCircle(green, cast(int) (floor(spot.x)+0.5), cast(int) (floor(spot.y)+0.5),
                         cast(int) (floor(spotResult.c.r+0.5)), img.maxval);             
         spotResult.cutout = sliceout(img, scratch, i, spot.x1, spot.x2, spot.y1, spot.y2);
         if (warning !is null) {
            Iplane test = sliceout(warning, scratch, i, spot.x1, spot.x2, spot.y1, spot.y2);
            foreach (int a, int pixel; test.img) {
               if (pixel != 0) {    // pixel invalid for fit purposes, flag
                  spotResult.cutout.img[a] = -1;     // *** -1 may be better so nex prog knows
               }
            }
         }
         list ~= spotResult;
      } else {
         continue;
      }
    }

   // circletest potential calibration spots
   Iplane[] colors = [red, green, blue];
   circles = compact(colors);
   return list;
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
    writeln("calibrate_volume --cal img1.pgm img2.pgm img3.pgm --data datafile.dat --imgdat spotcutouts.dat [--warn img1_sat.pgm img2_sat.pgm img3_sat.pgm --thresh -1 fract 0.5 --minradius 3.0 ]");
}

Parms parseArgs(string[] args) {
   Parms p;
   p.calibration  = [];
   p.warn         = [];
   bool calHit, warnHit, inRun;
   calHit = inRun = warnHit = false;
   string lastSwitch = "";
   string[] newArgs = [];
   if (args.length > 0) {
     foreach (string a; args) {
        if (!inRun) {
           if (a == "--cal") {
              inRun = calHit = true;
              lastSwitch = a;
           } else if (a == "--warn") {
              inRun = warnHit = true;
              lastSwitch = a;
           } else {
             newArgs ~= a;
           }
        } else {     // inRun
          if ((a.length >= 2) && (a[0..2]=="--")) {
             if (a == "--cal") {
               calHit   = true;
               warnHit = false;
               lastSwitch = a;
             } else if (a == "--warn") {
               warnHit = true;
               calHit   = false;
               lastSwitch = a;
             } else {
               inRun = false;
               newArgs ~= a;
             }
          } else {
            if (calHit) {
              p.calibration ~= a;
            }
            if (warnHit) {
              p.warn ~= a;
            }
          }
        }
     }
   }  
   try {
     getopt(newArgs, 
        "minPixels", &p.minPixels,
        "maxPixels", &p.maxPixels,
        "thresh", &p.thresh,
        "fract", &p.fract,
        "data", &p.dataName,
        "imgdat", &p.imgDat,
        "minradius", &p.minRadius,
     );
   } catch (Exception e) {
     printUsage();
     writeln("Program exiting.");
     exit(1);
   } 
   return p;
}


// *** note that saturation warn images must be in the SAME order as the calibration images
// *** This is the user's responsibility.  No way to change that, but there should
// *** be some warning text whenever this option is used.
// *** Saturation warning images have NOT been tested or used yet.  Beware.  Prepare to write
// *** code and do tests if you need them as input.

void main(string[] args) {
   Iplane[] calImgs = [];
   Iplane[] warnImgs = [];
   string[] namelist = [];
   // volume --cal img1.pgm img2.pgm img3.pgm --files file1 file2 file3 --output report.txt
   Parms parms = parseArgs(args);
   parms.printParms();
   global_min_radius = parms.minRadius;
   // now load calibration list
   if (parms.calibration.length < 1) {
      writeln("No calibration images.  Cannot proceed.");
      printUsage();
      exit(1);
   }
   if (parms.warn.length == 0) {
      parms.warn = null;
   } else if (parms.warn.length != parms.calibration.length) {
      writeln("Number of saturation warning images different from number of calibration images.");
      writeln("Cannot proceed.");
      printUsage();
      exit(1);
   }
   // *** probably a good idea also to test if all calibration images, warning images
   // *** are the same size and same number channels
   if ((parms.dataName == "") || (parms.imgDat == "")) {
      writeln("Must specify --data filename.dat and --imgdat img.dat");
      writeln("   otherwise, there is nothing for analysis program to report.");
      writeln("Cannot proceed.");
      printUsage();
      exit(1);
   }
   foreach(int n, string filename; parms.calibration) {
      Iplane i, w;
      try {
        i = readPNM(filename);
        i.name = filename;          // make sure filename is stored with image for later
        if (parms.warn !is null) {
           w = readPNM(parms.warn[n]);
           warnImgs ~= w;
        }
        calImgs  ~= i;
        namelist ~= filename;
      } catch (Exception e) {
        writefln("Loading of calibration image <%s> failed.  File not pnm or may not exist", filename);
       continue;
      }
   }
   // verify there is at least one loaded image
   if (calImgs.length < 1) {
      writeln("No calibration images. Loading failed.  Cannot proceed.");
      exit(1);
   }
   // *** need to test whether number actually loaded calibration images
   // *** is the same as warning images, if warning images are used

   // ------ now process calibration images ------
   CalibrationResult[] calDroplets = [];
   CalibrationResult[] currentImageResults;
   Iplane coloredCircles;
   int counter=0;              // *** this is to quickly see all calibration images
   foreach(int n, img; calImgs) {
      int thresh = parms.thresh;
      if (thresh == -1) {
         thresh = determineThreshold(img);
      }
     
      // note that marking of saturated pixels is not helpful at this point.  It was there when
      // we were still considering fitting all the pixels in the spot and not just the boundary
      // pixels.  In this case, we would have tested omitting saturated pixels from the fit. So
      // parameter is still there, but for the moment does nothing.
      
      if (parms.warn is null) {
         currentImageResults = processCalibrationImage(img, null, thresh, parms.minPixels,
            parms.fract, 0.0, coloredCircles);
      }
      else {
          currentImageResults = processCalibrationImage(img, warnImgs[n], thresh, 
             parms.minPixels, parms.fract, 0.0, coloredCircles);
      } 
      writeln("A calibration image processed.");
      // using name in image to include image filename in image 
      calDroplets ~= currentImageResults;
      string current_name = namelist[counter];
      string name = std.string.format("color_%s", current_name); 
      // here substitute ppm for pgm at end if there
      writePNM(name, coloredCircles);
      counter += 1;
   }
   if (calDroplets.length == 0) {
      writeln("No calibration droplets.  Cannot proceed.");
      exit(1);
   } else {
      File f  = File(parms.dataName, "w");
      File f2 = File(parms.imgDat, "w");
      f.write(calDroplets[0].headerLine);
      foreach (d; calDroplets) {
        f.write(d.lineForWriting);
        d.writeToFile(f2);
      }
      f.close();      // try block later
      f2.close();
   }


} 
