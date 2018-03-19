/*
** Copyright (C) 2007-2009 Erik de Castro Lopo <erikd@mega-nerd.com>
**
** This program is free software: you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation, either version 2 or version 3 of the
** License.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sndfile.h>

#define ARRAY_LEN(x)	((int) (sizeof (x) / sizeof (x [0])))
#define MAX(x,y)		((x) > (y) ? (x) : (y))
#define MIN(x,y)		((x) < (y) ? (x) : (y))

#define THRES	0.7

void usage_exit (void);
double calc_ch_corr(double* data, int n);

int main (int argc, char ** argv)
{
	SNDFILE *infile ;
	SF_INFO sfinfo ;
	
	double corr = 1.0;

	if (argc != 2)
		usage_exit () ;

	memset ((void*)&sfinfo, 0, sizeof (sfinfo)) ;
	if ((infile = sf_open (argv[1], SFM_READ, &sfinfo)) == NULL) {
		fprintf(stderr, "Error : Not able to open input file '%s'\n", argv [argc - 2]) ;
		sf_close (infile) ;
		exit (-1) ;
	} ;

	if (sfinfo.channels == 2) {
		double *data = (double *)malloc(sizeof(double)*sfinfo.frames*sfinfo.channels);
		sf_count_t rf = sf_readf_double(infile, data, sfinfo.frames);
		corr = calc_ch_corr(data, rf);
#ifdef DEBUG
		fprintf(stderr, "Read %ld frames, channel-correlation = %5.4f\n", rf, corr);
#endif
	}
#ifdef DEBUG
	else 
		fprintf(stderr, "Input file is mono\n");
#endif

	sf_close (infile);
	return corr<=THRES ? 2 : 1;
} /* main */


double 
calc_ch_corr(double* data, int n)
{
	double sumX = 0;
	double sumX2 = 0;
	double sumY = 0;
	double sumY2 = 0;
	double sumXY = 0;
	int i;
	
	for (i = 0; i < n; ++i) {
	  double x = data[2*i];
	  double y = data[2*i + 1];

	  sumX += x;
	  sumX2 += x * x;
	  sumY += y;
	  sumY2 += y * y;
	  sumXY += x * y;
	}

	double stdX = sqrt(sumX2 / n - sumX * sumX / n / n);
	double stdY = sqrt(sumY2 / n - sumY * sumY / n / n);
	double covariance = (sumXY / n - sumX * sumY / n / n);

	return covariance / stdX / stdY; 
}

void usage_exit()
{
	fputs ("\n"
		"Usage :\n\n"
		"    sndfile-mix-to-mono <input file>\n"
#ifdef DEBUG
		"    <<DEBUG-VER>>\n"
#endif
		, stderr) ;
	exit (0) ;
} /* usage_exit */
