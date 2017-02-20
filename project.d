import std.stdio;
import std.c.stdlib;
import std.string;
import std.conv;
import std.getopt;
import std.file;
import image;
import medianLib;
   
string makeName(string root, string extension, int i, int digits) {
   string fmt = "%s%0" ~ std.string.format("%d",digits) ~ "d.%s";
   return std.string.format(fmt, root, i, extension);
}

// *** There's a bug in the median filter routine that leaves high values for edge pixels
// *** It's worse when the image is subsampled and re-expanded.  For the moment, we're
// *** not subsampling, and we set the edge pixels to zero to make sure

void killBorders(ref Iplane i) {
   int x, y, n;
   int xs = i.xsize;
   int ys = i.ysize;
   // kill top, bottom
   for (n=0; n<xs; n++) {
     // top
     i.img[n] = 0;
     i.img[n+xs] = 0;
     // bottom
     i.img[n+xs*(ys-1)] = 0;
     i.img[n+xs*(ys-2)] = 0;
   }
   // kill left, right
   for (n=0; n<ys; n++) {
     // left
     i.img[xs*n] = 0;
     i.img[xs*n + 1] = 0;
     // right
     i.img[xs*n + ys - 1] = 0;
     i.img[xs*n + ys - 2] = 0;
   }

}

int findLimit(string root, string extension, int first, int digits) {
   int i = first - 1;
   while (true) {
      string name = makeName(root, extension, ++i, digits);
      //writefln("File found =  %s", name);
      if (!std.file.exists(name)) { 
        i--;
        break; 
      }
   }
   return i;
}

int findHistPeak(Iplane img) {
   int i, n, max, peakval, peak;
   int[] hist;
   n   = cast(int) img.img.length;
   max = peakval = peak = 0;
   for (i=0; i<n; i++) {
     max = (max > img.img[i] ? max : img.img[i]); 
   }
   hist = new int[max+1];
   for (i=0; i<n; i++) {
     ++hist[img.img[i]];
   }
   for (i=0; i<(max); i++) {
     if (hist[i] > peakval) {
        peak    = i;
        peakval = hist[i];
     } 
   }
   return peak;
}

Iplane bkgdCorrectHistPeak(Iplane img) {
   int i;
   int bkg = findHistPeak(img);
   writefln("Hist peak is: %d", bkg); 
   for (i=0; i<img.img.length; i++) {
      img.img[i] = img.img[i] - bkg;
      img.img[i] = (img.img[i] < 0 ? 0 : img.img[i]);
   }
   return img;
}

/* 
    Parms has some defaults set that can be overriden from command line.
    These can be edited easily if you prefer different defaults.

 */

struct Parms {          
  string root;
  int first = 0;
  int last = -1;
  int digits = 3;
  string extension;
  string outputfile;  
  int neighborhood = 120; 
  bool mode     = false;    // background correct by subtracting histogram peak everywhere
  bool nomedian = false;
  int normalize = -1;       // don't normalize images unless specifically requested
  int satval = -1;          // must specify saturation value if you want warning image
  string warn = "";         // empty if you don't want warning, otherwise must specify name
}

// *** Right now, median filter can't be turned off.  Change that.
// *** Also, non-median percentiles should be usable.

void main(string[] args) {
   Parms parms;
   bool warnSat;
   bool satImageMade = false;
   int limit;
   Iplane[] accums;
   Iplane saturationImage;
   getopt(args,
      "root", &parms.root,
      "first", &parms.first,
      "last", &parms.last,
      "digits", &parms.digits,
      "extension", &parms.extension,
      "outputfile", &parms.outputfile,
      "neighborhood", &parms.neighborhood,
      "mode", &parms.mode,
      "nomedian", &parms.nomedian,
      "normalize", &parms.normalize,
      "saturation", &parms.satval,       // value of saturated pixel to warn
      "warnimg", &parms.warn,
   );
   if ((parms.root == "") || (parms.outputfile == "")) {
     writeln("Usage: project --root root [--first 0 --last 12 --digits 3 --nomedian --mode ] --extension ppm --neighborhood 120 --outputfile projected.pgm --saturation 65535 --warnimg saturation.pgm");
     writeln("No args, program terminating.");
     exit(1);
   }
   if ((parms.warn == "")||(parms.satval <= 0)) {
     warnSat = false;
   } else {
     warnSat = true;
   }
   string root  = parms.root;
   if (parms.last > 0) {
     limit = parms.last;
   } else {
     limit = findLimit(parms.root, parms.extension, parms.first, parms.digits); 
   }
   if (parms.neighborhood <= 1) {
     parms.nomedian = true;
   }
   string ext   = parms.extension;
   string proj  = parms.outputfile;
   bool done    = false;
   int i;
   Iplane accum;
   for (i=0; i<limit; i++) {
     string name = makeName(root, ext, i, parms.digits);
     writeln(name);
     Iplane temp    = readPNM(name);
     Iplane[] tlist = temp.explode();
     // *** if Iplane list is empty, throw and handle exception
     // *** while at it, consider what explode does when Iplane empty
     // *** also, all images should be the same dimensions (x,y).  This should
     // *** be tested, and reasonable solution if one fails
     if (warnSat && (!satImageMade)) {
        saturationImage = tlist[0].blankClone();
        satImageMade = true;
     }
     if (!parms.nomedian) {
        foreach (ref t; tlist) {        // *** move this snippet of code upwards
            if (warnSat) {
               for(int j=0; j< saturationImage.img.length; j++) {
                  if (t.img[j] >= parms.satval) {
                     saturationImage.img[j] = 1;       // mark pixel as saturated
                  }
               }
            }
            auto filt   = new MedianFilter(t, parms.neighborhood, 50);
            filt.ssMedian(1);
            t           = filt.doSub();
            killBorders(t);          // bug leaves values for borders, fix later
         }
     } else if (parms.mode) {
//Iplane bkgdCorrectHistPeak(Iplane i) {
       foreach (ref t; tlist) {            // ***needs to check saturation put earlier
          Iplane t2 = bkgdCorrectHistPeak(t);
          t = t2;
       }
     }
     temp = compact(tlist);
     if (i==0) {
       accum = temp.clone();
     } else {
       if (   (accum.xsize != temp.xsize)
           || (accum.ysize != temp.ysize) 
           || (accum.tuple != temp.tuple))  {
          throw new Exception("Image sizes don't match.  Projection failed.");
       }
       accum.img[] += temp.img[];
     }

   }
   int maxPixel = accum.maxPixel();
   accums = accum.explode();
   int counter = 0;
   foreach(ref Iplane a; accums) {
        if (!parms.nomedian) {
         auto filt = new MedianFilter(a, parms.neighborhood, 50);
         filt.ssMedian(1);
	 a         = filt.doSub(); 
         killBorders(a);
       }
       if (parms.normalize < 0) {
         ;
       } else {
         a = a.renormalize(parms.normalize);
       }
   }
   accum = compact(accums);
 
   writePNM(proj, accum);
   if (warnSat) {
      writePNM(parms.warn, saturationImage);
   }
   writeln(proj);
}