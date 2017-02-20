
target: calibrate_volume project sum_volume sqrt_img sum_cells scaled sum_PAT 

sum_cells: sum_cells.d image.d medianLib.d perimeter.d
	dmd sum_cells.d perimeter.d image.d medianLib.d -ofsum_cells #-O -inline -release

sum_PAT: sum_PAT.d dialate.d image.d convolve.d circleFit.d spots.d watershedLib.d
	dmd sum_PAT.d image.d dialate.d circleFit.d convolve.d watershedLib.d spots.d -L/usr/local/lib/libgsl.a -L/usr/local/lib/libgslcblas.a -Lwrapper.a -ofsum_PAT #-inline -release -O

sqrt_img: sqrt_img.d image.d
	dmd image.d sqrt_img.d -ofsqrt_img

scaled: scaled.d image.d
	dmd image.d scaled.d -ofscaled

sum_volume: sum_volume.d dialate.d convolve.d circleFit.d spots.d watershedLib.d
	dmd sum_volume.d image.d dialate.d circleFit.d convolve.d watershedLib.d spots.d -L/usr/local/lib/libgsl.a -L/usr/local/lib/libgslcblas.a -Lwrapper.a -ofsum_volume #-inline -release -O

calibrate_volume: image.d convolve.d circleFit.d spots.d watershedLib.d calibrate_volume.d
	dmd calibrate_volume.d image.d circleFit.d convolve.d watershedLib.d spots.d  -L/usr/local/lib/libgsl.a -L/usr/local/lib/libgslcblas.a -Lwrapper.a -ofcalibrate_volume #-inline -release -O

project: image.d medianLib.d project.d
	dmd image.d medianLib.d project.d -ofproject -O -inline -release

wrapper.a: wrapper.c
	gcc -Wall -c wrapper.c -o wrapper.o
	echo "wrapper compiled"
	gcc -shared wrapper.o -lgsl -lgslcblas -lm -o wrapper.a

#install: calibrate_volume project
#	cp calibrate_volume ~/bin
#	cp project ~/bin
#	cp sum_volume ~/bin
#	cp sum_PAT ~/bin
#	cp sum_cells ~/bin
#	cp perimeter_test ~/bin
#	cp draw_cells ~/bin
#	cp sqrt_img ~/bin