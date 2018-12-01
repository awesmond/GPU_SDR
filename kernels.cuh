#pragma once
#ifndef GPU_KERNELS_INCUDED_h
#define GPU_KERNELS_INCUDED_h

#include <cuda_runtime.h>
#include "cublas_v2.h"
#include <curand.h>
#include <curand_kernel.h>
#include <cufft.h>
#include <iostream>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <iostream>
//#include "USRP_server_diagnostic.hpp"
#ifndef pi_f
#define pi_f 3.14159265358979f
#define _31_BIT_VALUE 2147483647.5
#endif

//could be used to tune for other GPUs. NOTE: it also defines the shared memory
#define PFB_DECIM_TPB 64. //Threads per block

//polyphase filter parameter wrapper + utility variables for buffer reminder
struct filter_param {
    float2* window; //pointer to an already initialized window.
    int length; //total length of the device buffer
    int n_tones; //how many points to calculate in the FFT
    int average_buffer; //how many buffer are averaged (length of the window has to be average_buffer * n_tones)
    int batching; //how many samples per each tone are present in the device buffer
    int* tones; //Must be an array containing the fft bin number corresponding to the tone frequency
    int eff_n_tones; //how many tones do you effectively want to download in the host buffer

};

struct chirp_parameter{
    unsigned  long int num_steps; //number of frequency change in the chirp signal (1 means simple sinus).
    unsigned  long int length; //total length of the each frequency in the chirp signal (in samples).
    unsigned  int chirpness; //coefficient for quedratic phase calculation.
    int f0; //start frequency
    float freq_norm; //coefficient to adapt buffer samples to TX/RX frequency (deprecated).
};

//descriptor of the mutitone generation
struct tone_parameters{
    int tones_number; //how many tones to generate
    int* tone_frquencies; //tones frequencies in Hz (frequency resolution will be 1Hz, host side)
    float* tones_amplitudes; //tones amplitudes (linear, host side)
};


void chirp_gen_wrapper(
    float2* __restrict__ output, //pointer to the gpu buffer
    unsigned int output_size, //size of the buffer
    chirp_parameter* __restrict__ info, //chirp information
    unsigned long int last_index,
    cudaStream_t internal_stream,
    float scale //scale the amplitude of the chirp
);

void chirp_demodulator_wrapper(
    float2* __restrict__ input,  //pointer to the input buffer
    float2* __restrict__ output, //pointer to the gpu buffer
    unsigned int output_size, //size of the buffers
    unsigned long int last_index,
    chirp_parameter* __restrict__ info, //chirp information
    cudaStream_t internal_stream
);

void move_buffer_wrapper(
    float2* __restrict__ from,
    float2* __restrict__ to,
    int size,
    int from_offset,
    int to_offset,
    cudaStream_t internal_stream
);
void polyphase_filter_wrapper(
    float2* __restrict__ input,
    float2* __restrict__ output,
    filter_param* __restrict__ filter_info,
    cudaStream_t internal_stream
);

void tone_select_wrapper(
    float2* __restrict__ input, //must be the fft output
    float2* __restrict__ output,//the buffer that will then be downloaded to host
    filter_param* __restrict__ filter_info, //information about the filtering process
    int effective_batching, //how many samples per tone have been effectively calculated
    cudaStream_t internal_stream
);
//allocates memory on gpu and fills with a real hamming window. returns a pointer to the window on the device.
//note that this is a host function that wraps some device calls
template <typename T>
T* make_hamming_window(int length, int side, bool diagnostic = false);
float2* make_hamming_window(int length, int side, bool diagnostic = false);

//allocates memory on gpu and fills with a real sinc window. returns a pointer to the window on the device.
//note that this is a host function that wraps some device calls
float2* make_sinc_window(int length, float fc, bool diagnostic);

void print_chirp_params(std::string comment, chirp_parameter cp);

//generate a set of tones and return host pointer to the buffer unless the device option is true.
//NOTE the length of the buffer is the sampling_rate
float2* tone_gen(
    tone_parameters* info, //tone information (all host side)
    int sampling_rate,
    float scale = 1., //scale the whole buffer (all tones) for a scalar
    bool device = false//the function return device buffer instead
    );

void decimate_spectra(
        float2* __restrict__ input, //output of the pfb
        float2* __restrict__ output,//decimated output
        int decim,                  //decimation factor (multiplicative to the pfb one)
        int nfft,                   //length of the fft
        int input_len,              //could be calculated inside but I wrote an apposite class for it
        int output_len,
        cudaStream_t stram_f        //stream on which to launch the decimator
        );

//decimate the output of the fft without tone selection
//NOTE: this thread has to be launched from its wrapper or witha Nblocks*Nthreads == out_len and
//it is not protected from accessing data outside input_len (see wrapper)

#ifdef CUBLAS_API_H_
// cuBLAS API errors
void _cudaGetErrorEnum(cublasStatus_t error);
#endif
void cublas_decim(
    float2* __restrict__ input,
    float2* __restrict__ output,
    float2* __restrict__ profile,
    cuComplex* __restrict__ zero,
    cuComplex* __restrict__ one,
    int ppt,
    int n_freqs,
    cublasHandle_t* __restrict__ handle
    );

//wrapper for the previous fft decimation function. decimates the pfb output.
//NOTE: this function does not take care of the reminder and suppose that calculation
//to determine the output_length has already been externally done.
void decimate_pfb(        
    float2* __restrict__ input, //output of the pfb
    float2* __restrict__ output,//decimated output
    int decim,                  //decimation factor (multiplicative to the pfb one)
    int nfft,                   //length of the fft
    int output_length,          //could be calculated inside but I wrote an apposite class for it
    cudaStream_t stram_f        //stream on which to launch the decimator
    );

void D_cublas_decim(
    double2* __restrict__ input,
    double2* __restrict__ output,
    double2* __restrict__ profile,
    cuDoubleComplex* __restrict__ zero,
    cuDoubleComplex* __restrict__ one,
    int ppt,
    int n_freqs,
    cublasHandle_t* __restrict__ handle
    );
#endif




