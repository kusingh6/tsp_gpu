#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <cuda.h>
#include <math.h>

#define t_num 256
#define N 100 

/* For some reason, tabs are giving me a weird error. Use four spaces instead - S. */

/* BEGIN KERNEL:*/
__global__ static void try(int* i, int* k, float *dist,
                           int *odr, float *T, float *r, int *flag) {
    const int tid= threadIdx.x;       /* const int N=100;*/
    float delta, p, b=1;

    delta = dist[odr[(i[tid] - 1 + N) % N] * N + odr[k[tid]]] +
                dist[odr[k[tid]] * N + odr[(i[tid] + 1) % N]] +
                dist[odr[(k[tid] - 1 + N) % N] * N + odr[i[tid]]] +
                dist[odr[i[tid]] * N + odr[(k[tid] + 1) % N]] -
                dist[odr[(i[tid] - 1 + N) % N] * N + odr[i[tid]]] -
                dist[odr[(i[tid])] * N + odr[(i[tid] + 1) % N]] -
                dist[odr[(k[tid] - 1 + N) % N] * N + odr[k[tid]]] -
                dist[odr[k[tid]] * N + odr[(k[tid] + 1) % N]];
    p=exp(-delta*b/T[0]);
    if (p > r[tid])
        flag[tid] = 1;
    else
        flag[tid] = 0;
} /* END KERNEL*/

int main()
{
       /*ijklm classic counters, N the number of the cities;*/
    int i, j, k, l, m;  

    /*city's x y coordinate, respectively;*/       struct location
    {
    int x, y;
    }

    lct[N];

    /*the order the salesman travels;*/
    int odr[N];

    /*initialize the location and sequence;*/
    for(i=0; i<N; i++)
    {
        lct[i].x=rand()%1000;
        lct[i].y=rand()%1000;
        odr[i]=i;
    } 

    /*distance matrix;*/
    float dist[N*N];

    for(i=0; i<N; i++)
    {
        for(j=0; j<N; j++)
        {
            /*calculate distance from location;*/
            dist[i*N+j]= (lct[i].x-lct[j].x) *
                         (lct[i].x-lct[j].x) +
                         (lct[i].y-lct[j].y) * 
                         (lct[i].y-lct[j].y);  
                 /*because there'll be error when sqrt(0),
            so here I just calculate the square form
            and it also works.;*/
           /*      printf("%d %d %f\n",i,j,dist[i][j]);*/
        }
    } 
    
    /*
    float sum = 0;
    for (i = 0; i < N*N; i++)
    {
        sum += dist[odr[i]] * N + odr[(i + 1) % N]];
    }       printf("before optimization %f\n", sum);
    */

    float dist_g[N*N], T=1000, T_g[1], r_h[t_num], r_g[t_num];

    /*define some device variables, 
    r_g is a random number for deciding acceptance.
    flag is the acceptance vector*/
    int i_h[t_num], i_g[t_num], k_h[t_num], k_g[t_num],
        odr_g[N], flag_h[t_num], flag_g[t_num];      

    cudaMalloc((void**)&dist_g, N*N*sizeof(float));
    cudaMalloc((void**)&T_g, sizeof(float));
    cudaMalloc((void**)&r_g, t_num*sizeof(float));
    cudaMalloc((void**)&i_g, t_num*sizeof(int));
    cudaMalloc((void**)&k_g, t_num*sizeof(int));
    cudaMalloc((void**)&odr_g, N*sizeof(int));
    cudaMalloc((void**)&flag_g, t_num*sizeof(int));
    /*Beta is temp decay rate */
    float beta = 0.99, f, a = 1, b = 1, delta, p;  
    while (T > 1)
    {
        /*initialize the parameter*/
        for (m = 0; m < t_num; m++)    
        {
            /*city A to swap*/
            i_h[m] = rand() % N;
            f = exp(-a / T);
            /*f is the bound parameter of swap, a is a parameter*/
            j = 1 + rand() % (int)floor(1 + N*f);
            /*city B to swap*/
            k_h[m] = (i_h[m] + j) % N;
            r_h[m] = rand() / 2147483647.0;
        }
        cudaMemcpy(i_g, i_h, t_num* sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(k_g, k_h, t_num* sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(dist_g, dist, N*N* sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(odr_g, odr, N* sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(T_g, &T, sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(r_g, r_h, t_num* sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(flag_g, flag_h, t_num* sizeof(int), cudaMemcpyHostToDevice);
        try << <1, t_num, 0 >> >(i_g, k_g, dist_g, odr_g, T_g, r_g, flag_g);
        cudaMemcpy(flag_h, flag_g, t_num * sizeof(int), cudaMemcpyDeviceToHost);
        T = 0;
    }
    cudaFree(i_g);
    cudaFree(k_g);
    cudaFree(dist_g);
    cudaFree(odr_g);
    cudaFree(&T_g);
    cudaFree(r_g);
    cudaFree(flag_g);

    for (m = 0; m < t_num; m++)
    {
        printf("%d\n", flag_h[m]);
    }
    getchar();
    getchar();
    return 0;
}
