import std.stdio;
import std.string;
import std.math;
import image;
import spots;

// produces a dialated set of scratch images which can be used to put a graded border on spots
// This is really specialized for the particular use of calculating an edge correction for 
// volume calculation procedure.  This is NOT a simple general-purpose dialate.
// A general-purpose dialate is included as "simpleDialate", but names should really
// be switched around.
// After writing this, there's a lot of unneeded unit switching.  Best to keep 
// everything here in units of pixels and leave the caller to figure out microns, 
// but for now that's not the way it's done.
// Fix in revision.

bool allzeros(int first, int second, int third) {
  if ((first==0)&&(second==0)&&(third==0)) {
    return true;
  } else {
    return false;
  }
}

int test4solo(int up, int down, int left, int right) {
  if ((up != 0) && (allzeros(down,left,right))) {
     return up;
  }
  if ((down != 0) && (allzeros(up,left,right))) {
     return down;
  }
  if ((left != 0) && (allzeros(up,down,right))) {
     return left;
  }
  if ((right != 0) && (allzeros(up,down,left))) {
     return right;
  }
  return 0;
}

int environ(Iplane img, int xsize, int ysize, int x, int y) {
  // uses 4-connectivity for now, I have to think about how to handle anything more complicated
  int up, down, left, right;
  int answer;
  up = down = left = right = 0;
  if (y > 0)         up   = img.img[xsize*(y-1)+x];
  if (y < (ysize-2)) down = img.img[xsize*(y+1)+x];
  if (x > 0)         left = img.img[xsize*y+x-1];
  if (x < (xsize-2)) right= img.img[xsize*y+x+1];
  // trivial case, nothing interesting
  if ((up == 0) && (down == 0) && (left == 0) && (right == 0)) {
    return 0;
  }
  answer = test4solo(up,down,left,right);
  if (answer != 0) {
    return answer;
  }
  // if three are equal, problem solved, majority wins
  // ignore right
  if ((up == down) && (down == left)) {
    return up;
  }
  // ignore left
  if ((up == down) && (down == right)) {
    return up;
  }
  // ignore up
  if ((down == left) && (left == right)) {
    return down;
  }
  // ignore down
  if ((up == left) && (left == right)) {
    return up;
  }
  // if two are equal, have to make sure the other two are not equal
  // otherwise tiebreaker, for the moment up > down, left > right, up > left or right
  // this puts in a one-pixel skew, which maybe there is a clever solution to, but
  // still good enough for guvment work
  // note that three of a kind already ruled out
  if ((up == down) && (left != right)) {
     return up;
  } else if ((up == down) && (left == right)) {
     return up;
  } else if ((up == left) && (down != right)) {
     return up;
  } else if ((up == left) && (down == right)) {
     return up;
  } else if ((up == right) && (down != left)) {
     return up;
  } else if ((up == right) && (down == left)) {
     return up;
  } else if (left == right) {
     return left;
  } else if (left == down) {
     return down;
  } else if (down == right) {
     return down;
  }
  // if none are equal, return the first non-zero one in the tiebreaker sequence
  if (up != 0) return up;
  if (down != 0) return down;
  if (left != 0) return left;
  if (right != 0) return right;
  return 0;                        // shouldn't come here so long as test4solo works properly
}

// simpleDialate1 is a basic general-purpose dilation (note that dialate1 and dialate are
//  ***special purpose *** and only useful for a particular correction of volume 
//  measurements).  simpleDialate runs simpleDialate1 for however many rounds needed

void simpleDialate1(ref Iplane scratch) {
  int i;
  Iplane oldScratch = scratch.clone();  
  for (i=0; i<scratch.img.length; i++) {
    if (scratch.img[i] != 0) {
      continue;                  // pixel already accounted for
    }
    int y = i / scratch.xsize;
    int x = i % scratch.xsize;
    scratch.img[i]       = environ(oldScratch, scratch.xsize, scratch.ysize, x, y);
  }
}

Iplane simpleDialate(Iplane scratch, int rounds) {
  int i;
  Iplane cpyScr   = scratch.clone();
  for(i=0; i<=rounds; i++) {
    simpleDialate1(cpyScr);
  }
  return cpyScr;
}

void dialate1(ref Iplane scratch, ref Iplane count_scratch, int counter) {
  int i;
  Iplane oldScratch = scratch.clone();  
  for (i=0; i<scratch.img.length; i++) {
    if (scratch.img[i] != 0) {
      continue;                  // pixel already accounted for
    }
    int y = i / scratch.xsize;
    int x = i % scratch.xsize;
    scratch.img[i]       = environ(oldScratch, scratch.xsize, scratch.ysize, x, y);
    count_scratch.img[i] = counter;
  }
}

Iplane[] dialate(Iplane scratch, int rounds) {
  int i;
  Iplane cpyScr   = scratch.clone();
  Iplane countImg = scratch.clone();
  for(i=0; i<countImg.img.length; i++) {
    if (countImg.img[i] != 0) {
      countImg.img[i] = -1;
    }
  }
  for(i=0; i<=rounds; i++) {
    dialate1(cpyScr, countImg, i);
  }
  return [cpyScr, countImg];
}

double calculateThickness(double calibrationFactor, double micronsPixel, SpotInfo spot) {
  double cubicMicrons = spot.sum / calibrationFactor;
  double area         = spot.pixels * (micronsPixel*micronsPixel);
  return cubicMicrons/area;
}

int calculateEdge(ref double[] edgeGradient, double thickness, double micronsPixel, SpotInfo spot) {
  int i = 0;
  double pos = 0.0;
  double radius = thickness * 1.57079;         // just assume spheres with average thickness of thickness
  double radiusPixels = radius / micronsPixel;
  double radSquared   = radiusPixels * radiusPixels;
  pos = radiusPixels * sqrt(0.75);    // edge is fwhm
  double z;
  do { 
    pos += 1.0;
    i++;
    double place = radSquared - pos * pos;
    if (place < 0.0) break;
    z = sqrt(place);
    edgeGradient ~= z;
  } while (pos < radiusPixels);
    return i;
}

struct dBundle {
  Iplane oldScratch, newScratch, countScratch;
  SpotInfo[] spots;             // parallel arrays
  double[] spotThickness;
  double[] newFluorescence;

  int length() {
    return cast(int) spots.length;
  }

  string header() {
    if (spots.length < 1) 
       throw new Exception("dBundle has no spots");
    return spots[0].spotTitles(4095) ~ ",thickness,margin_fluorescence";
  }

  string printLine(int i) {
    string line = std.string.format("%s,%g,%g",spots[i].spotDataLine(),
       spotThickness[i], newFluorescence[i]);
    return line;
  }
}

dBundle dialateWithSpots(SpotInfo[] s, Iplane original, Iplane scratch, double calibrationFactor, double micronsPerPixel) {
  dBundle answer;
  int i, x, y, maxRounds;
  double[] spotThickness = new double[s.length+1];
  int[] spotEdge      = new int[s.length+1];
  double[][] edgeGradients  = new double[][s.length+1];
  double[] newFluorescence  = new double[s.length+1];
  foreach(ref f; newFluorescence) {
     f = 0.0;
  }
  foreach(ref double[] gr; edgeGradients) {
    gr = [];
  }
  maxRounds = 0;
  foreach(int n, SpotInfo spot; s) {
    spotThickness[n] = calculateThickness(calibrationFactor, micronsPerPixel, spot);
    spotEdge[n]      = calculateEdge(edgeGradients[n], spotThickness[n], micronsPerPixel, spot);
    if (maxRounds < spotEdge[i]) maxRounds = spotEdge[n];
  }
  // go through
  Iplane[] newScratch = dialate(scratch, maxRounds);  // dialate through maximum number of rounds, not used for many 
  // iterate through iplane to add the extra edge to each spot
  writeln("all rounds dialate done");
  for (i=0; i < newScratch[0].img.length; i++) {
    int pixel = newScratch[0].img[i];
    int code  = newScratch[1].img[i];
    if ((pixel == 0)||(code<1)) continue;
    if (code >= edgeGradients[pixel].length) continue;
    newFluorescence[pixel] += edgeGradients[pixel][code];
  }  
  answer.oldScratch     = scratch;
  answer.newScratch     = newScratch[0];
  answer.countScratch   = newScratch[1];
  answer.spots          = s;
  answer.spotThickness  = spotThickness;
  answer.newFluorescence= newFluorescence;
  return answer;
}

