/***************************************************************************************
*                                                                                      *
*                                     Deformetrica                                     *
*                                                                                      *
*    Copyright Inria and the University of Utah.  All rights reserved. This file is    *
*    distributed under the terms of the MIT License. This file is also distributed     *
*    under the terms of the Inria Non-Commercial License Agreement.                    *
*                                                                                      *
*                                                                                      *
****************************************************************************************/

// This file contains Cuda functions doing the same computations as in GpuConv1D.cu. The computations 
// are performed in a different way and use a 2 dimensional computations grid. It should be faster in
// some circumstence (in particalr when ny >> nx). 
//  b.
// Update 02/02/17: GpuConv2DOnDevice was completly rewritten. It also appears that when nx is large (around 1e6) 
// the results are no more accurate due to a lack of ram.


#ifndef _GpuConv2D_cu
#define _GpuConv2D_cu

#include <stdio.h>
#include <iostream>
#include <assert.h>
#include <cuda.h>
#include <cuda_runtime_api.h>

#include "GaussFunction.h"
#include "ScalarRadialKernel.h"

#include "GpuConv2D.h"

#include "SimpleTimer.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
// Reduce a 2D array in a 1D vector
///////////////////////////////////////////////////////////////////////////////////////////////////

// this piece of code is common to all the cuda kernels below

template <typename TYPE, int DIMVECT>
__global__ void reduce0(TYPE* in, TYPE* out, int sizeY,int nx)
{
	TYPE res = 0;
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	if(tid < nx*DIMVECT)
	{
		for (int i = 0; i < sizeY; i++)
			res += in[tid + i*nx*DIMVECT];
		/*res = in[tid+ nx* DIMVECT];*/
		out[tid] = res;
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////
// Conv2D :
////////////////////////////////////////////////////////////////////////////////////////////////////


// thread kernel: computation of gammai = sum_j k(xi,yj)betaj for index i given by thread id.
template < typename TYPE, int DIMPOINT, int DIMVECT, class KER  >
__global__ void GpuConv2DOnDevice(KER Ker,
                                      TYPE *x, TYPE *y, TYPE *beta, TYPE *gammaB,
                                      int nx, int ny)
{

	// Compute the id of current thread
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;

	// Shared data will contain : x,beta,gammaij
	extern __shared__ char SharedData_char[];
	TYPE* const SharedData = reinterpret_cast<TYPE*>(SharedData_char);

	// Define some constant to 
	int const inc = DIMPOINT + DIMVECT;
	int const inc_intercept = inc * blockDim.x;
	int const inc_line = blockDim.y * DIMVECT;

	// Load data in shared memory
	if ((i<ny) && (threadIdx.y==0)) // use only first column of threads to feed the shared mem.
	{
		for(int k=0; k<DIMPOINT; k++)
			SharedData[threadIdx.x*inc+k] = y[i*DIMPOINT+k];
		for(int k=0; k<DIMVECT; k++)
			SharedData[threadIdx.x*inc+DIMPOINT+k] = beta[i*DIMVECT+k];
	}
	TYPE xj[DIMPOINT];
	if (j<nx)// load xj from device global memory only if j is in the range
	{
		for(int k=0; k<DIMPOINT; k++)
			xj[k] = x[j*DIMPOINT+k];
	}
	__syncthreads();
	// Compute each entry of the array
	TYPE *gammai  = SharedData + inc_intercept + threadIdx.x * inc_line;
	TYPE *gammaij = gammai + DIMVECT * threadIdx.y;
	if((i<ny) && ( j<nx)) // we compute gammaij only if needed
	{
		TYPE *yi = SharedData + threadIdx.x * inc, *betai = SharedData+ threadIdx.x * inc + DIMPOINT;
		Ker.Eval2(gammaij, xj, yi, betai);
	}
	__syncthreads();


	// do reduction in shared mem
	for ( unsigned int s=1; s < blockDim.x ; s *= 2)
	{
		if ((threadIdx.x % (2*s) == 0) && (i<ny-s) && (j<nx))
		{
			for (int k=0; k<DIMVECT; k++)
				gammaij[k] += gammaij[k + s * inc_line];
		}
		__syncthreads() ;
	}

	// write result for this block to global memomry
	if ((threadIdx.x == 0) && (j<nx))
	{
		for(int k=0; k<DIMVECT; k++)
			gammaB[blockIdx.x*(DIMVECT*nx)+j*DIMVECT+k] = gammaij[k];
	}




}
///////////////////////////////////////////////////



template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
int GpuEvalConv2D(KER Ker, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{
    // Data on the device.
    TYPE* x_d;
    TYPE* y_d;
    TYPE* beta_d;
    TYPE* gamma_d;
    TYPE* gammaB;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&y_d, sizeof(TYPE)*(ny*DIMPOINT));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(ny*DIMVECT));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*(nx*DIMVECT));

//      SimpleTimer timerCGPU;

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(y_d, y_h, sizeof(TYPE)*(ny*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(ny*DIMVECT), cudaMemcpyHostToDevice);

//      TYPE timeCGPU = timerCGPU.GetElapsedCPUTimeInSecondsOnly();
//      std::cout << "CPUcopy : " << timeCGPU << "s" << std::endl;

    // Compute on device.
    dim3 blockSize;
     blockSize.x = 32; // number of threads in each block
     blockSize.y = 32;
   dim3 gridSize;
     gridSize.x =  ny / blockSize.x + (ny%blockSize.x==0 ? 0 : 1);
     gridSize.y =  nx / blockSize.y + (nx%blockSize.y==0 ? 0 : 1);

     cudaMalloc((void**)&gammaB, sizeof(TYPE)*(nx*DIMVECT*gridSize.x));

 //      SimpleTimer timerCPU;
        std::cout << "2D!!!!! " << "(" << gridSize.x << "," <<gridSize.y << "," << gridSize.z <<")" << std::endl;
 
     GpuConv2DOnDevice<TYPE,DIMPOINT,DIMVECT,KER>
                 <<<gridSize,blockSize,(blockSize.x*(DIMVECT+DIMPOINT) + blockSize.x*blockSize.y*(DIMVECT))*sizeof(TYPE)>>>
                         (Ker, x_d, y_d, beta_d, gammaB, nx, ny);


 // Reduce  : grid and block are 1d
   dim3 blockSize2;
     blockSize2.x = 512; // number of threads in each block
   dim3 gridSize2;
   gridSize2.x =  (nx*DIMVECT) / blockSize2.x + ((nx*DIMVECT)%blockSize2.x==0 ? 0 : 1);


     reduce0<TYPE,DIMVECT><<<gridSize2, blockSize2>>>(gammaB, gamma_d, gridSize.x,nx);
   // block until the device has completed
   cudaThreadSynchronize();


   // Send data from device to host.
   cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*(nx*DIMVECT),cudaMemcpyDeviceToHost);

   // Free memory.
   cudaFree(x_d);
   cudaFree(y_d);
   cudaFree(beta_d);
   cudaFree(gamma_d);
   cudaFree(gammaB);

   return 0;
}







/*
template < typename TYPE, int DIMPOINT, int DIMVECT >
int CauchyGpuEvalConv2D(TYPE sigma, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{

	return GpuEvalConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> >(CauchyFunction<TYPE>(sigma)),
			x_h, y_h, beta_h, gamma_h, nx, ny);
}
*/

template < typename TYPE, int DIMPOINT, int DIMVECT >
int GaussGpuEvalConv2D(TYPE sigma, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{

	return GpuEvalConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> >(GaussFunction<TYPE>(sigma)),
			x_h, y_h, beta_h, gamma_h, nx, ny);
}




////////////////////////////////////////////////////////////////////////////////////////////////////
// Grad1 Conv1D :
////////////////////////////////////////////////////////////////////////////////////////////////////


template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
__global__ void GpuGrad1Conv2DOnDevice(KER Ker,
        TYPE *alpha, TYPE *x, TYPE *y, TYPE *beta, TYPE *gammaB,
        int nx, int ny)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    extern __shared__ char SharedData_char[];
    TYPE* const SharedData = reinterpret_cast<TYPE*>(SharedData_char);

    TYPE xi[DIMPOINT], alphai[DIMVECT], gammai[DIMPOINT];
    if(i<nx)  // we will compute gammai only if i is in the range
    {
        // load xi and alphai from device global memory
        for(int k=0; k<DIMPOINT; k++)
            xi[k] = x[i*DIMPOINT+k];
        for(int k=0; k<DIMVECT; k++)
            alphai[k] = alpha[i*DIMVECT+k];
        for(int k=0; k<DIMPOINT; k++)
            gammai[k] = 0.0f;
    }

        int j = blockIdx.y * blockDim.x + threadIdx.x;
        if(j<ny) // we load yj and betaj from device global memory only if j<ny
        {
            int inc = DIMPOINT + DIMVECT;
            for(int k=0; k<DIMPOINT; k++)
                SharedData[threadIdx.x*inc+k] = y[j*DIMPOINT+k];
            for(int k=0; k<DIMVECT; k++)
                SharedData[threadIdx.x*inc+DIMPOINT+k] = beta[j*DIMVECT+k];
        }
        __syncthreads();
        if(i<nx) // we compute gammai only if i is in the range
        {
            TYPE *yj, *betaj;
            yj = SharedData;
            betaj = SharedData + DIMPOINT;
            int inc = DIMPOINT + DIMVECT;
            for(int jrel = 0; (jrel < blockDim.x) && ((blockDim.x*blockIdx.y+jrel)< ny); jrel++, yj+=inc, betaj+=inc)
	            Ker.Grad1(gammai,alphai,xi,yj,betaj);
        }
        __syncthreads();

    // Save the result in global memory.
    if(i<nx)
        for(int k=0; k<DIMPOINT; k++)
            gammaB[blockIdx.y*DIMPOINT*nx+i*DIMPOINT+k] = gammai[k];
}

//////////////////////////////////////////////////////////////

template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
int GpuGrad1Conv2D(KER Ker, TYPE* alpha_h, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{

    // Data on the device.
    TYPE* x_d;
    TYPE* y_d;
    TYPE* alpha_d;
    TYPE* gamma_d;
    TYPE* gammaB;
    TYPE* beta_d;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&y_d, sizeof(TYPE)*(ny*DIMPOINT));
    cudaMalloc((void**)&alpha_d, sizeof(TYPE)*(nx*DIMVECT));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(ny*DIMVECT));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*(nx*DIMPOINT));

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(y_d, y_h, sizeof(TYPE)*(ny*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(alpha_d, alpha_h, sizeof(TYPE)*(nx*DIMVECT), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(ny*DIMVECT), cudaMemcpyHostToDevice);

    // compute on device.
    dim3 blockSize;
    blockSize.x = 192; // number of threads in each block
    int blockSizey = blockSize.x;
    dim3 gridSize;
    gridSize.x =  nx / blockSize.x + (nx%blockSize.x==0 ? 0 : 1);
    gridSize.y =  ny / blockSizey + (ny%blockSizey==0 ? 0 : 1);

    cudaMalloc((void**)&gammaB, sizeof(TYPE)*(nx*DIMPOINT*gridSize.y));

   // Reduce  : grid and block are 1d
    dim3 blockSize2;
    blockSize2.x = 192; // number of threads in each block
    dim3 gridSize2;
    gridSize2.x =  (nx*DIMPOINT) / blockSize2.x + ((nx*DIMPOINT)%blockSize2.x==0 ? 0 : 1);

    GpuGrad1Conv2DOnDevice<TYPE,DIMPOINT,DIMVECT,KER>
		<<<gridSize,blockSize,blockSize.x*(DIMPOINT+DIMVECT)*sizeof(TYPE)>>>
			(Ker, alpha_d, x_d, y_d, beta_d, gammaB, nx, ny);

    reduce0<TYPE,DIMPOINT><<<gridSize2, blockSize2>>>(gammaB, gamma_d, gridSize.y,nx);

    // block until the device has completed
    cudaThreadSynchronize();

    // Send data from device to host.
    cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*(nx*DIMPOINT),cudaMemcpyDeviceToHost);

    // Free memory.
    cudaFree(x_d);
    cudaFree(y_d);
    cudaFree(alpha_d);
    cudaFree(gamma_d);
    cudaFree(gammaB);
    cudaFree(beta_d);

    return 0;
}

/*
template < typename TYPE, int DIMPOINT, int DIMVECT >
int CauchyGpuGrad1Conv2D(TYPE sigma, TYPE* alpha_h, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{
	return GpuGrad1Conv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> >(CauchyFunction<TYPE>(sigma)),
			alpha_h, x_h, y_h, beta_h, gamma_h, nx, ny);
}
*/

template < typename TYPE, int DIMPOINT, int DIMVECT >
int GaussGpuGrad1Conv2D(TYPE sigma, TYPE* alpha_h, TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{
	return GpuGrad1Conv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> >(GaussFunction<TYPE>(sigma)),
			alpha_h, x_h, y_h, beta_h, gamma_h, nx, ny);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
// Grad Conv1D :
////////////////////////////////////////////////////////////////////////////////////////////////////


template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
__global__ void GpuGradConv2DOnDevice(KER Ker,
         TYPE *x, TYPE *beta, unsigned int dim, TYPE *gammaB,
        int nx)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    extern __shared__ char SharedData_char[];
    TYPE* const SharedData = reinterpret_cast<TYPE*>(SharedData_char);

    TYPE xi[DIMPOINT], gammai[DIMVECT];
    if(i<nx)  // we will compute gammai only if i is in the range
    {
        // load xi from device global memory
        for(int k=0; k<DIMPOINT; k++)
            xi[k] = x[i*DIMPOINT+k];
        for(int k=0; k<DIMVECT; k++)
            gammai[k] = 0.0f;
    }


        int j = blockIdx.y * blockDim.x + threadIdx.x;
        if(j<nx) // we load xj and betaj from device global memory only if j<nx
        {
            int inc = DIMPOINT + DIMVECT;
            for(int k=0; k<DIMPOINT; k++)
                SharedData[threadIdx.x*inc+k] = x[j*DIMPOINT+k];
            for(int k=0; k<DIMVECT; k++)
                SharedData[threadIdx.x*inc+DIMPOINT+k] = beta[j*DIMVECT+k];
        }
        __syncthreads();
        if(i<nx) // we compute gammai only if i is in the range
        {
            TYPE *xj, *betaj;
            xj = SharedData;
            betaj = SharedData + DIMPOINT;
            int inc = DIMPOINT + DIMVECT;
            for(int jrel = 0; (jrel < blockDim.x) && ((blockDim.x*blockIdx.y+jrel)< nx); jrel++, xj+=inc, betaj+=inc)
                Ker.Graddim(gammai, xi, xj, betaj, &dim);
        }
        __syncthreads();


    // Save the result in global memory.
    if(i<nx)
        for(int k=0; k<DIMPOINT; k++)
            gammaB[blockIdx.y*DIMPOINT*nx+i*DIMPOINT+k] = gammai[k];
}

////////////////////////////////////////////////////////////////////////////

template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
int GpuGradConv2D(KER Ker,
        TYPE* x_h, TYPE* beta_h, unsigned int dim_h, TYPE* gamma_h,
         int nx)
{

    // Data on the device.
    TYPE* x_d;
    TYPE* gamma_d;
    TYPE* gammaB;
    TYPE* beta_d;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(nx*DIMVECT));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*(nx*DIMVECT));

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(nx*DIMVECT), cudaMemcpyHostToDevice);

    // compute on device.
    dim3 blockSize;
    blockSize.x = 192; // number of threads in each block
    int blockSizey = blockSize.x;
    dim3 gridSize;
    gridSize.x =  nx / blockSize.x + (nx%blockSize.x==0 ? 0 : 1);
    gridSize.y =  nx / blockSizey + (nx%blockSizey==0 ? 0 : 1);

    // Reduce  : grid and block are 1d
    dim3 blockSize2;
    blockSize2.x = 192; // number of threads in each block
    dim3 gridSize2;
    gridSize2.x =  (nx*DIMPOINT) / blockSize2.x + ((nx*DIMPOINT)%blockSize2.x==0 ? 0 : 1);

   cudaMalloc((void**)&gammaB, sizeof(TYPE)*(nx*DIMPOINT*gridSize.y));

    GpuGradConv2DOnDevice<TYPE,DIMPOINT,DIMVECT,KER>
        <<<gridSize,blockSize,blockSize.x*(DIMPOINT+DIMVECT)*sizeof(TYPE)>>>
            (Ker, x_d, beta_d, dim_h, gammaB, nx);

    reduce0<TYPE,DIMPOINT><<<gridSize2, blockSize2>>>(gammaB, gamma_d, gridSize.y,nx);

    // block until the device has completed
    cudaThreadSynchronize();

    // Send data from device to host.
    cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*(nx*DIMPOINT),cudaMemcpyDeviceToHost);

    // Free memory.
    cudaFree(x_d);
    cudaFree(beta_d);
    cudaFree(gamma_d);
    cudaFree(gammaB);

    return 0;
}

//template < typename TYPE, int DIMPOINT, int DIMVECT >
//int CauchyGpuGradConv2D(TYPE sigma, TYPE* alpha_h, TYPE* x_h, TYPE* beta_h, TYPE* gamma_h, int nx)
//{
//	return GpuGradConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> > >
//		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> >(CauchyFunction<TYPE>(sigma)),
//			alpha_h, x_h, beta_h, gamma_h, nx);
//}

template < typename TYPE, int DIMPOINT, int DIMVECT >
int GaussGpuGradConv2D(TYPE sigma,  TYPE* x_h, TYPE* beta_h, unsigned int dim_h, TYPE* gamma_h, int nx)
{
	return GpuGradConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> >(GaussFunction<TYPE>(sigma)),
			x_h, beta_h,dim_h,  gamma_h, nx);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// GradDiff Conv1D :
////////////////////////////////////////////////////////////////////////////////////////////////////


template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
__global__ void GpuGradDiffConv2DOnDevice(KER Ker,
        TYPE *x, TYPE *beta, TYPE *eta, TYPE *gammaB,
        int nx)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    extern __shared__ char SharedData_char[];
    TYPE* const SharedData = reinterpret_cast<TYPE*>(SharedData_char);

    TYPE xi[DIMPOINT], betai[DIMVECT], etai[DIMPOINT], gammai[DIMPOINT];
    if(i<nx)  // we will compute gammai only if i is in the range
    {
        // load xi, etai, betai from device global memory
        for(int k=0; k<DIMPOINT; k++)
            xi[k] = x[i*DIMPOINT+k];
        for(int k=0; k<DIMVECT; k++)
            betai[k] = beta[i*DIMVECT+k];
        for(int k=0; k<DIMPOINT; k++)
            etai[k] = eta[i*DIMPOINT+k];
        for(int k=0; k<DIMPOINT; k++)
            gammai[k] = 0.0f;
    }


        int j = blockIdx.y * blockDim.x + threadIdx.x;
        if(j<nx) // we load xj, etaj and betaj from device global memory only if j<nx
        {
            int inc = 2 * DIMPOINT + DIMVECT;
            for(int k=0; k<DIMPOINT; k++)
                SharedData[threadIdx.x*inc+k] = x[j*DIMPOINT+k];
            for(int k=0; k<DIMVECT; k++)
                SharedData[threadIdx.x*inc+DIMPOINT+k] = beta[j*DIMVECT+k];
            for(int k=0; k<DIMPOINT; k++)
                SharedData[threadIdx.x*inc+DIMPOINT+DIMVECT+k] = eta[j*DIMPOINT+k];
        }
        __syncthreads();
        if(i<nx) // we compute gammai only if i is in the range
        {
            TYPE *xj, *betaj, *etaj;
            xj = SharedData;
            betaj = SharedData + DIMPOINT;
            etaj = SharedData + DIMPOINT + DIMVECT;
            int inc = 2 * DIMPOINT + DIMVECT;
            for(int jrel = 0; (jrel < blockDim.x) && ((blockDim.x*blockIdx.y+jrel)< nx); jrel++, xj+=inc, betaj+=inc, etaj+=inc)
                Ker.GradDiff(gammai, xi, xj, betai, betaj, etai, etaj);
        }
        __syncthreads();


    // Save the result in global memory.
    if(i<nx)
        for(int k=0; k<DIMPOINT; k++)
            gammaB[blockIdx.y*DIMPOINT*nx+i*DIMPOINT+k] = gammai[k];
}

////////////////////////////////////////////////////////////////////////////

template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
int GpuGradDiffConv2D(KER Ker,
        TYPE* x_h, TYPE* beta_h, TYPE* eta_h, TYPE* gamma_h,
         int nx)
{

    // Data on the device.
    TYPE* x_d;
    TYPE* beta_d;
    TYPE* gamma_d;
    TYPE* gammaB;
    TYPE* eta_d;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(nx*DIMVECT));
    cudaMalloc((void**)&eta_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*(nx*DIMPOINT));

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(nx*DIMVECT), cudaMemcpyHostToDevice);
    cudaMemcpy(eta_d, eta_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);

    // compute on device.
    dim3 blockSize;
    blockSize.x = 192; // number of threads in each block
    int blockSizey = blockSize.x;
    dim3 gridSize;
    gridSize.x =  nx / blockSize.x + (nx%blockSize.x==0 ? 0 : 1);
    gridSize.y =  nx / blockSizey + (nx%blockSizey==0 ? 0 : 1);

    cudaMalloc((void**)&gammaB, sizeof(TYPE)*(nx*DIMPOINT*gridSize.y));

    // Reduce  : grid and block are 1d
    dim3 blockSize2;
    blockSize2.x = 192; // number of threads in each block
    dim3 gridSize2;
    gridSize2.x =  (nx*DIMPOINT) / blockSize2.x + ((nx*DIMPOINT)%blockSize2.x==0 ? 0 : 1);

    GpuGradDiffConv2DOnDevice<TYPE,DIMPOINT,DIMVECT,KER>
        <<<gridSize,blockSize,blockSize.x*(2*DIMPOINT+DIMVECT)*sizeof(TYPE)>>>
            (Ker, x_d, beta_d, eta_d, gammaB, nx);

    reduce0<TYPE,DIMPOINT><<<gridSize2, blockSize2>>>(gammaB, gamma_d, gridSize.y,nx);

    // block until the device has completed
    cudaThreadSynchronize();

    // Send data from device to host.
    cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*(nx*DIMPOINT),cudaMemcpyDeviceToHost);

    // Free memory.
    cudaFree(x_d);
    cudaFree(eta_d);
    cudaFree(beta_d);
    cudaFree(gamma_d);
    cudaFree(gammaB);

    return 0;
}

template < typename TYPE, int DIMPOINT, int DIMVECT >
int GaussGpuGradDiffConv2D(TYPE sigma, TYPE* x_h, TYPE* beta_h, TYPE* eta_h, TYPE* gamma_h, int nx)
{
	return GpuGradDiffConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> >(GaussFunction<TYPE>(sigma)),
			x_h, beta_h, eta_h, gamma_h, nx);
}



////////////////////////////////////////////////////////////////////////////////////////////////////
// Grad_varlin Conv2D :
////////////////////////////////////////////////////////////////////////////////////////////////////

template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
__global__ void GpuGradConv_varlin_2DOnDevice(KER Ker,
        TYPE *x, TYPE *y, TYPE *beta, TYPE *gammaB,
        int nx, int ny)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    extern __shared__ char SharedData_char[];
    TYPE* const SharedData = reinterpret_cast<TYPE*>(SharedData_char);

    TYPE xi[DIMPOINT], gammai[DIMVECT*DIMPOINT];
    if(i<nx)  // we will compute gammai only if i is in the range
    {
        // load xi from device global memory
        for(int k=0; k<DIMPOINT; k++)
            xi[k] = x[i*DIMPOINT+k];
        for(int k=0; k<DIMVECT*DIMPOINT; k++)
            gammai[k] = 0.0f;
    }

	int j = blockIdx.y * blockDim.x + threadIdx.x;
        if(j<ny) // we load yj and betaj from device global memory only if j<ny
        {
            int inc = DIMPOINT + DIMVECT;
            for(int k=0; k<DIMPOINT; k++)
                SharedData[threadIdx.x*inc+k] = y[j*DIMPOINT+k];
            for(int k=0; k<DIMVECT; k++)
                SharedData[threadIdx.x*inc+DIMPOINT+k] = beta[j*DIMVECT+k];
        }
        __syncthreads();

        if(i<nx) // we compute gammai only if i is in the range
        {
            TYPE *yj, *betaj;
            yj = SharedData;
            betaj = SharedData + DIMPOINT;
            int inc = DIMPOINT + DIMVECT;
            for(int jrel = 0; jrel < blockDim.x && ((blockDim.x*blockIdx.y+jrel)< ny); jrel++, yj+=inc, betaj+=inc)
                Ker.Grad_varlin(gammai, xi, yj,  betaj);
        }
        __syncthreads();

    // Save the result in global memory.
    if(i<nx)
        for(int k=0; k<DIMVECT*DIMPOINT; k++)
            gammaB[blockIdx.y*DIMVECT*DIMPOINT*nx+i*DIMVECT*DIMPOINT+k] = gammai[k];
}



template < typename TYPE, int DIMPOINT, int DIMVECT, class KER >
int GpuGradConv_varlin_2D(KER Ker,
        TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h,
         int nx, int ny)
{

    // Data on the device.
    TYPE* x_d;
    TYPE* y_d;
    TYPE* gamma_d;
    TYPE* beta_d;
    TYPE* gammaB;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*DIMPOINT));
    cudaMalloc((void**)&y_d, sizeof(TYPE)*(ny*DIMPOINT));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(ny*DIMVECT));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*(nx*DIMVECT*DIMPOINT));

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(y_d, y_h, sizeof(TYPE)*(ny*DIMPOINT), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(ny*DIMVECT), cudaMemcpyHostToDevice);

    // compute on device.
    dim3 blockSize;
    blockSize.x = 192; // number of threads in each block
    int blockSizey = blockSize.x;
    dim3 gridSize;
    gridSize.x =  nx / blockSize.x + (nx%blockSize.x==0 ? 0 : 1);
    gridSize.y =  ny / blockSizey + (ny%blockSizey==0 ? 0 : 1);

    cudaMalloc((void**)&gammaB, sizeof(TYPE)*(nx*DIMVECT*DIMPOINT*gridSize.y));

	GpuGradConv_varlin_2DOnDevice<TYPE,DIMPOINT,DIMVECT,KER>
        <<<gridSize,blockSize,blockSize.x*(DIMPOINT+DIMVECT)*sizeof(TYPE)>>>
            (Ker, x_d, y_d, beta_d, gammaB, nx, ny);

    // Reduce  : grid and block are 1d
    dim3 blockSize2;
    blockSize2.x = 192; // number of threads in each block
    dim3 gridSize2;
    gridSize2.x =  (nx*DIMVECT*DIMPOINT) / blockSize2.x + ((nx*DIMVECT*DIMPOINT)%blockSize2.x==0 ? 0 : 1);

    reduce0<TYPE,DIMVECT*DIMPOINT><<<gridSize2, blockSize2>>>(gammaB, gamma_d, gridSize.y,nx);

    // block until the device has completed
    cudaThreadSynchronize();

    // Send data from device to host.
    cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*(nx*DIMVECT*DIMPOINT),cudaMemcpyDeviceToHost);

    // Free memory.
    cudaFree(x_d);
    cudaFree(y_d);
    cudaFree(beta_d);
    cudaFree(gamma_d);

    return 0;
}



//template < typename TYPE, int DIMPOINT, int DIMVECT >
//int CauchyGpuGradConv2D(TYPE sigma, TYPE* alpha_h, TYPE* x_h, TYPE* beta_h, TYPE* gamma_h, int nx)
//{
//	return GpuGradConv2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> > >
//		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE> >(CauchyFunction<TYPE>(sigma)),
//			alpha_h, x_h, beta_h, gamma_h, nx);
//}



template < typename TYPE, int DIMPOINT, int DIMVECT >
int GaussGpuGradConv_varlin_2D(TYPE sigma,  TYPE* x_h, TYPE* y_h, TYPE* beta_h, TYPE* gamma_h, int nx, int ny)
{
	return GpuGradConv_varlin_2D < TYPE, DIMPOINT, DIMVECT, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> > >
		(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE> >(GaussFunction<TYPE>(sigma)),
			x_h, y_h, beta_h, gamma_h, nx, ny);
}




// http://www.parashift.com/c++-faq-lite/separate-template-fn-defn-from-decl.html
#define DECLARE_Conv2DS(TYPE,DIMPOINT,DIMVECT) \
	template int GaussGpuEvalConv2D<TYPE,DIMPOINT,DIMVECT>(TYPE, TYPE*, TYPE*, TYPE*, TYPE*, int, int); \
	template int GaussGpuGrad1Conv2D<TYPE,DIMPOINT,DIMVECT>(TYPE, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, int, int); \
	template int GaussGpuGradConv2D<TYPE,DIMPOINT,DIMVECT>(TYPE, TYPE*, TYPE*, unsigned int, TYPE*, int); \
	template int GaussGpuGradDiffConv2D<TYPE,DIMPOINT,DIMVECT>(TYPE, TYPE*, TYPE*, TYPE*, TYPE*, int);  \
	template int GaussGpuGradConv_varlin_2D<TYPE,DIMPOINT,DIMVECT>(TYPE, TYPE*, TYPE*, TYPE*, TYPE*, int, int); 
#define DECLARE_Conv2DS_ALLDIMS_FOR(TYPE) \
	DECLARE_Conv2DS(TYPE,1,1) \
	DECLARE_Conv2DS(TYPE,2,1) \
	DECLARE_Conv2DS(TYPE,2,2) \
	DECLARE_Conv2DS(TYPE,2,4) \
	DECLARE_Conv2DS(TYPE,3,1) \
	DECLARE_Conv2DS(TYPE,3,3) \
	DECLARE_Conv2DS(TYPE,3,6)
DECLARE_Conv2DS_ALLDIMS_FOR(float)
DECLARE_Conv2DS_ALLDIMS_FOR(double)



#endif /* _GpuConv2D_cu */
