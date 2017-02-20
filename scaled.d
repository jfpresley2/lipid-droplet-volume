  
import std.stdio;
import std.c.stdlib;
import std.string;
import std.math;
import std.getopt;
import std.conv;
import image;

struct Parms {
    string image = "";             // input image name (already background corrected)
    string imgOut = "";
    int maxval   = 255;         
    bool sqrt = false;             // apply square root lut after done
    
    void printParms() {
       writefln("Image: %s.", image);
       writefln("Output Image: %s.", imgOut);
       writefln("maxval to scale to: %d.", maxval);
       if (sqrt) {
         writeln("Will apply square root modification.");
       } else {
         writeln("Will represent brightness linearly.");
       }
       writeln("--------------------------------------");
       writeln();
    }
}

int determineMax(Iplane img) {
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


int determineMin(Iplane img) {
   // works for single channel images only
   if (img.tuple != 1) {
      throw new Exception("determineThreshold does not work for multi-channel images.");
   }
   int min = img.maxval;
   int i;
   for (i=0; i < img.img.length; i++) {
       min = (min > img.img[i] ? img.img[i] : min);
   }
   writefln("Min is %d.", min);
   return min;
}


void printUsage() {
    writeln("scaled --image image.pgm --imgOut output.pgm [ --maxval 255 ]");
}

Parms parseArgs(string[] args) {
   Parms p;
   try {
     getopt(args, 
        "imgOut", &p.imgOut,
        "maxval", &p.maxval,
        "sqrt", &p.sqrt,
        "image", &p.image,
     );
   } catch (Exception e) {
     printUsage();
     writeln("Program exiting.");
     exit(1);
   } 
   return p;
}

// This should only be used on one-plane images (each color could have different 
// maximum values).

Iplane sqrtScale(Iplane image, int maxval, int actual_max) {
   int i;
   Iplane outPlane = image.blankClone();
   double dmax  = cast(double) maxval;
   double damax = cast(double) actual_max;
   damax        = sqrt(damax);
   for (i=0; i<image.img.length; i++) {
      double pixel    = cast(double) image.img[i];
      pixel           = sqrt(pixel);
      pixel           = dmax * (pixel / damax);  // rescale
      outPlane.img[i] = cast(int) floor(pixel + 0.5);
      if (outPlane.img[i] > maxval) outPlane.img[i] = maxval;
   }
   outPlane.maxval = maxval;
   return outPlane;
}

Iplane scale(Iplane image, int maxval, int actual_max, int actual_min) {
   int i;
   Iplane outPlane = image.blankClone();
   double dmax     = cast(double) maxval;
   double damax    = cast(double) actual_max;
   double damin    = cast(double) actual_min;
   damax          -= damin;
   for (i=0; i<image.img.length; i++) {
       double pixel = cast(double) image.img[i];
       pixel        = dmax * ((pixel - damin)/damax);
       outPlane.img[i] = cast(int) floor(pixel + 0.5);
       if (outPlane.img[i] > maxval) outPlane.img[i] = maxval;
   }
   outPlane.maxval = maxval;
   return outPlane;
}

void main(string[] args) {
   Iplane   image, outputImage;
   Parms parms = parseArgs(args);
   if ((parms.image == "")||(parms.imgOut == "")) {
     writeln("Input or output file missing");
     printUsage();
     exit(1);
   } 
   if (parms.maxval < 0) {
     writeln("Maximum allowed value cannot be negative.  Default is 255 if not actively set.");
     printUsage();
     exit(1);
   }
   parms.printParms();

   image       = readPNM(parms.image);
   int max     = determineMax(image);
   int min     = determineMin(image);
   if (parms.sqrt) {
      writeln("Applying sqrt lut.");
      outputImage = sqrtScale(image, parms.maxval, max);   // doesn't yet take min into account
   } else {
      writeln("Applying linear lut.");
      writefln("Min value is %d", min);
      outputImage = scale(image, parms.maxval, max, min);
   }
   
   outputImage.maxval = parms.maxval;
   writePNM(parms.imgOut, outputImage);
}
